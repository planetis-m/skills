# Module Layout

Shared raw types plus selective ergonomic re-exports for a multi-module wrapper.

```nim
# lib_raw_types.nim
type
  SharedHandle* = object
    id*: cint

# lib_raw_audio.nim
import ./lib_raw_types

proc openAudio*(id: cint): SharedHandle =
  SharedHandle(id: id)

# lib_raw_video.nim
import ./lib_raw_types

proc openVideo*(id: cint): SharedHandle =
  SharedHandle(id: id)

# lib_api.nim
import ./lib_raw_audio
import ./lib_raw_video
import ./lib_raw_types

export SharedHandle, openAudio, openVideo

proc openDefaultAudio*(): SharedHandle =
  openAudio(10)
```

## When to use

- Use this layout when several raw modules share handle or enum types.
- Keep the shared-type module boring and dependency-light so it does not pull wrapper code back into the raw layer.
- Re-export only the stable ergonomic surface from the top-level API module.
