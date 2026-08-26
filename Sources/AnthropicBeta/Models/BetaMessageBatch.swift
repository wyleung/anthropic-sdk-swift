import Anthropic

/// Ported from `types/beta/messages/beta_message_batch.py` and
/// `beta_message_batch_request_counts.py`. Both confirmed field-identical to their GA
/// `MessageBatch`/`MessageBatchRequestCounts` counterparts, so they're reused directly rather than
/// duplicated.
public typealias BetaMessageBatch = MessageBatch
public typealias BetaMessageBatchRequestCounts = MessageBatchRequestCounts

/// Ported from `types/beta/messages/beta_deleted_message_batch.py`. Field-identical to GA's
/// `DeletedMessageBatch` (`id`/`type`); the `type` discriminator literal differs
/// (`"message_batch_deleted"` vs. GA's own value) but both model it as a plain `String`, so the
/// wire shape still matches exactly.
public typealias BetaDeletedMessageBatch = DeletedMessageBatch
