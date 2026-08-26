import Anthropic

/// Ported from `types/beta_error.py` and `types/beta_error_response.py`. Confirmed field-identical
/// to GA's `ErrorObject`/`ErrorResponse` by reading all nine Beta leaf error files directly --
/// each carries the same `message`/`type` fields under the same discriminator values as its GA
/// counterpart, including the `beta_gateway_timeout_error.py` `"timeout_error"` quirk GA already
/// models.
public typealias BetaError = ErrorObject
public typealias BetaErrorResponse = ErrorResponse
