class Lexer {
    let source: String
    let sourceLength: Int
    var tokens: [Token]
    var start: Int
    var current: Int
    var line: Int
    var column: Int
    
    init(source: String) {
        self.source = source
        self.sourceLength = source.count
        self.tokens = []
        self.start = 0
        self.current = 0
        self.line = 1
        self.column = 1
    }
    
    func addToken(type: TokenType, literal: String? = nil) {
        let text = substr(self.source, start: self.start, end: self.current)
        self.tokens.append(
          Token(
            type: type,
            value: literal ?? text,
            line: self.line,
            column: self.column - text.count,
            endOfLine: self.peek() == "\n"
          )
        )
    }
    
    func tokenize() -> [Token] {
        while !self.isAtEnd() {
            self.start = self.current
            self.scanToken()
        }
        
        self.tokens.append(
          Token(
            type: TokenType.EOF,
            value: "",
            line: self.line,
            column: self.column,
            endOfLine: true
          )
        )
        return self.tokens
    }
    
    func scanToken() {
        let c = self.advance()
        switch c {
        case "(": self.addToken(type: TokenType.LEFT_PAREN)
        case ")": self.addToken(type: TokenType.RIGHT_PAREN)
        case "{": self.addToken(type: TokenType.LEFT_BRACE)
        case "}": self.addToken(type: TokenType.RIGHT_BRACE)
        case "[": self.addToken(type: TokenType.LEFT_BRACKET)
        case "]": self.addToken(type: TokenType.RIGHT_BRACKET)
        case ";": self.addToken(type: TokenType.SEMICOLON)
        case ":": self.addToken(type: TokenType.COLON)
        case ",": self.addToken(type: TokenType.COMMA)
        case "+":
            if self.match("=") {
                self.addToken(type: TokenType.PLUS_EQUAL)
            } else {
                self.addToken(type: TokenType.PLUS)
            }
        case "*": self.addToken(type: TokenType.STAR)
        case "/":
            if self.match("/") {
                // Single-line comment goes until the end of the line
                while self.peek() != "\n" && !self.isAtEnd() { self.advance() }
            } else if self.match("*") {
                // Multi-line comment
                while !self.isAtEnd() {
                    if self.peek() == "*" && self.peekNext() == "/" {
                        self.advance() // Consume the *
                        self.advance() // Consume the /
                        break
                    }
                    if self.peek() == "\n" {
                        self.line += 1
                    }
                    self.advance()
                }
            } else {
                self.addToken(type: TokenType.SLASH)
            }
        case ".":
            if self.match(".") {
                if self.match(".") {
                    self.addToken(type: TokenType.DOT_DOT_DOT)
                } else if self.match("<") {
                    self.addToken(type: TokenType.DOT_DOT_LESS)
                } else {
                    self.addToken(type: TokenType.DOT)
                    self.addToken(type: TokenType.DOT)
                }
            } else {
                self.addToken(type: TokenType.DOT)
            }
        case "=":
            if self.match("=") {
                self.addToken(type: TokenType.EQUAL_EQUAL)
            } else {
                self.addToken(type: TokenType.EQUAL)
            }
        case "!":
            if self.match("=") {
                self.addToken(type: TokenType.BANG_EQUAL)
            } 
            else if self.peekPreviousPrevious() == " " || self.peekPreviousPrevious() == "\n" || self.peekPreviousPrevious() == "\r" || self.peekPreviousPrevious() == "\t" {
                self.addToken(type: TokenType.BANG)
            }
            else {
                self.addToken(type: TokenType.ATTACHED_BANG)
            }
        case "<":
            if self.match("=") {
                self.addToken(type: TokenType.LESS_EQUAL)
            } else {
                self.addToken(type: TokenType.LESS)
            }
        case ">":
            if self.match("=") {
                self.addToken(type: TokenType.GREATER_EQUAL)
            } else {
                self.addToken(type: TokenType.GREATER)
            }
        case "-":
            if self.match("=") {
                self.addToken(type: TokenType.MINUS_EQUAL)
            } else if self.match(">") {
                self.addToken(type: TokenType.RIGHT_ARROW)
            } else {
                self.addToken(type: TokenType.MINUS)
            }
        case "?":
            if self.match("?") {
                self.addToken(type: TokenType.QUESTION_QUESTION)
            }
            else if self.peekPreviousPrevious() == " " || self.peekPreviousPrevious() == "\n" || self.peekPreviousPrevious() == "\r" || self.peekPreviousPrevious() == "\t" {
                self.addToken(type: TokenType.QUESTION)
            }
            else {
                self.addToken(type: TokenType.ATTACHED_QUESTION)
            }
        case "&":
            if self.match("&") {
                self.addToken(type: TokenType.AMPERSAND_AMPERSAND)
            } else {
                self.addToken(type: TokenType.AMPERSAND)
            }
        case "|":
            if self.match("|") {
                self.addToken(type: TokenType.PIPE_PIPE)
            } else {
                self.addToken(type: TokenType.PIPE)
            }
        case "#": self.addToken(type: TokenType.HASH)
        case "@": self.addToken(type: TokenType.AT)
        case "\\": self.addToken(type: TokenType.BACKSLASH)
        case "~": self.addToken(type: TokenType.TILDE)
        case "$": self.addToken(type: TokenType.DOLLAR)
        case " ", "\r", "\t": break // Ignore whitespace
        case "\n":
            self.line += 1
            self.column = 1

        // TODO: Handle multi-line string literals
        case "\"":
            if self.peek() == "\"" && self.peekNext() == "\"" {
                self.advance()
                self.advance()
                self.multiLineString()
            } else {
                self.string()
            }
        case "'": self.character()
        default:
            if self.isDigit(c) {
                self.number()
            } else if self.isAlpha(c) {
                self.identifier()
            } else {
                fatalError("Unexpected character: \(c) at line \(self.line), column \(self.column)")
            }
        }
    }
    
    func string() {
        while self.peek() != "\"" && !self.isAtEnd() {
            if self.peek() == "\n" {
                self.line += 1
                self.column = 1
            }
            if self.peek() == "\\" {
                if self.peek() == "\"" && self.peekNext() == "\"" && self.peekNextNext() == "\"" {
                    self.advance()
                    self.advance()
                    self.advance()
                }
                else {
                    self.advance()
                }
            }
            self.advance()
        }
        
        if self.isAtEnd() {
            fatalError("Unterminated string at line \(self.line), column \(self.column)")
        }
        
        // The closing "
        self.advance()
        
        // Trim the surrounding quotes
        let value = substr(self.source, start: self.start + 1, end: self.current - 1)
        self.addToken(type: TokenType.STRING, literal: value)
    }

    func multiLineString() {
        while !(self.peek() == "\"" && self.peekNext() == "\"" && self.peekNextNext() == "\"") && !self.isAtEnd() {
            if self.peek() == "\n" {
                self.line += 1
                self.column = 1
            }
            if self.peek() == "\\" {
                if self.peek() == "\"" && self.peekNext() == "\"" && self.peekNextNext() == "\"" {
                    self.advance()
                    self.advance()
                    self.advance()
                }
                else {
                    self.advance()
                }
            }
            self.advance()
        }

        if self.isAtEnd() {
            fatalError("Unterminated string at line \(self.line), column \(self.column)")
        }

        // The closing quotes
        self.advance()
        self.advance()
        self.advance()

        let value = substr(self.source, start: self.start + 3, end: self.current - 3)
        self.addToken(type: TokenType.STRING_MULTILINE, literal: value)
    }
    
    func character() {
        if self.isAtEnd() || self.peek() == "\n" {
            fatalError("Unterminated character literal at line \(self.line), column \(self.column)")
        }
        self.advance() // Consume the character
        if self.peek() != "'" {
            fatalError("Invalid character literal at line \(self.line), column \(self.column)")
        }
        self.advance() // Consume the closing '
        
        let value = substr(self.source, start: self.start + 1, end: self.current - 1)
        self.addToken(type: TokenType.CHARACTER, literal: value)
    }
    
    func number() {
        var isDouble = false
        while self.isDigit(self.peek()) { self.advance() }
        
        // Look for a fractional part
        if self.peek() == "." && self.isDigit(self.peekNext()) {
            // Consume the "."
            self.advance()
            isDouble = true

            while self.isDigit(self.peek()) { self.advance() }
        }
        
        // Look for an exponent part
        // if peek().lowercased() == "e" {
        //     advance()
        //     if peek() == "+" || peek() == "-" { advance() }
        //     if !isDigit(peek()) {
        //         fatalError("Invalid number format at line \(line), column \(column)")
        //     }
        //     while isDigit(peek()) { advance() }
        // }
        
        let value = substr(self.source, start: self.start, end: self.current)
        var type = TokenType.INT
        if isDouble { type = TokenType.DOUBLE }
        self.addToken(type: type, literal: value)
    }
    
    func identifier() {
        while self.isAlphaNumeric(self.peek()) { self.advance() }
        
        let text = substr(self.source, start: self.start, end: self.current)
        let type = keywords[text] ?? TokenType.IDENTIFIER
        self.addToken(type: type)
    }
    
    func isAtEnd() -> Bool {
        return self.current >= self.sourceLength
    }
    
    @discardableResult
    func advance() -> Character {
        let char = charAt(self.source, index: self.current, stringLength: self.sourceLength)
        self.current += 1
        self.column += 1
        return char!
    }
    
    func peek() -> Character {
        if self.isAtEnd() { return "\0" }
        return charAt(self.source, index: self.current, stringLength: self.sourceLength)!
    }

    func peekPrevious() -> Character {
        if self.current - 1 < 0 { return "\0" }
        return charAt(self.source, index: self.current - 1, stringLength: self.sourceLength)!
    }

    func peekPreviousPrevious() -> Character {
        if self.current - 2 < 0 { return "\0" }
        return charAt(self.source, index: self.current - 2, stringLength: self.sourceLength)!
    }
    
    func peekNext() -> Character {
        if self.current + 1 >= self.sourceLength { return "\0" }
        return charAt(self.source, index: self.current + 1, stringLength: self.sourceLength)!
    }

    func peekNextNext() -> Character {
        if self.current + 2 >= self.sourceLength { return "\0" }
        return charAt(self.source, index: self.current + 2, stringLength: self.sourceLength)!
    }
    
    func match(_ expected: Character) -> Bool {
        if self.isAtEnd() { return false }
        if charAt(self.source, index: self.current, stringLength: self.sourceLength) != expected { return false }
        
        self.current += 1
        self.column += 1
        return true
    }
    
    func isDigit(_ c: Character) -> Bool {
        return c >= "0" && c <= "9"
    }
    
    func isAlpha(_ c: Character) -> Bool {
        return (c >= "a" && c <= "z") ||
               (c >= "A" && c <= "Z") ||
                c == "_"
    }
    
    func isAlphaNumeric(_ c: Character) -> Bool {
        return self.isAlpha(c) || self.isDigit(c)
    }
}
