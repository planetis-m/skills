Use a value type for copyable configuration and a reference type only for a
session whose shared identity is part of the contract.

```nim
type
  EncoderOptions* = object
    quality: int
    format: string

  EncoderSession* = ref object
    options: EncoderOptions
    frames: int

proc initEncoderOptions*(quality: range[1..100] = 80;
    format = "png"): EncoderOptions =
  EncoderOptions(quality: quality, format: format)

proc newEncoderSession*(
    options = initEncoderOptions()): EncoderSession =
  EncoderSession(options: options)

func quality*(s: EncoderSession): int {.inline.} =
  s.options.quality

func quality*(o: EncoderOptions): int {.inline.} =
  o.quality

func format*(o: EncoderOptions): string {.inline.} =
  o.format

proc recordFrame*(s: EncoderSession) =
  inc s.frames
```

## Key points

- `EncoderOptions` is plain copyable data, so `initEncoderOptions` returns a
  value.
- `EncoderSession` has intentional shared identity, so `newEncoderSession`
  returns a reference.
- The constrained constructor parameter is stored in a base `int` field.
- The simple construction paths keep sensible defaults.
