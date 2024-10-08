class Token {
  constructor(type, value, line, column) {
    this.type = type;
    this.value = value;
    this.line = line;
    this.column = column;
  }
}

class Lexer {
  constructor(source) {
    this.source = source;
    this.tokens = [];
    this.start = 0;
    this.current = 0;
    this.line = 1;
    this.column = 1;
  }

  addToken(type, literal = null) {
    const text = this.source.substring(this.start, this.current);
    this.tokens.push(new Token(type, literal || text, this.line, this.column - text.length));
  }

  tokenize() {
    while (!this.isAtEnd()) {
      this.start = this.current;
      this.scanToken();
    }

    this.tokens.push(new Token(TT.EOF, '', this.line, this.column));
    return this.tokens;
  }

  scanToken() {
    const c = this.advance();
    switch (c) {
      case '(': this.addToken(TT.LEFT_PAREN); break;
      case ')': this.addToken(TT.RIGHT_PAREN); break;
      case '{': this.addToken(TT.LEFT_BRACE); break;
      case '}': this.addToken(TT.RIGHT_BRACE); break;
      case '[': this.addToken(TT.LEFT_BRACKET); break;
      case ']': this.addToken(TT.RIGHT_BRACKET); break;
      case ';': this.addToken(TT.SEMICOLON); break;
      case ':': this.addToken(TT.COLON); break;
      case ',': this.addToken(TT.COMMA); break;
      case '+':
        if (this.match('=')) {
          this.addToken(TT.PLUS_EQUAL);
        } 
        else {
          this.addToken(TT.PLUS);
        }
        break;
      case '*': this.addToken(TT.STAR); break;
      case '/':
        if (this.match('/')) {
          // Single-line comment goes until the end of the line
          while (this.peek() !== '\n' && !this.isAtEnd()) this.advance();
        } 
        else if (this.match('*')) {
          // Multi-line comment
          while (!this.isAtEnd()) {
            if (this.peek() === '*' && this.peekNext() === '/') {
              this.advance(); // Consume the *
              this.advance(); // Consume the /
              break;
            }
            if (this.peek() === '\n') {
              this.line++;
            }
            this.advance();
          }
        } 
        else {
          this.addToken(TT.SLASH);
        }
        break;
      case '.':
        if (this.match('.')) {
          if (this.match('.')) {
            this.addToken(TT.CLOSED_RANGE);
          }
          else if (this.match('<')) {
            this.addToken(TT.HALF_OPEN_RANGE);
          }
          else {
            this.addToken(TT.DOT);
            this.addToken(TT.DOT);
          }
        } else {
          this.addToken(TT.DOT);
        }
        break;
      case '=':
        this.addToken(this.match('=') ? TT.EQUAL_EQUAL : TT.EQUAL);
        break;
      case '!':
        this.addToken(this.match('=') ? TT.BANG_EQUAL : TT.BANG);
        break;
      case '<':
        this.addToken(this.match('=') ? TT.LESS_EQUAL : TT.LESS);
        break;
      case '>':
        this.addToken(this.match('=') ? TT.GREATER_EQUAL : TT.GREATER);
        break;
      case '-':
        if (this.match('=')) {
          this.addToken(TT.MINUS_EQUAL);
        } 
        else if (this.match('>')) {
          this.addToken(TT.RIGHT_ARROW);
        } 
        else {
          this.addToken(TT.MINUS);
        }
        break;
      case '?':
        this.addToken(this.match('?') ? TT.QUESTION_QUESTION : TT.QUESTION);
        break;
      case '&':
        this.addToken(this.match('&') ? TT.AMPERSAND_AMPERSAND : TT.AMPERSAND);
        break;
      case '|':
        this.addToken(this.match('|') ? TT.PIPE_PIPE : TT.PIPE);
        break;
      case '#': this.addToken(TT.HASH); break;
      case '@': this.addToken(TT.AT); break;
      case '\\': this.addToken(TT.BACKSLASH); break;
      case '^': this.addToken(TT.CARET); break;
      case '~': this.addToken(TT.TILDE); break;

      // Whitespace
      case ' ':
      case '\r':
      case '\t':
        // Ignore whitespace
        break;
      case '\n':
        this.line++;
        this.column = 1;
        break;

      // String literals
      case '"': this.string(); break;
      case "'": this.character(); break;
      
      default:
        if (this.isDigit(c)) {
          this.number();
        } 
        else if (this.isAlpha(c)) {
          this.identifier();
        } 
        else {
          throw new Error(`Unexpected character: ${c} at line ${this.line}, column ${this.column}`);
        }
        break;
    }
  }

  string() {
    while (this.peek() !== '"' && !this.isAtEnd()) {
      if (this.peek() === '\n') {
        this.line++;
        this.column = 1;
      }
      if (this.peek() === '\\' && this.peekNext() === '"') {
        this.advance(); // Consume the backslash
      }
      this.advance();
    }

    if (this.isAtEnd()) {
      throw new Error(`Unterminated string at line ${this.line}, column ${this.column}`);
    }

    // The closing "
    this.advance();

    // Trim the surrounding quotes
    const value = this.source.substring(this.start + 1, this.current - 1);
    this.addToken('STRING', value);
  }

  character() {
    if (this.isAtEnd() || this.peek() === '\n') {
      throw new Error(`Unterminated character literal at line ${this.line}, column ${this.column}`);
    }
    this.advance(); // Consume the character
    if (this.peek() !== "'") {
      throw new Error(`Invalid character literal at line ${this.line}, column ${this.column}`);
    }
    this.advance(); // Consume the closing '

    const value = this.source.substring(this.start + 1, this.current - 1);
    this.addToken('CHARACTER', value);
  }

  number() {
    while (this.isDigit(this.peek())) this.advance();

    // Look for a fractional part
    if (this.peek() === '.' && this.isDigit(this.peekNext())) {
      // Consume the "."
      this.advance();

      while (this.isDigit(this.peek())) this.advance();
    }

    // Look for an exponent part
    if (this.peek().toLowerCase() === 'e') {
      this.advance();
      if (this.peek() === '+' || this.peek() === '-') this.advance();
      if (!this.isDigit(this.peek())) {
        throw new Error(`Invalid number format at line ${this.line}, column ${this.column}`);
      }
      while (this.isDigit(this.peek())) this.advance();
    }

    this.addToken('NUMBER',
      parseFloat(this.source.substring(this.start, this.current)));
  }

  identifier() {
    while (this.isAlphaNumeric(this.peek())) this.advance();

    const text = this.source.substring(this.start, this.current);
    const type = keywords[text] || 'IDENTIFIER';
    this.addToken(type);
  }

  isAtEnd() {
    return this.current >= this.source.length;
  }

  advance() {
    this.column++;
    return this.source.charAt(this.current++);
  }

  peek() {
    if (this.isAtEnd()) return '\0';
    return this.source.charAt(this.current);
  }

  peekNext() {
    if (this.current + 1 >= this.source.length) return '\0';
    return this.source.charAt(this.current + 1);
  }

  match(expected) {
    if (this.isAtEnd()) return false;
    if (this.source.charAt(this.current) !== expected) return false;

    this.current++;
    this.column++;
    return true;
  }

  isDigit(c) {
    return c >= '0' && c <= '9';
  }

  isAlpha(c) {
    return (c >= 'a' && c <= 'z') ||
           (c >= 'A' && c <= 'Z') ||
           c === '_';
  }

  isAlphaNumeric(c) {
    return this.isAlpha(c) || this.isDigit(c);
  }
}

const TokenTypes = Object.freeze({
  EOF: "EOF",
  NUMBER: "NUMBER",
  STRING: "STRING",
  CHARACTER: "CHARACTER",
  IDENTIFIER: "IDENTIFIER",

  IF: "IF",
  ELSE: "ELSE",
  GUARD: "GUARD",
  SWITCH: "SWITCH",
  CASE: "CASE",
  DEFAULT: "DEFAULT",
  FOR: "FOR",
  IN: "IN",
  WHILE: "WHILE",
  VAR: "VAR",
  LET: "LET",
  FUNC: "FUNC",
  RETURN: "RETURN",
  STRUCT: "STRUCT",
  ENUM: "ENUM",
  PROTOCOL: "PROTOCOL",
  EXTENSION: "EXTENSION",
  NIL: "NIL",
  TRUE: "TRUE",
  FALSE: "FALSE",
  CLASS: "CLASS",
  INIT: "INIT",
  DEINIT: "DEINIT",
  OVERRIDE: "OVERRIDE",
  STATIC: "STATIC",
  FINAL: "FINAL",
  PRIVATE: "PRIVATE",
  PUBLIC: "PUBLIC",
  INTERNAL: "INTERNAL",
  TYPEALIAS: "TYPEALIAS",

  PLUS: "PLUS",
  MINUS: "MINUS",
  STAR: "STAR", 
  DIVIDE: "DIVIDE",
  EQUAL: "EQUAL",
  EQUAL_EQUAL: "EQUAL_EQUAL",
  BANG: "BANG",
  BANG_EQUAL: "BANG_EQUAL",
  GREATER: "GREATER",
  LESS: "LESS",
  GREATER_EQUAL: "GREATER_EQUAL",
  LESS_EQUAL: "LESS_EQUAL",
  RIGHT_ARROW: "RIGHT_ARROW",

  LEFT_PAREN: "LEFT_PAREN",
  RIGHT_PAREN: "RIGHT_PAREN",
  LEFT_BRACKET: "LEFT_BRACKET",
  RIGHT_BRACKET: "RIGHT_BRACKET",
  LEFT_BRACE: "LEFT_BRACE",
  RIGHT_BRACE: "RIGHT_BRACE",
  SEMICOLON: "SEMICOLON",
  COLON: "COLON",
  COMMA: "COMMA",
  DOT: "DOT",
  CLOSED_RANGE: "CLOSED_RANGE",
  HALF_OPEN_RANGE: "HALF_OPEN_RANGE",
  QUESTION: "QUESTION",
  QUESTION_QUESTION: "QUESTION_QUESTION",
  AMPERSAND: "AMPERSAND",
  AMPERSAND_AMPERSAND: "AMPERSAND_AMPERSAND",
  PIPE: "PIPE",
  PIPE_PIPE: "PIPE_PIPE",
  SELF: "SELF",
  PLUS_EQUAL: "PLUS_EQUAL",
  MINUS_EQUAL: "MINUS_EQUAL",
});

const TT = TokenTypes;

export const keywords = {
  "if": TT.IF,
  "else": TT.ELSE,
  "guard": TT.GUARD,
  "switch": TT.SWITCH,
  "case": TT.CASE,
  "default": TT.DEFAULT,
  "for": TT.FOR,
  "in": TT.IN,
  "while": TT.WHILE,
  "var": TT.VAR,
  "let": TT.LET,
  "func": TT.FUNC,
  "return": TT.RETURN,
  "struct": TT.STRUCT,
  "enum": TT.ENUM,
  "protocol": TT.PROTOCOL,
  "extension": TT.EXTENSION,
  "nil": TT.NIL,
  "true": TT.TRUE,
  "false": TT.FALSE,
  "class": TT.CLASS,
  "init": TT.INIT,
  "deinit": TT.DEINIT,
  "override": TT.OVERRIDE,
  "static": TT.STATIC,
  "final": TT.FINAL,
  "private": TT.PRIVATE,
  "public": TT.PUBLIC,
  "internal": TT.INTERNAL,
  "self": TT.SELF,
  "typealias": TT.TYPEALIAS,
};

export default Lexer;
export { TokenTypes, TT, Token };

// Example usage
// const input = `
// func greet(name: String) {
//   let message = "Hello, " + name + "!"
//   return message
// }

// let result = greet(name: "World")
// print(result)
// `;

// const lexer = new Lexer(input);
// const tokens = lexer.tokenize();
// console.log(tokens);