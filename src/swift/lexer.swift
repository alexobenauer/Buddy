class Lexer {
    let source: String
    var tokens: [Token]
    var start: Int
    var current: Int
    var line: Int
    var column: Int
    
    init(source: String) {
        self.source = source
        self.tokens = []
        self.start = 0
        self.current = 0
        self.line = 1
        self.column = 1
    }
    
    func addToken(type: TokenType, literal: String? = nil) {
        let text = String(source[source.index(source.startIndex, offsetBy: start)..<source.index(source.startIndex, offsetBy: current)])
        tokens.append(Token(type: type, value: literal ?? text, line: line, column: column - text.count))
    }
    
    func tokenize() -> [Token] {
        while !isAtEnd() {
            start = current
            scanToken()
        }
        
        tokens.append(Token(type: .EOF, value: "", line: line, column: column))
        return tokens
    }
    
    func scanToken() {
        let c = advance()
        switch c {
        case "(": addToken(type: .LEFT_PAREN)
        case ")": addToken(type: .RIGHT_PAREN)
        case "{": addToken(type: .LEFT_BRACE)
        case "}": addToken(type: .RIGHT_BRACE)
        case "[": addToken(type: .LEFT_BRACKET)
        case "]": addToken(type: .RIGHT_BRACKET)
        case ";": addToken(type: .SEMICOLON)
        case ":": addToken(type: .COLON)
        case ",": addToken(type: .COMMA)
        case "+":
            if match("=") {
                addToken(type: .PLUS_EQUAL)
            } else {
                addToken(type: .PLUS)
            }
        case "*": addToken(type: .STAR)
        case "/":
            if match("/") {
                // Single-line comment goes until the end of the line
                while peek() != "\n" && !isAtEnd() { advance() }
            } else if match("*") {
                // Multi-line comment
                while !isAtEnd() {
                    if peek() == "*" && peekNext() == "/" {
                        advance() // Consume the *
                        advance() // Consume the /
                        break
                    }
                    if peek() == "\n" {
                        line += 1
                    }
                    advance()
                }
            } else {
                addToken(type: .SLASH)
            }
        case ".":
            if match(".") {
                if match(".") {
                    addToken(type: .DOT_DOT_DOT)
                } else if match("<") {
                    addToken(type: .DOT_DOT_LESS)
                } else {
                    addToken(type: .DOT)
                    addToken(type: .DOT)
                }
            } else {
                addToken(type: .DOT)
            }
        case "=": addToken(type: match("=") ? .EQUAL_EQUAL : .EQUAL)
        case "!": addToken(type: match("=") ? .BANG_EQUAL : .BANG)
        case "<": addToken(type: match("=") ? .LESS_EQUAL : .LESS)
        case ">": addToken(type: match("=") ? .GREATER_EQUAL : .GREATER)
        case "-":
            if match("=") {
                addToken(type: .MINUS_EQUAL)
            } else if match(">") {
                addToken(type: .RIGHT_ARROW)
            } else {
                addToken(type: .MINUS)
            }
        case "?": addToken(type: match("?") ? .QUESTION_QUESTION : .QUESTION)
        case "&": addToken(type: match("&") ? .AMPERSAND_AMPERSAND : .AMPERSAND)
        case "|": addToken(type: match("|") ? .PIPE_PIPE : .PIPE)
        case "#": addToken(type: .HASH)
        case "@": addToken(type: .AT)
        case "\\": addToken(type: .BACKSLASH)
        case "^": addToken(type: .CARET)
        case "~": addToken(type: .TILDE)
        case " ", "\r", "\t": break // Ignore whitespace
        case "\n":
            line += 1
            column = 1
        case "\"": string()
        case "'": character()
        default:
            if isDigit(c) {
                number()
            } else if isAlpha(c) {
                identifier()
            } else {
                fatalError("Unexpected character: \(c) at line \(line), column \(column)")
            }
        }
    }
    
    func string() {
        while peek() != "\"" && !isAtEnd() {
            if peek() == "\n" {
                line += 1
                column = 1
            }
            if peek() == "\\" && peekNext() == "\"" {
                advance() // Consume the backslash
            }
            advance()
        }
        
        if isAtEnd() {
            fatalError("Unterminated string at line \(line), column \(column)")
        }
        
        // The closing "
        advance()
        
        // Trim the surrounding quotes
        let value = String(source[source.index(source.startIndex, offsetBy: start + 1)..<source.index(source.startIndex, offsetBy: current - 1)])
        addToken(type: .STRING, literal: value)
    }
    
    func character() {
        if isAtEnd() || peek() == "\n" {
            fatalError("Unterminated character literal at line \(line), column \(column)")
        }
        advance() // Consume the character
        if peek() != "'" {
            fatalError("Invalid character literal at line \(line), column \(column)")
        }
        advance() // Consume the closing '
        
        let value = String(source[source.index(source.startIndex, offsetBy: start + 1)..<source.index(source.startIndex, offsetBy: current - 1)])
        addToken(type: .CHARACTER, literal: value)
    }
    
    func number() {
        while isDigit(peek()) { advance() }
        
        // Look for a fractional part
        if peek() == "." && isDigit(peekNext()) {
            // Consume the "."
            advance()
            
            while isDigit(peek()) { advance() }
        }
        
        // Look for an exponent part
        if peek().lowercased() == "e" {
            advance()
            if peek() == "+" || peek() == "-" { advance() }
            if !isDigit(peek()) {
                fatalError("Invalid number format at line \(line), column \(column)")
            }
            while isDigit(peek()) { advance() }
        }
        
        let value = String(source[source.index(source.startIndex, offsetBy: start)..<source.index(source.startIndex, offsetBy: current)])
        addToken(type: .NUMBER, literal: value)
    }
    
    func identifier() {
        while isAlphaNumeric(peek()) { advance() }
        
        let text = String(source[source.index(source.startIndex, offsetBy: start)..<source.index(source.startIndex, offsetBy: current)])
        let type = keywords[text] ?? .IDENTIFIER
        addToken(type: type)
    }
    
    func isAtEnd() -> Bool {
        return current >= source.count
    }
    
    @discardableResult
    func advance() -> Character {
        let char = source[source.index(source.startIndex, offsetBy: current)]
        current += 1
        column += 1
        return char
    }
    
    func peek() -> Character {
        if isAtEnd() { return "\0" }
        return source[source.index(source.startIndex, offsetBy: current)]
    }
    
    func peekNext() -> Character {
        if current + 1 >= source.count { return "\0" }
        return source[source.index(source.startIndex, offsetBy: current + 1)]
    }
    
    func match(_ expected: Character) -> Bool {
        if isAtEnd() { return false }
        if source[source.index(source.startIndex, offsetBy: current)] != expected { return false }
        
        current += 1
        column += 1
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
        return isAlpha(c) || isDigit(c)
    }
}