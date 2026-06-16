Run feature-aware installs and replay pinned dependencies.

# Example

Use this when the Nimble file declares optional feature dependencies or when CI should replay a pinned dependency set.

```bash
atlas --feature=test install
atlas --features="sqlite ssl" update
atlas --keepFeatures install
atlas pin
atlas --noexec rep atlas.lock
```

For all declared features, use:

```bash
atlas --allFeatures install
```

`atlas replay atlas.lock` and `atlas reproduce atlas.lock` are aliases for `atlas rep atlas.lock`.

# Key points

- Pass required features on each command, or use `--keepFeatures` to reuse feature defines from the current `nim.cfg`.
- Use `--noexec` for lockfile replay when build actions should not run.
- Keep `atlas.lock` with the repository only when the project policy expects pinned dependency commits.
