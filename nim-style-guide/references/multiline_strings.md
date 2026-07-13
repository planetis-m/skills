Triple-quoted multiline string patterns: leading newline, concatenation around
interpolated values, and `dedent` for shared indentation.

```nim
import std/strutils

# Nim strips a newline right after the opening """, so both forms are equal.
let a = """
foo
bar
"""
let b = """foo
bar
"""
doAssert a == b

# Without the leading newline here, the result would be "documentsWHERE".
let q = """SELECT id
FROM """ & tableName & """

WHERE id = ?"""

# dedent removes common leading whitespace; extra indentation on a line is kept.
let x = """
      Hello
        There
    """.dedent()

doAssert x == "Hello\n  There\n"
```

## Key points

- Nim strips one newline immediately after the opening `"""`.
- In a `&` join, each literal is taken verbatim; the newline is the only
  separator, so dropping it fuses adjacent tokens.
- `dedent()` removes the common leading whitespace only.
