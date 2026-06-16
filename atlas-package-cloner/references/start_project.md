Start an Atlas project and add a package dependency.

# Example

Use this when a repository has a Nimble file and should start using Atlas-managed dependencies.

```bash
atlas init
atlas use gh:user/repo
nim c src/main.nim
```

After `atlas init`, inspect `deps/atlas.config`. After `atlas use`, inspect the Atlas section in `nim.cfg` and compile the smallest Nim target that imports the new package.

# Key points

- `atlas init` creates `deps/atlas.config` by default.
- `gh:user/repo` is a verified forge alias for `https://github.com/user/repo`.
- Use the target project's own compile or test command as the final check.
