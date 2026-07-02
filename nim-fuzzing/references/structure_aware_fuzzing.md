# Structure-aware fuzzing: length-prefixed frames

This example fuzzes a small binary protocol:

```text
kind: byte | payload length: byte | payload
```

Ordinary byte mutations often make the length field disagree with the
payload. The custom mutator decodes the frame, changes one field, and encodes
it again.

## Complete target

```nim
import std/random

type
  Frame = object
    kind: byte
    payload: seq[byte]

proc decodeFrame(input: openArray[byte]; frame: var Frame): bool =
  result = input.len >= 2
  if result:
    let payloadLen = int(input[1])
    result = payloadLen == input.len - 2
    if result:
      frame.kind = input[0]
      frame.payload = newSeq[byte](payloadLen)
      if payloadLen > 0:
        copyMem(addr frame.payload[0], unsafeAddr input[2], payloadLen)

proc processFrame(input: openArray[byte]) =
  var frame: Frame
  if not decodeFrame(input, frame):
    raise newException(ValueError, "invalid frame")
  if frame.kind > 3:
    raise newException(ValueError, "unknown frame kind")

  case frame.kind
  of 0:
    discard
  of 1:
    if frame.payload.len != 4:
      raise newException(ValueError, "invalid ping")
  of 2:
    if frame.payload.len == 0:
      raise newException(ValueError, "empty data frame")
  of 3:
    if frame.payload.len > 32:
      raise newException(ValueError, "control frame too large")
  else:
    discard

proc encodeFrame(
    frame: Frame;
    data: ptr UncheckedArray[byte];
    maxLen: int
): int =
  result = 0
  if maxLen >= 2 and
      frame.payload.len <= 255 and
      frame.payload.len <= maxLen - 2:
    data[0] = frame.kind
    data[1] = byte(frame.payload.len)
    if frame.payload.len > 0:
      copyMem(addr data[2], unsafeAddr frame.payload[0], frame.payload.len)
    result = frame.payload.len + 2

proc testOneInput(data: ptr UncheckedArray[byte], len: int): cint {.
    cdecl, exportc: "LLVMFuzzerTestOneInput", raises: [].} =
  result = 0
  try:
    processFrame(data.toOpenArray(0, len - 1))
  except ValueError:
    discard

proc customMutator(
    data: ptr UncheckedArray[byte];
    len, maxLen: int;
    seed: int64
): int {.cdecl, exportc: "LLVMFuzzerCustomMutator", raises: [].} =
  var frame: Frame
  if not decodeFrame(data.toOpenArray(0, len - 1), frame):
    frame = Frame(kind: 0)

  var rng = initRand(seed)
  let maxPayloadLen = min(255, max(0, maxLen - 2))
  case rng.rand(3)
  of 0:
    frame.kind = byte(rng.rand(0..3))
  of 1:
    if frame.payload.len > 0:
      let index = rng.rand(0..<frame.payload.len)
      frame.payload[index] = byte(rng.rand(255))
  of 2:
    if frame.payload.len < maxPayloadLen:
      frame.payload.add byte(rng.rand(255))
  of 3:
    if frame.payload.len > 0:
      frame.payload.setLen(frame.payload.len - 1)
  else:
    discard

  result = encodeFrame(frame, data, maxLen)
  if result == 0:
    result = len

proc initialize(): cint {.cdecl, exportc: "LLVMFuzzerInitialize".} =
  {.emit: "N_CDECL(void, NimMain)(void); NimMain();".}
```

## Why this pattern works

- `decodeFrame` rejects malformed input without reading past the buffer.
- The mutator repairs invalid input by starting from an empty valid frame.
- Every successful mutation updates the payload length.
- `encodeFrame` writes only when the complete frame fits in `maxLen`.
- `seed` controls all randomness, so mutations are reproducible.

Start with libFuzzer's built-in mutations. Add this pattern when malformed
inputs dominate and coverage stops improving.
