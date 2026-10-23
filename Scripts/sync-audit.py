#!/usr/bin/env python3
"""Net-new classes, fields, Literal values and resource methods between two refs of the Python SDK,
checked against the Swift sources. Read-only: it only runs `git show` / `git diff` in the reference clone.

    python3 -I Scripts/sync-audit.py PIN TARGET PYTHON_CLONE Sources

    python3 -I Scripts/sync-audit.py 4474f31 upstream/main ~/code/anthropic-sdk-python Sources

It lists, for every type and resource file changed between the two refs (admin/organization, Bedrock,
Vertex, Foundry and AWS areas excluded), each class, field, Literal value and method that is new at TARGET
and that no Swift source mentions. A field is looked for as its camelCase name and its wire name; a
Literal as its wire string and its camelCase form.

Read the result as a checklist, not a verdict. Expected noise: classes that Swift models under a
different name (an enum with cases instead of one class per variant), beta flags (Swift takes plain
`[String]`), model ids (plain `String`), and typing-only overlays that were deliberately not ported (see
REFERENCE.md). A *field* with no Swift mention is the strongest signal: that is how a field that moved to
a new class (`clear_at` on `BetaSystemMessageParam`) was found after a hand-written diff had missed it.
"""

import ast
import re
import subprocess
import sys

if len(sys.argv) != 5:
    sys.exit(__doc__)
PIN, TARGET, REPO, SWIFT = sys.argv[1:5]
EXCLUDE = ("/organization/", "bedrock", "vertex", "foundry", "/aws", "google_cloud")
# Handled generically rather than per call (documented in REFERENCE.md).
GENERIC_PARAMS = {"betas", "workspace_id", "extra_headers", "extra_query", "extra_body", "timeout", "user_profile_id"}


def git(*args):
    return subprocess.run(["git", "-C", REPO, *args], capture_output=True, text=True).stdout


def show(ref, path):
    out = subprocess.run(["git", "-C", REPO, "show", f"{ref}:{path}"], capture_output=True, text=True)
    return out.stdout if out.returncode == 0 else None


swift_text = subprocess.run(
    ["grep", "-rh", "", SWIFT, "--include=*.swift"], capture_output=True, text=True
).stdout


def camel(name):
    head, *rest = name.split("_")
    return head + "".join(p[:1].upper() + p[1:] for p in rest)


def in_swift(*needles):
    return any(re.search(r"(?<![A-Za-z0-9_])" + re.escape(n) + r"(?![A-Za-z0-9_])", swift_text) for n in needles if n)


def literals(node):
    found = set()
    for sub in ast.walk(node):
        if isinstance(sub, ast.Subscript) and getattr(sub.value, "id", getattr(sub.value, "attr", "")) == "Literal":
            for c in ast.walk(sub.slice):
                if isinstance(c, ast.Constant) and isinstance(c.value, str):
                    found.add(c.value)
    return found


def inventory(source):
    """{'classes': {name}, 'fields': {(class, field)}, 'literals': {str}, 'methods': {(class, method, param)}}"""
    inv = {"classes": set(), "fields": set(), "literals": set(), "methods": set()}
    if source is None:
        return inv
    try:
        tree = ast.parse(source)
    except SyntaxError:
        return inv
    for node in ast.walk(tree):
        if isinstance(node, ast.ClassDef):
            inv["classes"].add(node.name)
            for item in node.body:
                if isinstance(item, ast.AnnAssign) and isinstance(item.target, ast.Name) and not item.target.id.startswith("_"):
                    inv["fields"].add((node.name, item.target.id))
                if isinstance(item, (ast.FunctionDef, ast.AsyncFunctionDef)) and not item.name.startswith("_"):
                    for arg in item.args.args + item.args.kwonlyargs:
                        if arg.arg not in ("self", "cls"):
                            inv["methods"].add((node.name, item.name, arg.arg))
                    if not item.args.args and not item.args.kwonlyargs:
                        inv["methods"].add((node.name, item.name, ""))
    inv["literals"] = literals(tree)
    return inv


changed = [
    f for f in git("diff", "--name-only", PIN, TARGET, "--", "src/anthropic/types", "src/anthropic/resources").split()
    if f.endswith(".py") and not any(x in f for x in EXCLUDE)
]
rows = []
for path in changed:
    new, old = inventory(show(TARGET, path)), inventory(show(PIN, path))
    missing = []
    for cls in sorted(new["classes"] - old["classes"]):
        # Sync/Async twins and *WithRawResponse wrappers are Python-only mechanics.
        if cls.startswith("Async") or "WithRawResponse" in cls or "WithStreamingResponse" in cls:
            continue
        if not in_swift(cls) and not in_swift(cls.replace("Beta", "", 1)):
            missing.append(f"class {cls}")
    for cls, field in sorted(new["fields"] - old["fields"]):
        if not in_swift(camel(field), field):
            missing.append(f"field {cls}.{field}")
    for lit in sorted(new["literals"] - old["literals"]):
        if len(lit) < 3:
            continue
        if not in_swift(lit, camel(lit)):
            missing.append(f"literal {lit!r}")
    if "/resources/" in path:
        for cls, method, param in sorted(new["methods"] - old["methods"]):
            if cls.startswith("Async") or "WithRawResponse" in cls or "WithStreamingResponse" in cls:
                continue
            if param in GENERIC_PARAMS:
                continue
            if not in_swift(camel(method), method) or (param and not in_swift(camel(param), param)):
                missing.append(f"method {cls}.{method}({param})")
    if missing:
        rows.append((path.replace("src/anthropic/", ""), missing))

print(f"{len(changed)} files changed (excluding out-of-scope areas); {len(rows)} with items Swift never mentions\n")
for path, missing in rows:
    print(path)
    for m in missing:
        print("   ", m)
