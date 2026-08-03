Choose parameter modes from caller-visible reading, element mutation,
resizing, ownership transfer, and borrowed return behavior.

```nim
type
  Message* = object
    topic*: string
    payload*: seq[byte]
    queued*: bool

  MessageQueue* = object
    messages: seq[Message]

func totalBytes*(msgs: openArray[Message]): int =
  for msg in msgs:
    result += msg.payload.len

proc markQueued*(msgs: var openArray[Message]) =
  for msg in msgs.mitems:
    msg.queued = true

proc clear*(msgs: var seq[Message]) =
  msgs.setLen 0

proc add*(q: var MessageQueue; msg: sink Message) =
  q.messages.add msg

proc messages*(q: MessageQueue): lent seq[Message] {.inline.} =
  q.messages
```

## Key points

- `openArray` supports read-only traversal of several caller container shapes.
- `var openArray` mutates elements without permitting resize or replacement.
- `var seq` exposes caller-visible resizing.
- `sink` allows move-or-copy ownership transfer; retained values may be
  copied.
- `lent` returns storage borrowed from the queue.
