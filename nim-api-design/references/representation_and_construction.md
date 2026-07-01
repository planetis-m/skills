Use a value type for copyable configuration and a reference type only for a
session whose shared identity is part of the contract.

```nim
type
  EncoderOptions* = object
    encoderQuality: int
    encoderFormat: string

  EncoderSession* = ref object
    options: EncoderOptions
    encodedFrames: int

proc initEncoderOptions*(quality: range[1..100] = 80;
    format = "png"): EncoderOptions =
  EncoderOptions(encoderQuality: quality, encoderFormat: format)

proc newEncoderSession*(
    options = initEncoderOptions()): EncoderSession =
  EncoderSession(options: options)

func quality*(session: EncoderSession): int =
  session.options.encoderQuality

func quality*(options: EncoderOptions): int =
  options.encoderQuality

func format*(options: EncoderOptions): string =
  options.encoderFormat

proc recordFrame*(session: EncoderSession) =
  inc session.encodedFrames

let defaults = initEncoderOptions()
let custom = initEncoderOptions(95)
doAssert defaults.quality == 80
doAssert defaults.format == "png"

let session = newEncoderSession(custom)
let alias = session
alias.recordFrame()
doAssert session.encodedFrames == 1
doAssert session.quality == 95
```

## Key points

- `EncoderOptions` is plain copyable data, so `initEncoderOptions` returns a
  value.
- `EncoderSession` has intentional shared identity, so `newEncoderSession`
  returns a reference.
- The constrained constructor parameter is stored in a base `int` field.
- The simple construction paths keep sensible defaults.
