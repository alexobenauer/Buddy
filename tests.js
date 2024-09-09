#!/usr/bin/env deno test

import { assertEquals } from "https://deno.land/std/testing/asserts.ts";
import Lexer from './src/lexer.js';
import Parser from './src/parser.js';
import Transpiler from './src/transpiler.js';

function transpile(sourceCode, emitTS = false) {
  const lexer = new Lexer(sourceCode);
  const tokens = lexer.tokenize();
  const parser = new Parser(tokens);
  const ast = parser.parse();
  const transpiler = new Transpiler(ast, emitTS);
  return transpiler.transpile({ excludeRuntime: true });
}

function normalize(code) {
  return code.trim().replace(/\s+/g, ' ');
}

Deno.test("Simple variable declaration", () => {
  const input = "let x = 5";
  const expected = "const x = 5;";
  const result = transpile(input);
  assertEquals(result.trim(), expected);
});

Deno.test("Basic function declaration", () => {
  const input = `
    func greet(name: String) -> String {
      return "Hello, " + name + "!"
    }
  `;
  const expected = `
    function greet(params = {}) {
      const { name } = params;
      return "Hello, " + name + "!";
    }
  `;
  const result = transpile(input);
  assertEquals(normalize(result), normalize(expected));
});

Deno.test("Basic class declaration", () => {
  const input = `
    class Example {
      var value: String?

      init(value: String? = "yo") {
        self.value = value
      }
    }
  `;
  const expected = `
    class Example {
      value;

      constructor(params = {}) {
        const { value = "yo" } = params;
        this.value = value;
      }
    }
  `;
  const result = transpile(input);
  assertEquals(normalize(result), normalize(expected));
});