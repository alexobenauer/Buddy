**Ignore this repo. Nothing good can come from taking it seriously.**

To run the transpiler, make `./src/swiftscript.js` executable and run it. It expects a command line argument of either `compile` or `interpret`, followed by a list of Swift files to compile or interpret. Pass `-debug` to see the tokens and AST. Pass `-ts` to output TypeScript instead of JavaScript. Deno must be installed. Example usage:

```bash
./src/swiftscript.js compile test.swift
```

To run the test suite, run `deno test test.ts`.

To preview the website locally, run `vite` from the root directory.
