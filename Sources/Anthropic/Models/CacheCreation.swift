public struct CacheCreation: Codable, Sendable, Equatable {
    /// Capital `H` (not `ephemeral1hInputTokens`) is deliberate: Foundation's `.convertFromSnakeCase`
    /// maps the wire's `ephemeral_1h_input_tokens` to `ephemeral1HInputTokens`, uppercasing the letter
    /// immediately after a digit run rather than the first character of the `1h` segment.
    public let ephemeral1HInputTokens: Int
    public let ephemeral5MInputTokens: Int
}
