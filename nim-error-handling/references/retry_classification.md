Retry loop example that separates retriable failures from final failures.

```nim
type
  RetryDecision = enum
    retryNow, failFinal

proc classifyFailure(statusCode: int): RetryDecision =
  case statusCode
  of 408, 429, 500, 502, 503, 504:
    retryNow
  else:
    failFinal

proc shouldRetry(attempt, maxAttempts: int; statusCode: int): bool =
  classifyFailure(statusCode) == retryNow and attempt < maxAttempts

proc requestWithRetry(maxAttempts: int; responses: openArray[int]): string =
  for i, statusCode in responses:
    let attempt = i + 1
    if statusCode == 200:
      return "ok"
    if not shouldRetry(attempt, maxAttempts, statusCode):
      raise newException(IOError,
        "request failed at attempt " & $attempt & " with status " & $statusCode)
  raise newException(IOError, "request produced no successful response")
```

Key points
- Classify retryable failures separately from final failures.
- Retry only when the failure is retryable and attempts remain.
- Raise once when the failure is final.
