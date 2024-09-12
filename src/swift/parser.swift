class Parser {
    private var tokens: [Token]
    private var current: Int = 0
    private var ast: [ASTNode] = []
    private var errors: [Error] = []

    init(tokens: [Token]) {
        self.tokens = tokens
    }

    func getErrors() -> [Error] {
        return errors
    }

    func parse() -> [ASTNode]? {
        self.ast = []
        while !isAtEnd() {
            if let node = declaration() {
                ast.append(node)
            }
        }

        return errors.count > 0 ? nil : ast
    }

    // MARK: - Declarations

    func declaration() -> ASTNode? {
        do {
            if match(TokenType.VAR, TokenType.LET) { return try varDeclaration() }
            if match(TokenType.STRUCT) { return try structDeclaration() }
            if match(TokenType.CLASS) { return try classDeclaration() }
            if match(TokenType.FUNC) { return try function(.function) }
            if match(TokenType.ENUM) { return try enumDeclaration() }
            if match(TokenType.PROTOCOL) { return try protocolDeclaration() }
            if match(TokenType.TYPEALIAS) { return try typealiasDeclaration() }
            return try statement()
        } catch {
            self.errors.append(error)
            synchronize()
            return nil
        }
    }

    func varDeclaration() throws -> VarDeclaration {
        let isConstant = previous().type == TokenType.LET
        let name = try consume(TokenType.IDENTIFIER, "Expect variable name.")

        let type: TypeIdentifier? = match(TokenType.COLON) ? try typeIdentifier() : nil
        let initializer: ASTNode? = match(TokenType.EQUAL) ? try expression() : nil

        match(TokenType.SEMICOLON)

        return VarDeclaration(
            name: name, 
            type: type, 
            initializer: initializer, 
            isConstant: isConstant
        )
    }

    func structDeclaration() throws -> StructDeclaration {
        let name = try consume(TokenType.IDENTIFIER, "Expect struct name.")
        
        var inheritedTypes: [Token] = []
        if match(TokenType.COLON) {
            repeat {
                inheritedTypes.append(try consume(TokenType.IDENTIFIER, "Expect inherited type name."))
            } while match(TokenType.COMMA)
        }
        try consume(TokenType.LEFT_BRACE, "Expect '{' before struct body.")
        
        var members: [ASTNode] = []
        while !check(TokenType.RIGHT_BRACE) && !isAtEnd() {
            if match(TokenType.INIT) {
               members.append(try function(.initializer))
            } 
            else if match(TokenType.VAR, TokenType.LET) {
               members.append(try varDeclaration())
            }
            else if match(TokenType.FUNC) {
               members.append(try function(.method))
            }
            else if match(TokenType.STRUCT) {
                members.append(try structDeclaration())
            }
            else if match(TokenType.CLASS) {
                members.append(try classDeclaration())
            }
            else if match(TokenType.ENUM) {
                members.append(try enumDeclaration())
            }
            else if match(TokenType.PROTOCOL) {
                members.append(try protocolDeclaration())
            }
            else if match(TokenType.TYPEALIAS) {
                members.append(try typealiasDeclaration())
            } 
            else {
                throw error(peek(), "Expect method or property declaration in struct.")
            }   
        }

        try consume(TokenType.RIGHT_BRACE, "Expect '}' after struct body.")

        return StructDeclaration(name: name, inheritedTypes: inheritedTypes, members: members)
    }

    func classDeclaration() throws -> ClassDeclaration {
        let name = try consume(TokenType.IDENTIFIER, "Expect class name.")
        
        var inheritedTypes: [Token] = []
        if match(TokenType.COLON) {
            repeat {
                inheritedTypes.append(try consume(TokenType.IDENTIFIER, "Expect inherited type name."))
            } while match(TokenType.COMMA)
        }

        try consume(TokenType.LEFT_BRACE, "Expect '{' before class body.")

        var methods: [FunctionDeclaration] = []
        var properties: [ASTNode] = []

        while !check(TokenType.RIGHT_BRACE) && !isAtEnd() {
            if match(TokenType.INIT) {
                methods.append(try function(.initializer))
            } 
            else if match(TokenType.FUNC) {
                methods.append(try function(.method))
            } 
            else if match(TokenType.VAR, TokenType.LET) {
                properties.append(try varDeclaration())
            } 
            else {
                throw error(peek(), "Expect method or property declaration in class.")
            }
        }

        try consume(TokenType.RIGHT_BRACE, "Expect '}' after class body.")

        return ClassDeclaration(name: name, inheritedTypes: inheritedTypes, methods: methods, properties: properties)
    }

    func function(_ kind: FunctionDeclaration.Kind) throws -> FunctionDeclaration {
        let isStatic = kind == .method && match(TokenType.STATIC)
        let name = kind == .initializer ? previous() : try consume(TokenType.IDENTIFIER, "Expect \(kind) name.")

        try consume(TokenType.LEFT_PAREN, "Expect '(' after \(kind) name.")
        let parameters = try parameterList()
        try consume(TokenType.RIGHT_PAREN, "Expect ')' after parameters.")

        let returnType: TypeIdentifier? = match(TokenType.RIGHT_ARROW) ? try typeIdentifier() : nil

        try consume(TokenType.LEFT_BRACE, "Expect '{' before \(kind) body.")
        let body = try block()

        return FunctionDeclaration(
            name: name, 
            kind: kind, 
            isStatic: isStatic, 
            parameters: parameters, 
            returnType: returnType, 
            body: body
        )
    }

    func parameterList(allowNamelessParams: Bool = false) throws -> [Parameter] {
        var parameters: [Parameter] = []
        if check(TokenType.RIGHT_PAREN) { return parameters }
    
        repeat {
            parameters.append(try parameter(allowNamelessParams: allowNamelessParams))
        } while match(TokenType.COMMA)

        return parameters
    }
    
    func parameter(allowNamelessParams: Bool = false) throws -> Parameter {
        var externalName: Token?
        var internalName: Token
        var isVariadic: Bool = false
        var defaultValue: ASTNode?

        if allowNamelessParams && check(TokenType.IDENTIFIER) && (checkNext(TokenType.RIGHT_PAREN) || checkNext(TokenType.COMMA) ) {
            // Handle nameless parameter (only type)
            let type = try typeIdentifier()
            return Parameter(externalName: nil, internalName: Token(type: .IDENTIFIER, value: "_", line: 0, column: 0), type: type, isVariadic: false, defaultValue: nil)
        }
        
        /*if match(TokenType.UNDERSCORE) {
            // Handle "_ internalName: type"
            internalName = try consume(TokenType.IDENTIFIER, "Expect parameter internal name after '_'.")
        } 
        else */if match(TokenType.IDENTIFIER) {
            if check(TokenType.IDENTIFIER) {
                // Handle "externalName internalName: type"
                externalName = previous()
                internalName = try consume(TokenType.IDENTIFIER, "Expect parameter internal name.")
            } 
            else {
                // Handle "internalAndExternalName: type"
                internalName = previous()
                externalName = internalName
            }
        } 
        else {
            throw error(peek(), "Expect parameter name.")
        }

        try consume(TokenType.COLON, "Expect ':' after parameter name.")
        let type = try typeIdentifier()

        if match(TokenType.DOT_DOT_DOT) {
            isVariadic = true
        }

        if match(TokenType.EQUAL) {
            defaultValue = try expression()
        }

        return Parameter(
            externalName: externalName, 
            internalName: internalName, 
            type: type, 
            isVariadic: isVariadic, 
            defaultValue: defaultValue
        )
    }

    func typeIdentifier() throws -> TypeIdentifier {
        var type: TypeIdentifier

        if match(TokenType.LEFT_BRACKET) {
            if checkNext(TokenType.COLON) {
                let keyType = try typeIdentifier()
                try consume(TokenType.COLON, "Expect ':' after dictionary key type.")
                let valueType = try typeIdentifier()
                try consume(TokenType.RIGHT_BRACKET, "Expect ']' after dictionary value type.")
                type = .dictionary(keyType, valueType)
            } else {
                let elementType = try typeIdentifier()
                try consume(TokenType.RIGHT_BRACKET, "Expect ']' after array element type.")
                type = .array(elementType)
            }
        } else {
            type = .identifier(try consume(TokenType.IDENTIFIER, "Expect type name."))
        }

        if match(TokenType.QUESTION) {
            type = .optional(type)
        }

        return type
    }

    func enumDeclaration() throws -> EnumDeclaration {
        let name = try consume(TokenType.IDENTIFIER, "Expect enum name.")
        try consume(TokenType.LEFT_BRACE, "Expect '{' before enum cases.")

        var cases: [EnumCase] = []
        while !check(TokenType.RIGHT_BRACE) && !isAtEnd() {
            try consume(TokenType.CASE, "Expect 'case' before enum case name.")
            
            repeat {
                let caseName = try consume(TokenType.IDENTIFIER, "Expect enum case name.")

                var rawValue: ASTNode? = nil
                var associatedValues: [Parameter] = []

                if match(TokenType.EQUAL) {
                    rawValue = try expression()
                } 
                else if match(TokenType.LEFT_PAREN) {
                    associatedValues = try parameterList(allowNamelessParams: true)
                    try consume(TokenType.RIGHT_PAREN, "Expect ')' after associated value(s).")
                }

                cases.append(EnumCase(name: caseName, rawValue: rawValue, associatedValues: associatedValues))
            } while match(TokenType.COMMA)
        }

        try consume(TokenType.RIGHT_BRACE, "Expect '}' after enum cases.")

        return EnumDeclaration(name: name, cases: cases)
    }

    func protocolDeclaration() throws -> ProtocolDeclaration {
        let name = try consume(TokenType.IDENTIFIER, "Expect protocol name.")
        
        var inheritedProtocols: [Token] = []
        if match(TokenType.COLON) {
            repeat {
                inheritedProtocols.append(try consume(TokenType.IDENTIFIER, "Expect inherited protocol name."))
            } while match(TokenType.COMMA)
        }

        try consume(TokenType.LEFT_BRACE, "Expect '{' before protocol body.")
        
        var members: [ASTNode] = []
        while !check(TokenType.RIGHT_BRACE) && !isAtEnd() {
            if match(TokenType.VAR, TokenType.LET) {
                members.append(try protocolPropertyDeclaration())
            } 
            else if match(TokenType.FUNC) {
                members.append(try protocolMethodDeclaration())
            } 
            else {
                throw error(peek(), "Expect property or method declaration in protocol.")
            }
        }

        try consume(TokenType.RIGHT_BRACE, "Expect '}' after protocol body.")

        return ProtocolDeclaration(
            name: name, 
            inheritedProtocols: inheritedProtocols, 
            members: members
        )
    }

    func protocolPropertyDeclaration() throws -> ASTNode {
        let isConstant = previous().type == TokenType.LET
        let name = try consume(TokenType.IDENTIFIER, "Expect variable name.")
        try consume(TokenType.COLON, "Expect ':' after property name.")
        let propertyType = try typeIdentifier()

        var getter = true
        var setter = false

        if match(TokenType.LEFT_BRACE) {
            getter = false
            setter = false
            if match(TokenType.GET) {
                getter = true
                if match(TokenType.SET) { setter = true }
            } 
            else if match(TokenType.SET) {
                setter = true
                if match(TokenType.GET) { getter = true }
            }
            try consume(TokenType.RIGHT_BRACE, "Expect '}' after getter/setter specification.")
        }

        return ProtocolPropertyDeclaration(
            name: name, 
            propertyType: propertyType, 
            isConstant: isConstant, 
            getter: getter, 
            setter: setter
        )
    }

    func protocolMethodDeclaration() throws -> ASTNode {
        let name = try consume(TokenType.IDENTIFIER, "Expect method name.")
        try consume(TokenType.LEFT_PAREN, "Expect '(' after method name.")
        let parameters = try parameterList()
        try consume(TokenType.RIGHT_PAREN, "Expect ')' after parameters.")
        
        let returnType: TypeIdentifier? = match(TokenType.RIGHT_ARROW) ? try typeIdentifier() : nil 

        return ProtocolMethodDeclaration(
            name: name, 
            parameters: parameters, 
            returnType: returnType
        )
    }

    func typealiasDeclaration() throws -> TypealiasDeclaration {
        let name = try consume(TokenType.IDENTIFIER, "Expect typealias name.")
        try consume(TokenType.EQUAL, "Expect '=' after typealias name.")
        let type = try typeIdentifier() 

        return TypealiasDeclaration(name: name, type: type)
    }

    // MARK: - Statements

    func statement() throws -> ASTNode {
        if match(TokenType.IF) { return try ifStatement() }
        if match(TokenType.GUARD) { return try guardStatement() }
        if match(TokenType.SWITCH) { return try switchStatement() }
        if match(TokenType.FOR) { return try forStatement() }
        if match(TokenType.WHILE) { return try whileStatement() }
        if match(TokenType.REPEAT) { return try repeatStatement() }
        if match(TokenType.RETURN) { return try returnStatement() }
        if match(TokenType.BREAK) { return try breakStatement() }
        if match(TokenType.CONTINUE) { return try continueStatement() }
        if match(TokenType.INDIRECT) { return try blankStatement() }
        if match(TokenType.LEFT_BRACE) { return try block() }
        return try expressionStatement()
    }

    func ifStatement() throws -> ASTNode {
        if match(TokenType.LET) {
            return try ifLetStatement()
        }

        let parens = match(TokenType.LEFT_PAREN)
        let condition = try expression()
        if parens { try consume(TokenType.RIGHT_PAREN, "Expect matching ')' after if condition.") }

        try consume(TokenType.LEFT_BRACE, "Expect '{' after if condition.")
        let thenBranch = try block()
        
        let elseBranch: ASTNode? = match(TokenType.ELSE) ? try statement() : nil

        return IfStatement(
            condition: condition, 
            thenBranch: thenBranch, 
            elseBranch: elseBranch
        )
    }

    func ifLetStatement() throws -> ASTNode {
        let name = try consume(TokenType.IDENTIFIER, "Expect variable name after 'if let'.")
        let value: ASTNode?
        if match(TokenType.EQUAL) {
            value = try expression()
        } 
        else {
            value = nil
        }

        try consume(TokenType.LEFT_BRACE, "Expect '{' after if let condition.")
        let thenBranch = try block()

        let elseBranch: ASTNode? = match(TokenType.ELSE) ? try statement() : nil

        return IfLetStatement(
            name: name, 
            value: value,
            thenBranch: thenBranch, 
            elseBranch: elseBranch
        )
    }

    func guardStatement() throws -> ASTNode {
        if match(TokenType.LET) {
            return try guardLetStatement()
        }

        let condition = try expression()
        try consume(TokenType.ELSE, "Expect 'else' after guard condition.")
        try consume(TokenType.LEFT_BRACE, "Expect '{' after guard condition.")
        let body = try block()
        return GuardStatement(condition: condition, body: body)
    }

    func guardLetStatement() throws -> ASTNode {
        let name = try consume(TokenType.IDENTIFIER, "Expect variable name after 'guard let'.")
        try consume(TokenType.EQUAL, "Expect '=' after variable name in guard let.")
        let value = try expression()
        try consume(TokenType.ELSE, "Expect 'else' after guard let condition.")
        try consume(TokenType.LEFT_BRACE, "Expect '{' after guard let condition.")
        let body = try block()
        return GuardLetStatement(name: name, value: value, body: body)
    }

    func switchStatement() throws -> ASTNode {
        let expression = try expression()
        try consume(TokenType.LEFT_BRACE, "Expect '{' after switch expression.")

        var cases: [SwitchCase] = []
        var defaultCase: [ASTNode]?

        while !check(TokenType.RIGHT_BRACE) && !isAtEnd() {
            if match(TokenType.CASE) {
                var caseExpressions: [ASTNode] = []
                repeat {
                    caseExpressions.append(try self.expression())
                } while match(TokenType.COMMA)

                try consume(TokenType.COLON, "Expect ':' after case value.")
                var statements: [ASTNode] = []
                while !check(TokenType.CASE) && !check(TokenType.DEFAULT) && !check(TokenType.RIGHT_BRACE) {
                    statements.append(try statement())
                }
                cases.append(SwitchCase(expressions: caseExpressions, statements: statements))
            } 
            else if match(TokenType.DEFAULT) {
                try consume(TokenType.COLON, "Expect ':' after 'default'.")
                var statements: [ASTNode] = []
                while !check(TokenType.RIGHT_BRACE) {
                    statements.append(try statement())
                }
                defaultCase = statements
            } 
            else {
                throw error(peek(), "Expect 'case' or 'default' in switch statement.")
            }
        }

        try consume(TokenType.RIGHT_BRACE, "Expect '}' after switch cases.")

        return SwitchStatement(
            expression: expression, 
            cases: cases, 
            defaultCase: defaultCase
        )
    }

    func forStatement() throws -> ASTNode {
        let paren = match(TokenType.LEFT_PAREN)
        let variable = try consume(TokenType.IDENTIFIER, "Expect variable name in for-in loop.")
        try consume(TokenType.IN, "Expect 'in' after variable name in for-in loop.")
        let iterable = try expression()
        if paren { try consume(TokenType.RIGHT_PAREN, "Expect matching ')' after for-in loop.") }
        try consume(TokenType.LEFT_BRACE, "Expect '{' before for loop body.")
        let body = try block()
        return ForStatement(
            variable: variable, 
            iterable: iterable, 
            body: body
        )
    }

    func whileStatement() throws -> ASTNode {
        let condition = try expression()
        try consume(TokenType.LEFT_BRACE, "Expect '{' before while loop body.")
        let body = try block()
        return WhileStatement(condition: condition, body: body)
    }

    func repeatStatement() throws -> ASTNode {
        try consume(TokenType.LEFT_BRACE, "Expect '{' before repeat loop body.")
        let body = try block()
        try consume(TokenType.WHILE, "Expect 'while' after repeat loop body.")
        let paren = match(TokenType.LEFT_PAREN)
        let condition = try expression()
        if paren { try consume(TokenType.RIGHT_PAREN, "Expect matching ')' after repeat while condition.") }
        return RepeatStatement(body: body, condition: condition)
    }

    func returnStatement() throws -> ASTNode {
        var value: ASTNode?
        if !check(TokenType.RIGHT_BRACE) && !check(TokenType.SEMICOLON) && !isAtEnd() {
            value = try expression()
        }
        match(TokenType.SEMICOLON)
        return ReturnStatement(value: value)
    }

    func breakStatement() throws -> ASTNode {
        return BreakStatement()
    }

    func continueStatement() throws -> ASTNode {
        return ContinueStatement()
    }

    func blankStatement() throws -> ASTNode {
        return BlankStatement()
    }

    func block() throws -> BlockStatement {
        var statements: [ASTNode] = []
        while !check(TokenType.RIGHT_BRACE) && !isAtEnd() {
            if let statement = declaration() {
                statements.append(statement)
            }
        }
        try consume(TokenType.RIGHT_BRACE, "Expect '}' after block.")
        return BlockStatement(statements: statements)
    }

    func expressionStatement() throws -> ASTNode {
        let expression = try expression()
        match(TokenType.SEMICOLON)
        return ExpressionStatement(expression: expression)
    }

    // MARK: - Expressions

    func expression() throws -> ASTNode {
        return try assignment()
    }

    func assignment() throws -> ASTNode {
        let expr = try coalescing()

        if match(TokenType.EQUAL, TokenType.PLUS_EQUAL, TokenType.MINUS_EQUAL) {
            let equals = previous()
            let value = try assignment()
            
            if expr is VariableExpression || expr is IndexExpression || expr is GetExpression || expr is OptionalChainingExpression {
                return AssignmentExpression(target: expr, value: value, op: equals.type)
            }

            throw error(equals, "Invalid assignment target.")
        }

        return expr
    }

    func coalescing() throws -> ASTNode {
        var expr = try or()

        while match(TokenType.QUESTION_QUESTION) {
            let op = previous()
            let right = try or()
            expr = BinaryExpression(left: expr, right: right, op: op.type)
        }

        return expr
    }

    func or() throws -> ASTNode {
        var expr = try and()

        while match(TokenType.PIPE_PIPE) {
            let op = previous()
            let right = try and()
            expr = LogicalExpression(left: expr, right: right, op: op.type)
        }

        return expr
    }

    func and() throws -> ASTNode {
        var expr = try equality()

        while match(TokenType.AMPERSAND_AMPERSAND) {
            let op = previous()
            let right = try equality()
            expr = LogicalExpression(left: expr, right: right, op: op.type)
        }

        return expr
    }

    func equality() throws -> ASTNode {
        var expr = try comparison()

        while match(TokenType.BANG_EQUAL, TokenType.EQUAL_EQUAL) {
            let op = previous()
            let right = try comparison()
            expr = BinaryExpression(left: expr, right: right, op: op.type)
        }

        return expr
    }

    func comparison() throws -> ASTNode {
        var expr = try range()

        while match(TokenType.GREATER, TokenType.GREATER_EQUAL, TokenType.LESS, TokenType.LESS_EQUAL) {
            let op = previous()
            let right = try range()
            expr = BinaryExpression(left: expr, right: right, op: op.type)
        }

        return expr
    }

    func range() throws -> ASTNode {
        var expr = try term()

        while match(TokenType.DOT_DOT_DOT, TokenType.DOT_DOT_LESS) {
            let op = previous()
            let right = try term()
            expr = BinaryRangeExpression(left: expr, right: right, op: op.type)
        }

        return expr
    }

    func term() throws -> ASTNode {
        var expr = try factor()

        while match(TokenType.MINUS, TokenType.PLUS) {  
            let op = previous()
            let right = try factor()
            expr = BinaryExpression(left: expr, right: right, op: op.type)
        }

        return expr
    }

    func factor() throws -> ASTNode {
        var expr = try unary()

        while match(TokenType.SLASH, TokenType.STAR) {
            let op = previous()
            let right = try unary()
            expr = BinaryExpression(left: expr, right: right, op: op.type)
        }

        return expr
    }

    func unary() throws -> ASTNode {
        if match(TokenType.BANG, TokenType.MINUS) {
            let op = previous()
            let right = try unary()
            return UnaryExpression(op: op.type, operand: right)
        }

        return try call()
    }

    func call() throws -> ASTNode {
        var expr = try primary()

        while true {
            if match(TokenType.LEFT_PAREN) {
                expr = try finishCall(expr)
            } 
            else if match(TokenType.DOT) {
                let name = try consume(TokenType.IDENTIFIER, "Expect property name after '.'.")
                expr = GetExpression(object: expr, name: name)
            } 
            else if match(TokenType.LEFT_BRACKET) {
                let index = try expression()
                try consume(TokenType.RIGHT_BRACKET, "Expect ']' after index.")
                expr = IndexExpression(object: expr, index: index)
            } 
            else if match(TokenType.QUESTION) || match(TokenType.BANG) {
                let forceUnwrap = previous().type == TokenType.BANG
                expr = OptionalChainingExpression(object: expr, forceUnwrap: forceUnwrap)

                if match(TokenType.LEFT_PAREN) {
                    expr = try finishCall(expr, isOptional: true)
                } 
                else if match(TokenType.IDENTIFIER) {
                    let name = previous()
                    expr = GetExpression(object: expr, name: name, isOptional: true)
                } 
                else if match(TokenType.LEFT_BRACKET) {
                    let index = try expression()
                    try consume(TokenType.RIGHT_BRACKET, "Expect ']' after index.")
                    expr = IndexExpression(object: expr, index: index, isOptional: true)
                } 
                else if !forceUnwrap {
                    throw error(peek(), "Expect property, subscript, or method call after '?'.")
                }
            }
            else {
                break
            }
        }

        return expr
    }

    func finishCall(_ callee: ASTNode, isOptional: Bool = false) throws -> ASTNode {
        var arguments: [Argument] = []
        if !check(TokenType.RIGHT_PAREN) {
            repeat {
                var label: Token? = nil
                if check(TokenType.IDENTIFIER) && checkNext(TokenType.COLON) {
                    label = try consume(TokenType.IDENTIFIER, "Expect argument label.")
                    try consume(TokenType.COLON, "Expect ':' after argument label.")
                }
                let value = try expression()
                arguments.append(Argument(label: label, value: value))
            } while match(TokenType.COMMA)
        }
        try consume(TokenType.RIGHT_PAREN, "Expect ')' after arguments.")

        return CallExpression(callee: callee, arguments: arguments, isOptional: isOptional)
    }

    func primary() throws -> ASTNode {
        if match(TokenType.FALSE) { return LiteralExpression(value: false) }
        if match(TokenType.TRUE) { return LiteralExpression(value: true) }
        if match(TokenType.NIL) { return LiteralExpression(value: nil) }
        if match(TokenType.SELF) { return SelfExpression() }
        
        if match(TokenType.STRING) { 
            return StringLiteralExpression(value: previous().value) 
        }

        if match(TokenType.STRING_MULTILINE) { 
            return StringLiteralExpression(value: previous().value, isMultiLine: true) 
        }

        if match(TokenType.INT) { 
            if let value = Int(previous().value) {
                return IntLiteralExpression(value: value)
            }
            else {
                throw error(previous(), "Invalid number literal.")
            }
        }
        
        if match(TokenType.DOUBLE) { 
            if let value = Double(previous().value) {
                return DoubleLiteralExpression(value: value)
            }
            else {
                throw error(previous(), "Invalid number literal.")
            }
        }

        if match(TokenType.IDENTIFIER) { 
            return VariableExpression(name: previous()) 
        }

        if match(TokenType.LEFT_PAREN) {
            let expr = try expression()
            try consume(TokenType.RIGHT_PAREN, "Expect ')' after expression.")
            return GroupingExpression(expression: expr)
        }

        if match(TokenType.LEFT_BRACKET) {
            return try arrayOrDictionaryLiteral()
        }

        throw error(peek(), "Expect expression.")
    }

    func arrayOrDictionaryLiteral() throws -> ASTNode {
        if match(TokenType.COLON) {
            try consume(TokenType.RIGHT_BRACKET, "Expect ']' after empty dictionary literal.")
            return DictionaryLiteralExpression(elements: [])
        }

        if match(TokenType.RIGHT_BRACKET) {
            return ArrayLiteralExpression(elements: [])
        }

        let firstElement = try expression()

        if match(TokenType.COLON) {
            return try finishDictionaryLiteral(firstElement)
        } else {
            return try finishArrayLiteral(firstElement)
        }
    }

    func finishArrayLiteral(_ firstElement: ASTNode) throws -> ASTNode {
        var elements = [firstElement]
        while match(TokenType.COMMA) {
            if check(TokenType.RIGHT_BRACKET) { break }
            elements.append(try expression())
        }
        try consume(TokenType.RIGHT_BRACKET, "Expect ']' after array elements.")
        return ArrayLiteralExpression(elements: elements)
    }

    func finishDictionaryLiteral(_ firstKey: ASTNode) throws -> ASTNode {
        var elements: [KeyValuePair] = []
        let firstValue = try expression()
        elements.append(KeyValuePair(key: firstKey, value: firstValue))

        while match(TokenType.COMMA) {
            if check(TokenType.RIGHT_BRACKET) { break }
            let key = try expression()
            try consume(TokenType.COLON, "Expect ':' after dictionary key.")
            let value = try expression()
            elements.append(KeyValuePair(key: key, value: value))
        }
        try consume(TokenType.RIGHT_BRACKET, "Expect ']' after dictionary pairs.")
        return DictionaryLiteralExpression(elements: elements)
    }

    // MARK: - Helpers

    @discardableResult
    func match(_ types: TokenType...) -> Bool {
        for type in types {
            if check(type) {
                advance()
                return true
            }
        }
        return false
    }

    @discardableResult
    func consume(_ type: TokenType, _ message: String) throws -> Token {
        if check(type) { return advance() }
        throw error(peek(), message)
    }

    func check(_ type: TokenType) -> Bool {
        if isAtEnd() { return false }
        return peek().type == type
    }

    func checkNext(_ type: TokenType) -> Bool {
        if isAtEnd() { return false }
        if current + 1 >= tokens.count { return false }
        return tokens[current + 1].type == type
    }

    @discardableResult
    func advance() -> Token {
        if !isAtEnd() { current += 1 }
        return previous()
    }
    
    func isAtEnd() -> Bool {
        return peek().type == TokenType.EOF
    }

    func peek() -> Token {
        return tokens[current]
    }

    func previous() -> Token {
        return tokens[current - 1]
    }
    
    func next() -> Token {
        return tokens[current + 1]
    }
    
    func error(_ token: Token, _ message: String) -> Error {
        print("Error at '\(token.value)', line \(token.line), column \(token.column): \(message)")
        return ParserError(message)
    }

    func synchronize() {
        advance()
        while !isAtEnd() {
            if previous().type == TokenType.SEMICOLON { return }

            switch peek().type {
                case TokenType.FUNC,
                     TokenType.VAR,
                     TokenType.LET,
                     TokenType.FOR,
                     TokenType.IF,
                     TokenType.WHILE,
                     TokenType.RETURN,
                     TokenType.STRUCT,
                     TokenType.ENUM,
                     TokenType.PROTOCOL,
                     TokenType.TYPEALIAS,
                     TokenType.EXTENSION,
                     TokenType.GUARD,
                     TokenType.SWITCH:
                    return
                default:
                    break
            }
            advance()
        }
    }
}

// TODO: Add throws to the function declaration; add throw somewhere
// TODO: Add do-catch
// TODO: Add try? and try!
// TODO: Add force unwrapping to the parser
// TODO: Add as to the parser
// TODO: Add @discardableResult
// TODO: Differentiate method names based on parameters so you can overload
