enum TokenType {
    case EOF, INT, DOUBLE, STRING, STRING_MULTILINE, CHARACTER, IDENTIFIER
    
    case IF, ELSE, GUARD, SWITCH, CASE, DEFAULT, FOR, IN, REPEAT, WHILE, VAR, LET, FUNC, RETURN, BREAK, CONTINUE
    case THROWS, THROW, DO, TRY, CATCH
    case STRUCT, ENUM, INDIRECT, PROTOCOL, EXTENSION, NIL, TRUE, FALSE, CLASS, INIT, DEINIT
    case STATIC, FINAL, PRIVATE, PUBLIC, INTERNAL, TYPEALIAS
    case AS, IS
    case GET, SET
    
    case PLUS, MINUS, STAR, DIVIDE, EQUAL, EQUAL_EQUAL, BANG, ATTACHED_BANG, BANG_EQUAL
    case GREATER, LESS, GREATER_EQUAL, LESS_EQUAL, RIGHT_ARROW
    
    case LEFT_PAREN, RIGHT_PAREN, LEFT_BRACKET, RIGHT_BRACKET, LEFT_BRACE, RIGHT_BRACE
    case SEMICOLON, COLON, COMMA, DOT, DOT_DOT_DOT, DOT_DOT_LESS
    case QUESTION, ATTACHED_QUESTION, QUESTION_QUESTION, AMPERSAND, AMPERSAND_AMPERSAND, PIPE, PIPE_PIPE
    case SELF, PLUS_EQUAL, MINUS_EQUAL
    
    case HASH, AT, BACKSLASH, TILDE, SLASH, DOLLAR
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
    "as":       TokenType.AS,
    "is":       TokenType.IS,
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
    let endOfLine: Bool
}

protocol ASTNode {}


struct ParserError: Error {
    let message: String
    
    init(_ message: String) {
        self.message = message
    }
}

struct Attribute: ASTNode {
    let name: Token
    var arguments: [ASTNode]
}

struct VarDeclaration: ASTNode {
    let name: Token
    let type: TypeIdentifier?
    var initializer: ASTNode?
    let isConstant: Bool
    let isPrivate: Bool
}

struct StructDeclaration: ASTNode {
    let name: Token
    let inheritedTypes: [Token]
    var members: [ASTNode]
}

struct ClassDeclaration: ASTNode {
    let name: Token
    let inheritedTypes: [Token]
    var methods: [FunctionDeclaration]
    var properties: [ASTNode]    
}

struct FunctionDeclaration: ASTNode {
    let name: Token
    let kind: Kind
    var attributes: [Attribute]
    let isStatic: Bool
    let isPrivate: Bool
    let canThrow: Bool
    var parameters: [Parameter]
    let returnType: TypeIdentifier?
    var body: BlockStatement

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
    var defaultValue: ASTNode?
}

indirect enum TypeIdentifier {
    case identifier(String)
    case array(TypeIdentifier)
    case dictionary(TypeIdentifier, TypeIdentifier)
    case optional(TypeIdentifier)
}

struct EnumDeclaration: ASTNode {
    let name: Token
    var cases: [EnumCase]
}

struct EnumCase {
    let name: Token
    var rawValue: ASTNode?
    var associatedValues: [Parameter]
}

struct ProtocolDeclaration: ASTNode {
    let name: Token
    let inheritedProtocols: [Token]
    var members: [ASTNode]
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
    var parameters: [Parameter]
    let returnType: TypeIdentifier?
}

struct TypealiasDeclaration: ASTNode {
    let name: Token
    let type: TypeIdentifier
}

struct TernaryExpression: ASTNode {
    var condition: ASTNode
    var thenBranch: ASTNode
    var elseBranch: ASTNode
}

struct IfStatement: ASTNode {
    var condition: ASTNode
    var thenBranch: ASTNode
    var elseBranch: ASTNode?
}

struct IfLetStatement: ASTNode {
    let name: Token
    var value: ASTNode?
    var thenBranch: ASTNode
    var elseBranch: ASTNode?
}

struct GuardStatement: ASTNode {
    var condition: ASTNode
    var body: ASTNode
}

struct GuardLetStatement: ASTNode {
    let name: Token
    var value: ASTNode?
    var body: ASTNode
}

struct SwitchStatement: ASTNode {
    var expression: ASTNode
    var cases: [SwitchCase]
    var defaultCase: [ASTNode]?
}

struct SwitchCase {
    var expressions: [ASTNode]
    var statements: [ASTNode]
}

struct ForStatement: ASTNode {
    let variable: Token
    var iterable: ASTNode
    var body: ASTNode
}

struct WhileStatement: ASTNode {
    var condition: ASTNode
    var body: ASTNode
}

struct RepeatStatement: ASTNode {
    var body: ASTNode
    var condition: ASTNode
}

struct ReturnStatement: ASTNode {
    var value: ASTNode?
}

struct BreakStatement: ASTNode {}

struct ContinueStatement: ASTNode {}

struct BlankStatement: ASTNode {}

struct DoCatchStatement: ASTNode {
    var body: ASTNode
    var catchBlock: ASTNode
}

struct ThrowStatement: ASTNode {
    var expression: ASTNode
}

struct TryExpression: ASTNode {
    var expression: ASTNode
    let isOptional: Bool
    let isForceUnwrap: Bool
}

struct AsExpression: ASTNode {
    var expression: ASTNode
    let type: TypeIdentifier
    let isOptional: Bool
    let isForceUnwrap: Bool
}

struct IsExpression: ASTNode {
    var expression: ASTNode
    let type: TypeIdentifier
}

struct BlockStatement: ASTNode {
    var statements: [ASTNode]
    var inBodyParameters: [Parameter] = []
}

struct ExpressionStatement: ASTNode {
    var expression: ASTNode
}

struct AssignmentExpression: ASTNode {
    var target: ASTNode
    var value: ASTNode
    let op: TokenType
}

struct BinaryExpression: ASTNode {
    var left: ASTNode
    var right: ASTNode
    let op: TokenType
}

struct LogicalExpression: ASTNode {
    var left: ASTNode
    var right: ASTNode
    let op: TokenType
}

struct BinaryRangeExpression: ASTNode {
    var left: ASTNode
    var right: ASTNode
    let op: TokenType
}

struct UnaryExpression: ASTNode {
    let op: TokenType
    var operand: ASTNode
}

struct Argument {
    let label: Token?
    var value: ASTNode
}

struct CallExpression: ASTNode {
    var callee: ASTNode
    var arguments: [Argument]
    var isOptional: Bool = false
    
    var isInitializer: Bool = false // if true, then this call is an initializer of a class or struct
}

struct GetExpression: ASTNode {
    var object: ASTNode
    let name: Token
    var isOptional: Bool = false
}

struct IndexExpression: ASTNode {
    var object: ASTNode
    var index: ASTNode
    var isOptional: Bool = false
}

struct OptionalChainingExpression: ASTNode {
    var object: ASTNode
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
    var expression: ASTNode
}

struct ArrayLiteralExpression: ASTNode {
    var elements: [ASTNode]
}

struct KeyValuePair {
    var key: ASTNode
    var value: ASTNode
}

struct DictionaryLiteralExpression: ASTNode {
    var elements: [KeyValuePair]
}

