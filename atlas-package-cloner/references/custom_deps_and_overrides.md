Use a custom dependency directory and Atlas override fields.

# Example

Use this when the repository intentionally keeps dependency clones outside the default `deps/` directory or needs a fork/private URL mapping.

```bash
atlas init --deps=vendor/atlas-deps
```

Then edit `vendor/atlas-deps/atlas.config`:

```json
{
  "deps": "vendor/atlas-deps",
  "nameOverrides": {
    "customProject": "https://gitlab.company.com/customProject"
  },
  "urlOverrides": {
    "https://github.com/upstream/pkg": "https://github.com/fork/pkg"
  },
  "pkgOverrides": {
    "pkg": "https://github.com/fork/pkg"
  },
  "plugins": "",
  "resolver": "SemVer",
  "graph": null
}
```

Run the dependency operation after the config is in place:

```bash
atlas --forceGitToHttps install
```

# Key points

- `atlas init --deps=DIR` writes `DIR/atlas.config`.
- Use `nameOverrides`, `urlOverrides`, and `pkgOverrides` in Atlas config instead of editing generated `nim.cfg` paths.
- `--forceGitToHttps` is available when `git://` dependency URLs need HTTPS rewriting.
