# Parameter Ownership

Choose parameter modes from caller-visible mutation and ownership.

```nim
type
  Job* = object
    name*: string
    payload*: seq[byte]

  JobQueue* = object
    jobs: seq[Job]

proc payloadLen*(job: Job): int =
  job.payload.len

proc rename*(job: var Job; name: string) =
  job.name = name

proc add*(queue: var JobQueue; job: sink Job) =
  queue.jobs.add job

proc jobs*(queue: JobQueue): lent seq[Job] =
  queue.jobs

proc example() =
  var queue: JobQueue
  queue.add Job(name: "temporary", payload: @[1'u8])

  var retained = Job(name: "retained", payload: @[2'u8])
  queue.add retained
  doAssert retained.name == "retained"

  var transferred = Job(name: "transferred", payload: @[3'u8])
  queue.add transferred
  doAssert jobs(queue)[^1].name == "transferred"

when isMainModule:
  example()
```

## Key points

- Use `T` when the caller's variable stays unchanged, `var T` when the proc changes it, and `sink T` when the proc takes ownership.
- Pass sink arguments normally: Nim moves proven last-use values and copies others. Use `ensureMove` only to reject a copy.
- Use `lent T` only for a borrowed return tied to receiver-owned storage.
