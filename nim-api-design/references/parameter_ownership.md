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

func totalBytes*(messages: openArray[Message]): int =
  for message in messages:
    result += message.payload.len

proc markQueued*(messages: var openArray[Message]) =
  for message in messages.mitems:
    message.queued = true

proc clear*(messages: var seq[Message]) =
  messages.setLen 0

proc add*(queue: var MessageQueue; message: sink Message) =
  queue.messages.add message

proc messages*(queue: MessageQueue): lent seq[Message] =
  queue.messages

var pending = @[
  Message(topic: "build", payload: @[1'u8, 2'u8]),
  Message(topic: "test", payload: @[3'u8])
]
doAssert totalBytes(pending) == 3
markQueued(pending)
doAssert pending[0].queued

var queue: MessageQueue
var retained = pending[0]
queue.add retained
retained.topic = "caller-owned"
doAssert queue.messages[0].topic == "build"

queue.add Message(topic: "deploy", payload: @[4'u8])
doAssert queue.messages.len == 2
clear(pending)
doAssert pending.len == 0
```

## Key points

- `openArray` reads several caller container shapes.
- `var openArray` mutates elements without permitting resize or replacement.
- `var seq` exposes caller-visible resizing.
- `sink` allows move-or-copy ownership transfer; retained values may be
  copied.
- `lent` returns storage borrowed from the queue.
