**Ignore this repo. Nothing good can come from taking it seriously.**

Buddy is a Swift-like language for the browser and other JS contexts. It implements a subset of Swift’s core features, and extends it with a few improvements. It can be compiled into Javascript or Typescript in the browser, on the server, or from the command line.

To run the transpiler, make `./buddy.js` executable and run it. It expects a command line argument of either `compile` or `interpret`, followed by a list of Swift files to compile or interpret. Pass `-debug` to see the tokens and AST. Pass `-ts` to output TypeScript instead of JavaScript. Deno must be installed. Example usage:

```bash
./buddy.js compile src/test.swift
```

To run the test suite, run `deno test`.

To preview a website locally, run `vite` from the root directory and navigate to `http://localhost:5173/examples/index.html`.
