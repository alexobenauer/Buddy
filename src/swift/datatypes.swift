enum TokenType {
    case EOF, INT, DOUBLE, STRING, STRING_MULTILINE, CHARACTER, IDENTIFIER
    
    case IF, ELSE, GUARD, SWITCH, CASE, DEFAULT, FOR, IN, REPEAT, WHILE, VAR, LET, FUNC, RETURN, BREAK, CONTINUE
    case THROWS, THROW, DO, TRY, CATCH
    case STRUCT, ENUM, INDIRECT, PROTOCOL, EXTENSION, NIL, TRUE, FALSE, CLASS, INIT, DEINIT
    case STATIC, FINAL, PRIVATE, PUBLIC, INTERNAL, TYPEALIAS
    case GET, SET
    
    case PLUS, MINUS, STAR, DIVIDE, EQUAL, EQUAL_EQUAL, BANG, BANG_EQUAL
    case GREATER, LESS, GREATER_EQUAL, LESS_EQUAL, RIGHT_ARROW
    
    case LEFT_PAREN, RIGHT_PAREN, LEFT_BRACKET, RIGHT_BRACKET, LEFT_BRACE, RIGHT_BRACE
    case SEMICOLON, COLON, COMMA, DOT, DOT_DOT_DOT, DOT_DOT_LESS
    case QUESTION, QUESTION_QUESTION, AMPERSAND, AMPERSAND_AMPERSAND, PIPE, PIPE_PIPE
    case SELF, PLUS_EQUAL, MINUS_EQUAL
    
    case HASH, AT, BACKSLASH, TILDE, SLASH
}

let keywords: [String: TokenType] = [
    "if":       TokenType.IF,
    "else":     TokenType.ELSE,
    "guard":    TokenType.GUARD,
    "switch":   TokenType.SWITCH,
    "case":     TokenType.CASE,
    "default":  TokenType.DEFAULT,
    "for":      TokenType.FOR,
    "in":       TokenType.IN,
    "repeat":   TokenType.REPEAT,
    "while":    TokenType.WHILE,
    "break":    TokenType.BREAK,
    "continue": TokenType.CONTINUE,
    "var":      TokenType.VAR,
    "let":      TokenType.LET,
    "func":     TokenType.FUNC,
    "return":   TokenType.RETURN,
    "throws":   TokenType.THROWS,
    "throw":    TokenType.THROW,
    "do":       TokenType.DO,
    "try":      TokenType.TRY,
    "catch":    TokenType.CATCH,
    "struct":   TokenType.STRUCT,
    "enum":     TokenType.ENUM,
    "indirect": TokenType.INDIRECT,
    "protocol": TokenType.PROTOCOL,
    "extension": TokenType.EXTENSION,
    "nil":      TokenType.NIL,
    "true":     TokenType.TRUE,
    "false":    TokenType.FALSE,
    "class":    TokenType.CLASS,
    "init":     TokenType.INIT,
    "deinit":   TokenType.DEINIT,
    "static":   TokenType.STATIC,
    "final":    TokenType.FINAL,
    "private":  TokenType.PRIVATE,
    "public":   TokenType.PUBLIC,
    "internal": TokenType.INTERNAL,
    "self":     TokenType.SELF,
    "typealias": TokenType.TYPEALIAS,
    "get":      TokenType.GET,
    "set":      TokenType.SET
]

struct Token {
    let type: TokenType
    let value: String
    let line: Int
    let column: Int
}

protocol ASTNode {}


struct ParserError: Error {
    let message: String
    
    init(_ message: String) {
        self.message = message
    }
}

struct VarDeclaration: ASTNode {
    let name: Token
    let type: TypeIdentifier?
    var initializer: ASTNode?
    let isConstant: Bool
}

struct StructDeclaration: ASTNode {
    let name: Token
    let inheritedTypes: [Token]
    var members: [ASTNode]
}

struct ClassDeclaration: ASTNode {
    let name: Token
    let inheritedTypes: [Token]
    let methods: [FunctionDeclaration]
    let properties: [ASTNode]
}

struct FunctionDeclaration: ASTNode {
    let name: Token
    let kind: Kind
    let isStatic: Bool
    let parameters: [Parameter]
    let returnType: TypeIdentifier?
    let body: BlockStatement

    enum Kind {
        case method
        case initializer
        case function
    }
}

struct Parameter {
    let externalName: Token?
    let internalName: Token
    let type: TypeIdentifier
    let isVariadic: Bool
    let defaultValue: ASTNode?
}

indirect enum TypeIdentifier {
    case identifier(Token)
    case array(TypeIdentifier)
    case dictionary(TypeIdentifier, TypeIdentifier)
    case optional(TypeIdentifier)
}

struct EnumDeclaration: ASTNode {
    let name: Token
    let cases: [EnumCase]
}

struct EnumCase {
    let name: Token
    let rawValue: ASTNode?
    let associatedValues: [Parameter]
}

struct ProtocolDeclaration: ASTNode {
    let name: Token
    let inheritedProtocols: [Token]
    let members: [ASTNode]
}

struct ProtocolPropertyDeclaration: ASTNode {
    let name: Token
    let propertyType: TypeIdentifier
    let isConstant: Bool
    let getter: Bool
    let setter: Bool
}

struct ProtocolMethodDeclaration: ASTNode {
    let name: Token
    let parameters: [Parameter]
    let returnType: TypeIdentifier?
}

struct TypealiasDeclaration: ASTNode {
    let name: Token
    let type: TypeIdentifier
}

struct IfStatement: ASTNode {
    let condition: ASTNode
    let thenBranch: ASTNode
    let elseBranch: ASTNode?
}

struct IfLetStatement: ASTNode {
    let name: Token
    let value: ASTNode?
    let thenBranch: ASTNode
    let elseBranch: ASTNode?
}

struct GuardStatement: ASTNode {
    let condition: ASTNode
    let body: ASTNode
}

struct GuardLetStatement: ASTNode {
    let name: Token
    let value: ASTNode?
    let body: ASTNode
}

struct SwitchStatement: ASTNode {
    let expression: ASTNode
    let cases: [SwitchCase]
    let defaultCase: [ASTNode]?
}

struct SwitchCase {
    let expressions: [ASTNode]
    let statements: [ASTNode]
}

struct ForStatement: ASTNode {
    let variable: Token
    let iterable: ASTNode
    let body: ASTNode
}

struct WhileStatement: ASTNode {
    let condition: ASTNode
    let body: ASTNode
}

struct RepeatStatement: ASTNode {
    let body: ASTNode
    let condition: ASTNode
}

struct ReturnStatement: ASTNode {
    let value: ASTNode?
}

struct BreakStatement: ASTNode {}

struct ContinueStatement: ASTNode {}

struct BlankStatement: ASTNode {}

struct BlockStatement: ASTNode {
    let statements: [ASTNode]
}

struct ExpressionStatement: ASTNode {
    let expression: ASTNode
}

struct AssignmentExpression: ASTNode {
    let target: ASTNode
    let value: ASTNode
    let op: TokenType
}

struct BinaryExpression: ASTNode {
    let left: ASTNode
    let right: ASTNode
    let op: TokenType
}

struct LogicalExpression: ASTNode {
    let left: ASTNode
    let right: ASTNode
    let op: TokenType
}

struct BinaryRangeExpression: ASTNode {
    let left: ASTNode
    let right: ASTNode
    let op: TokenType
}

struct UnaryExpression: ASTNode {
    let op: TokenType
    let operand: ASTNode
}

struct Argument {
    let label: Token?
    let value: ASTNode
}

struct CallExpression: ASTNode {
    let callee: ASTNode
    let arguments: [Argument]
    var isOptional: Bool = false
    var isMember: Bool = false // if true, then this call is a member of a class or struct; if false, then this call is a standalone function call
}

struct GetExpression: ASTNode {
    let object: ASTNode
    let name: Token
    var isOptional: Bool = false
}

struct IndexExpression: ASTNode {
    let object: ASTNode
    let index: ASTNode
    var isOptional: Bool = false
}

struct OptionalChainingExpression: ASTNode {
    let object: ASTNode
    var forceUnwrap: Bool = false
}

struct LiteralExpression: ASTNode {
    let value: Any?
}

struct StringLiteralExpression: ASTNode {
    let value: String
    var isMultiLine: Bool = false
}

struct IntLiteralExpression: ASTNode {
    let value: Int
}

struct DoubleLiteralExpression: ASTNode {
    let value: Double
}

struct SelfExpression: ASTNode {}

struct VariableExpression: ASTNode {
    let name: Token
    var isMember: Bool = false // if true, then this variable is a member of a class or struct; if false, then this variable is a local or global variable
}

struct GroupingExpression: ASTNode {
    let expression: ASTNode
}

struct ArrayLiteralExpression: ASTNode {
    let elements: [ASTNode]
}

struct KeyValuePair {
    let key: ASTNode
    let value: ASTNode
}

struct DictionaryLiteralExpression: ASTNode {
    let elements: [KeyValuePair]
}

