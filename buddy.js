#!/usr/bin/env deno run --allow-read --allow-write

import Lexer from './src/js/lexer.js';
import Parser from './src/js/parser.js';
import Transpiler from './src/js/transpiler.js';

const args = Deno.args;
const debug = args.includes('-debug');
const verbose = args.includes('-verbose');
const emitTS = args.includes('-ts');
const command = args[0];

if (args.length < 2 || (command !== 'compile' && command !== 'interpret')) {
  console.log('Usage: buddy.js [compile|interpret] [-debug] [-verbose] <filename1> <filename2> ...');
} else {
  const fileContents = await Promise.all(args.slice(1).filter(arg => arg !== '-debug' && arg !== '-ts' && arg !== '-verbose').map(async (filename) => {
    return await Deno.readTextFile(filename);
  }));
  const combinedContents = fileContents.join('\n');

  const output = transpile(combinedContents, emitTS, debug, verbose);

  if (command === 'compile') {
    await Deno.mkdir('_build', { recursive: true });
    await Deno.writeTextFile(`_build/output.${emitTS ? 'ts' : 'js'}`, output);
    console.log(`Compiled output saved to _build/output.${emitTS ? 'ts' : 'js'}`);
  } else if (command === 'interpret') {
    if (debug) console.log("\n=== EVAL ===");
    eval(output);
  }
}

function transpile(sourceCode, emitTS = false, debug = false, verbose = false) {
  if (debug) console.log("\n=== TOKENS ===");

  const lexer = new Lexer(sourceCode);
  const tokens = lexer.tokenize();
  
  if (debug) console.log(tokens);

  if (debug) console.log("\n=== AST ===");

  const parser = new Parser(tokens);
  const ast = parser.parse();

  if (debug && verbose) console.log(JSON.stringify(ast, null, 2));
  if (debug) console.log(ast);

  if (debug) console.log("\n=== JS ===");

  const transpiler = new Transpiler(ast, emitTS);
  const output = transpiler.transpile();

  if (debug) console.log(output);

  return output;
}
