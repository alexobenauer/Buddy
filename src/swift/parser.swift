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
        while !self.isAtEnd() {
            if let node = self.declaration(inScopeOf: nil) {
                self.ast.append(node)
            }
        }

        return self.errors.count > 0 ? nil : self.ast
    }

    // MARK: - Declarations

    func declaration(inScopeOf: String?) -> ASTNode? {
        do {
            var attributes: [Attribute] = []
            while self.match(TokenType.AT) {
                attributes.append(try self.attribute())
            }

            let isPrivate = self.match(TokenType.PRIVATE)
            
            if self.match(TokenType.INIT) && inScopeOf != nil {
                return try self.function(FunctionDeclaration.Kind.initializer, isPrivate: isPrivate, attributes: attributes)
            }
            if self.match(TokenType.VAR, TokenType.LET) {
                return try self.varDeclaration(isPrivate: isPrivate)
            }
            if self.match(TokenType.FUNC) { 
                return try self.function(
                    inScopeOf == nil ? FunctionDeclaration.Kind.function : FunctionDeclaration.Kind.method,
                    isPrivate: isPrivate,
                    attributes: attributes
                )
            }
            if self.match(TokenType.STRUCT) { return try self.structDeclaration() }
            if self.match(TokenType.CLASS) { return try self.classDeclaration() }
            if self.match(TokenType.ENUM) { return try self.enumDeclaration() }
            if self.match(TokenType.PROTOCOL) { return try self.protocolDeclaration() }
            if self.match(TokenType.TYPEALIAS) { return try self.typealiasDeclaration() }

            if let inScopeOf {
                throw self.error(self.peek(), "Expect method or property declaration in \(inScopeOf).")
            }
            else {
                return try self.statement()
            }
        } catch {
            print(error)
            self.errors.append(error)
            self.synchronize()
            return nil
        }
    }

    func attribute() throws -> Attribute {
        let name = try self.consume(TokenType.IDENTIFIER, "Expect attribute name.")
        // TODO: Support for args?
        return Attribute(name: name, arguments: [])
    }

    func varDeclaration(isPrivate: Bool) throws -> VarDeclaration {
        let isConstant = self.previous().type == TokenType.LET
        let name = try self.consume(TokenType.IDENTIFIER, "Expect variable name.")

        let type: TypeIdentifier? = self.match(TokenType.COLON) ? try self.typeIdentifier() : nil
        let initializer: ASTNode? = self.match(TokenType.EQUAL) ? try self.expression() : nil

        self.match(TokenType.SEMICOLON)

        return VarDeclaration(
            name: name, 
            type: type, 
            initializer: initializer, 
            isConstant: isConstant,
            isPrivate: isPrivate
        )
    }

    func structDeclaration() throws -> StructDeclaration {
        let name = try self.consume(TokenType.IDENTIFIER, "Expect struct name.")
        
        var inheritedTypes: [Token] = []
        if match(TokenType.COLON) {
            repeat {
                inheritedTypes.append(try self.consume(TokenType.IDENTIFIER, "Expect inherited type name."))
            } while self.match(TokenType.COMMA)
        }
        try self.consume(TokenType.LEFT_BRACE, "Expect '{' before struct body.")
        
        var members: [ASTNode] = []
        while !self.check(TokenType.RIGHT_BRACE) && !self.isAtEnd() {
            if let node = self.declaration(inScopeOf: "struct") {
                members.append(node)
            }
        }

        try self.consume(TokenType.RIGHT_BRACE, "Expect '}' after struct body.")

        return StructDeclaration(name: name, inheritedTypes: inheritedTypes, members: members)
    }

    func classDeclaration() throws -> ClassDeclaration {
        let name = try self.consume(TokenType.IDENTIFIER, "Expect class name.")
        
        var inheritedTypes: [Token] = []
        if match(TokenType.COLON) {
            repeat {
                inheritedTypes.append(try self.consume(TokenType.IDENTIFIER, "Expect inherited type name."))
            } while self.match(TokenType.COMMA)
        }

        try self.consume(TokenType.LEFT_BRACE, "Expect '{' before class body.")

        var methods: [FunctionDeclaration] = []
        var properties: [ASTNode] = []

        while !self.check(TokenType.RIGHT_BRACE) && !self.isAtEnd() {
            var attributes: [Attribute] = []
            while self.match(TokenType.AT) {
                attributes.append(try self.attribute())
            }
            
            let isPrivate = self.match(TokenType.PRIVATE)
            
            if self.match(TokenType.INIT) {
                methods.append(try self.function(FunctionDeclaration.Kind.initializer, isPrivate: isPrivate, attributes: attributes))
            }
            else if self.match(TokenType.FUNC) {
                methods.append(try self.function(FunctionDeclaration.Kind.method, isPrivate: isPrivate, attributes: attributes))
            }
            else if self.match(TokenType.VAR, TokenType.LET) {
                properties.append(try self.varDeclaration(isPrivate: isPrivate))
            }
            else {
                throw self.error(self.peek(), "Expect method or property declaration in class.")
            }
        }

        try self.consume(TokenType.RIGHT_BRACE, "Expect '}' after class body.")

        return ClassDeclaration(name: name, inheritedTypes: inheritedTypes, methods: methods, properties: properties)
    }

    func function(_ kind: FunctionDeclaration.Kind, isPrivate: Bool, attributes: [Attribute]) throws -> FunctionDeclaration {
        let isStatic = kind == FunctionDeclaration.Kind.method && self.match(TokenType.STATIC)
        let name = kind == FunctionDeclaration.Kind.initializer ? self.previous() : try self.consume(TokenType.IDENTIFIER, "Expect \(kind) name.")

        try self.consume(TokenType.LEFT_PAREN, "Expect '(' after \(kind) name.")
        let parameters = try self.parameterList()
        try self.consume(TokenType.RIGHT_PAREN, "Expect ')' after parameters.")

        let canThrow: Bool = self.match(TokenType.THROWS)

        let returnType: TypeIdentifier? = self.match(TokenType.RIGHT_ARROW) ? try self.typeIdentifier() : nil

        try self.consume(TokenType.LEFT_BRACE, "Expect '{' before \(kind) body.")
        let body = try self.block()

        return FunctionDeclaration(
            name: name, 
            kind: kind, 
            attributes: attributes, 
            isStatic: isStatic, 
            isPrivate: isPrivate,
            canThrow: canThrow,
            parameters: parameters, 
            returnType: returnType, 
            body: body
        )
    }

    func parameterList(allowNamelessParams: Bool = false) throws -> [Parameter] {
        var parameters: [Parameter] = []
        if self.check(TokenType.RIGHT_PAREN) { return parameters }
    
        repeat {
            parameters.append(try self.parameter(allowNamelessParams: allowNamelessParams))
        } while self.match(TokenType.COMMA)

        return parameters
    }
    
    func parameter(allowNamelessParams: Bool = false) throws -> Parameter {
        var externalName: Token?
        var internalName: Token
        var isVariadic: Bool = false
        var defaultValue: ASTNode?

        if allowNamelessParams && self.check(TokenType.IDENTIFIER) && (self.checkNext(TokenType.RIGHT_PAREN) || self.checkNext(TokenType.COMMA) ) {
            // Handle nameless parameter (only type)
            let type = try self.typeIdentifier()
            return Parameter(externalName: nil, internalName: Token(type: TokenType.IDENTIFIER, value: "_", line: 0, column: 0, endOfLine: false), type: type, isVariadic: false, defaultValue: nil)
        }
        
        /*if match(TokenType.UNDERSCORE) {
            // Handle "_ internalName: type"
            internalName = try consume(TokenType.IDENTIFIER, "Expect parameter internal name after '_'.")
        } 
        else */if self.match(TokenType.IDENTIFIER) {
            if self.check(TokenType.IDENTIFIER) {
                // Handle "externalName internalName: type"
                externalName = self.previous()
                internalName = try self.consume(TokenType.IDENTIFIER, "Expect parameter internal name.")
            } 
            else {
                // Handle "internalAndExternalName: type"
                internalName = self.previous()
                externalName = internalName
            }
        } 
        else {
            throw self.error(self.peek(), "Expect parameter name.")
        }

        try self.consume(TokenType.COLON, "Expect ':' after parameter name.")
        let type = try self.typeIdentifier()

        if self.match(TokenType.DOT_DOT_DOT) {
            isVariadic = true
        }

        if self.match(TokenType.EQUAL) {
            defaultValue = try self.expression()
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

        if self.match(TokenType.LEFT_BRACKET) {
            if self.checkNext(TokenType.COLON) {
                let keyType = try self.typeIdentifier()
                try self.consume(TokenType.COLON, "Expect ':' after dictionary key type.")
                let valueType = try self.typeIdentifier()
                try self.consume(TokenType.RIGHT_BRACKET, "Expect ']' after dictionary value type.")
                type = TypeIdentifier.dictionary(keyType, valueType)
            } else {
                let elementType = try self.typeIdentifier()
                try self.consume(TokenType.RIGHT_BRACKET, "Expect ']' after array element type.")
                type = TypeIdentifier.array(elementType)
            }
        } else {
            var identifier: String = ""
        
            repeat {
                identifier = [identifier, try self.consume(TokenType.IDENTIFIER, "Expect type name.").value].joined(separator: ".")
            } while self.match(TokenType.DOT)

            type = TypeIdentifier.identifier(identifier)
        }

        if self.match(TokenType.ATTACHED_QUESTION) {
            type = TypeIdentifier.optional(type)
        }

        return type
    }

    func enumDeclaration() throws -> EnumDeclaration {
        let name = try self.consume(TokenType.IDENTIFIER, "Expect enum name.")
        try self.consume(TokenType.LEFT_BRACE, "Expect '{' before enum cases.")

        var cases: [EnumCase] = []
        while !self.check(TokenType.RIGHT_BRACE) && !self.isAtEnd() {
            try self.consume(TokenType.CASE, "Expect 'case' before enum case name.")
            
            repeat {
                let caseName = try self.consume(TokenType.IDENTIFIER, "Expect enum case name.")

                var rawValue: ASTNode? = nil
                var associatedValues: [Parameter] = []

                if self.match(TokenType.EQUAL) {
                    rawValue = try self.expression()
                } 
                else if self.match(TokenType.LEFT_PAREN) {
                    associatedValues = try self.parameterList(allowNamelessParams: true)
                    try self.consume(TokenType.RIGHT_PAREN, "Expect ')' after associated value(s).")
                }

                cases.append(EnumCase(name: caseName, rawValue: rawValue, associatedValues: associatedValues))
            } while self.match(TokenType.COMMA)
        }

        try self.consume(TokenType.RIGHT_BRACE, "Expect '}' after enum cases.")

        return EnumDeclaration(name: name, cases: cases)
    }

    func protocolDeclaration() throws -> ProtocolDeclaration {
        let name = try self.consume(TokenType.IDENTIFIER, "Expect protocol name.")
        
        var inheritedProtocols: [Token] = []
        if self.match(TokenType.COLON) {
            repeat {
                inheritedProtocols.append(try self.consume(TokenType.IDENTIFIER, "Expect inherited protocol name."))
            } while self.match(TokenType.COMMA)
        }

        try self.consume(TokenType.LEFT_BRACE, "Expect '{' before protocol body.")
        
        var members: [ASTNode] = []
        while !self.check(TokenType.RIGHT_BRACE) && !self.isAtEnd() {
            if self.match(TokenType.VAR, TokenType.LET) {
                members.append(try self.protocolPropertyDeclaration())
            } 
            else if self.match(TokenType.FUNC) {
                members.append(try self.protocolMethodDeclaration())
            } 
            else {
                throw self.error(self.peek(), "Expect property or method declaration in protocol.")
            }
        }

        try self.consume(TokenType.RIGHT_BRACE, "Expect '}' after protocol body.")

        return ProtocolDeclaration(
            name: name, 
            inheritedProtocols: inheritedProtocols, 
            members: members
        )
    }

    func protocolPropertyDeclaration() throws -> ASTNode {
        let isConstant = self.previous().type == TokenType.LET
        let name = try self.consume(TokenType.IDENTIFIER, "Expect variable name.")
        try self.consume(TokenType.COLON, "Expect ':' after property name.")
        let propertyType = try self.typeIdentifier()

        var getter = true
        var setter = false

        if self.match(TokenType.LEFT_BRACE) {
            getter = false
            setter = false
            if self.match(TokenType.GET) {
                getter = true
                if self.match(TokenType.SET) { setter = true }
            } 
            else if self.match(TokenType.SET) {
                setter = true
                if self.match(TokenType.GET) { getter = true }
            }
            try self.consume(TokenType.RIGHT_BRACE, "Expect '}' after getter/setter specification.")
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
        let name = try self.consume(TokenType.IDENTIFIER, "Expect method name.")
        try self.consume(TokenType.LEFT_PAREN, "Expect '(' after method name.")
        let parameters = try self.parameterList()
        try self.consume(TokenType.RIGHT_PAREN, "Expect ')' after parameters.")
        
        let returnType: TypeIdentifier? = self.match(TokenType.RIGHT_ARROW) ? try self.typeIdentifier() : nil 

        return ProtocolMethodDeclaration(
            name: name, 
            parameters: parameters, 
            returnType: returnType
        )
    }

    func typealiasDeclaration() throws -> TypealiasDeclaration {
        let name = try self.consume(TokenType.IDENTIFIER, "Expect typealias name.")
        try self.consume(TokenType.EQUAL, "Expect '=' after typealias name.")
        let type = try self.typeIdentifier() 

        return TypealiasDeclaration(name: name, type: type)
    }

    // MARK: - Statements

    func statement() throws -> ASTNode {
        if self.match(TokenType.IF) { return try self.ifStatement() }
        if self.match(TokenType.GUARD) { return try self.guardStatement() }
        if self.match(TokenType.SWITCH) { return try self.switchStatement() }
        if self.match(TokenType.FOR) { return try self.forStatement() }
        if self.match(TokenType.WHILE) { return try self.whileStatement() }
        if self.match(TokenType.REPEAT) { return try self.repeatStatement() }
        if self.match(TokenType.RETURN) { return try self.returnStatement() }
        if self.match(TokenType.BREAK) { return try self.breakStatement() }
        if self.match(TokenType.CONTINUE) { return try self.continueStatement() }
        if self.match(TokenType.DO) { return try self.doCatchStatement() }
        if self.match(TokenType.THROW) { return try self.throwStatement() }
        if self.match(TokenType.INDIRECT) { return try self.blankStatement() }
        if self.match(TokenType.LEFT_BRACE) { return try self.block() }
        return try self.expressionStatement()
    }

    func ifStatement() throws -> ASTNode {
        if self.match(TokenType.LET) {
            return try self.ifLetStatement()
        }

        let parens = self.match(TokenType.LEFT_PAREN)
        let condition = try self.expression()
        if parens { try self.consume(TokenType.RIGHT_PAREN, "Expect matching ')' after if condition.") }

        try self.consume(TokenType.LEFT_BRACE, "Expect '{' after if condition.")
        let thenBranch = try self.block()
        
        let elseBranch: ASTNode? = self.match(TokenType.ELSE) ? try self.statement() : nil

        return IfStatement(
            condition: condition, 
            thenBranch: thenBranch, 
            elseBranch: elseBranch
        )
    }

    func ifLetStatement() throws -> ASTNode {
        let name = try self.consume(TokenType.IDENTIFIER, "Expect variable name after 'if let'.")
        let value: ASTNode?
        if self.match(TokenType.EQUAL) {
            value = try self.expression()
        } 
        else {
            value = nil
        }

        try self.consume(TokenType.LEFT_BRACE, "Expect '{' after if let condition.")
        let thenBranch = try self.block()

        let elseBranch: ASTNode? = self.match(TokenType.ELSE) ? try self.statement() : nil

        return IfLetStatement(
            name: name, 
            value: value,
            thenBranch: thenBranch, 
            elseBranch: elseBranch
        )
    }

    func guardStatement() throws -> ASTNode {
        if self.match(TokenType.LET) {
            return try self.guardLetStatement()
        }

        let condition = try self.expression()
        try self.consume(TokenType.ELSE, "Expect 'else' after guard condition.")
        try self.consume(TokenType.LEFT_BRACE, "Expect '{' after guard condition.")
        let body = try self.block()
        return GuardStatement(condition: condition, body: body)
    }

    func guardLetStatement() throws -> ASTNode {
        let name = try self.consume(TokenType.IDENTIFIER, "Expect variable name after 'guard let'.")
        try self.consume(TokenType.EQUAL, "Expect '=' after variable name in guard let.")
        let value = try self.expression()
        try self.consume(TokenType.ELSE, "Expect 'else' after guard let condition.")
        try self.consume(TokenType.LEFT_BRACE, "Expect '{' after guard let condition.")
        let body = try self.block()
        return GuardLetStatement(name: name, value: value, body: body)
    }

    func switchStatement() throws -> ASTNode {
        let expression = try self.expression()
        try self.consume(TokenType.LEFT_BRACE, "Expect '{' after switch expression.")

        var cases: [SwitchCase] = []
        var defaultCase: [ASTNode]?

        while !self.check(TokenType.RIGHT_BRACE) && !self.isAtEnd() {
            if self.match(TokenType.CASE) {
                var caseExpressions: [ASTNode] = []
                repeat {
                    caseExpressions.append(try self.expression())
                } while match(TokenType.COMMA)

                try self.consume(TokenType.COLON, "Expect ':' after case value.")
                var statements: [ASTNode] = []
                while !self.check(TokenType.CASE) && !self.check(TokenType.DEFAULT) && !self.check(TokenType.RIGHT_BRACE) {
                    statements.append(try self.statement())
                }
                cases.append(SwitchCase(expressions: caseExpressions, statements: statements))
            } 
            else if self.match(TokenType.DEFAULT) {
                try self.consume(TokenType.COLON, "Expect ':' after 'default'.")
                var statements: [ASTNode] = []
                while !self.check(TokenType.RIGHT_BRACE) {
                    statements.append(try self.statement())
                }
                defaultCase = statements
            } 
            else {
                throw self.error(self.peek(), "Expect 'case' or 'default' in switch statement.")
            }
        }

        try self.consume(TokenType.RIGHT_BRACE, "Expect '}' after switch cases.")

        return SwitchStatement(
            expression: expression, 
            cases: cases, 
            defaultCase: defaultCase
        )
    }

    func forStatement() throws -> ASTNode {
        let paren = self.match(TokenType.LEFT_PAREN)
        let variable = try self.consume(TokenType.IDENTIFIER, "Expect variable name in for-in loop.")
        try self.consume(TokenType.IN, "Expect 'in' after variable name in for-in loop.")
        let iterable = try self.expression()
        if paren { try self.consume(TokenType.RIGHT_PAREN, "Expect matching ')' after for-in loop.") }
        try self.consume(TokenType.LEFT_BRACE, "Expect '{' before for loop body.")
        let body = try self.block()
        return ForStatement(
            variable: variable, 
            iterable: iterable, 
            body: body
        )
    }

    func whileStatement() throws -> ASTNode {
        let condition = try self.expression()
        try self.consume(TokenType.LEFT_BRACE, "Expect '{' before while loop body.")
        let body = try self.block()
        return WhileStatement(condition: condition, body: body)
    }

    func repeatStatement() throws -> ASTNode {
        try self.consume(TokenType.LEFT_BRACE, "Expect '{' before repeat loop body.")
        let body = try self.block()
        try self.consume(TokenType.WHILE, "Expect 'while' after repeat loop body.")
        let paren = self.match(TokenType.LEFT_PAREN)
        let condition = try self.expression()
        if paren { try self.consume(TokenType.RIGHT_PAREN, "Expect matching ')' after repeat while condition.") }
        return RepeatStatement(body: body, condition: condition)
    }

    func returnStatement() throws -> ASTNode {
        let token = previous()
        var value: ASTNode?
        if !token.endOfLine && !self.check(TokenType.RIGHT_BRACE) && !self.check(TokenType.SEMICOLON) && !self.isAtEnd() {
            value = try self.expression()
        }
        self.match(TokenType.SEMICOLON)
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

    func doCatchStatement() throws -> ASTNode {
        try self.consume(TokenType.LEFT_BRACE, "Expect '{' before do statement.")
        let body = try self.block()
        try self.consume(TokenType.CATCH, "Expect 'catch' after do statement.")
        try self.consume(TokenType.LEFT_BRACE, "Expect '{' before catch block.")
        let catchBlock = try self.block()
        return DoCatchStatement(body: body, catchBlock: catchBlock)
    }

    func throwStatement() throws -> ASTNode {
        let expression = try self.expression()
        return ThrowStatement(expression: expression)
    }
        
    func block() throws -> BlockStatement {
        var statements: [ASTNode] = []
        var inBodyParameters: [Parameter] = []

        if !previous().endOfLine {
            for x in current..<tokens.count {
                if tokens[x].type == TokenType.IN {
                    inBodyParameters = try self.parseInBodyArguments()
                    break
                }
                
                if tokens[x].endOfLine { break }
            }
        }

        for x in current..<tokens.count {
            if tokens[x].type == TokenType.RIGHT_BRACE { break }

            if tokens[x].type == TokenType.DOLLAR && x+1 < tokens.count && tokens[x+1].type == TokenType.INT {
                let id = "$" + tokens[x + 1].value
                inBodyParameters.append(Parameter(externalName: nil, internalName: Token(type: TokenType.IDENTIFIER, value: id, line: 0, column: 0, endOfLine: false), type: TypeIdentifier.identifier(id), isVariadic: false, defaultValue: nil))
            }
        }
        
        while !self.check(TokenType.RIGHT_BRACE) && !self.isAtEnd() {
            if let statement = self.declaration(inScopeOf: nil) {
                statements.append(statement)
            }
        }
        try self.consume(TokenType.RIGHT_BRACE, "Expect '}' after block.")

        return BlockStatement(statements: statements, inBodyParameters: inBodyParameters)
    }
    
    func parseInBodyArguments() throws -> [Parameter] {
        var arguments: [Parameter] = []
        
        repeat {
            let name = try self.consume(TokenType.IDENTIFIER, "Expect argument name.")
            arguments.append(Parameter(externalName: nil, internalName: name, type: TypeIdentifier.identifier(name.value), isVariadic: false, defaultValue: nil))
        } while self.match(TokenType.COMMA)
        
        try self.consume(TokenType.IDENTIFIER, "Expect 'in' after in-body arguments.")
        
        return arguments
    }

    func expressionStatement() throws -> ASTNode {
        let expression = try self.expression()
        self.match(TokenType.SEMICOLON)
        return ExpressionStatement(expression: expression)
    }

    // MARK: - Expressions

    func expression() throws -> ASTNode {
        return try self.assignment()
    }

    func assignment() throws -> ASTNode {
        let expr = try self.ternary()

        if self.match(TokenType.EQUAL, TokenType.PLUS_EQUAL, TokenType.MINUS_EQUAL) {
            let equals = self.previous()
            let value = try self.assignment()
            
            if expr is VariableExpression || expr is IndexExpression || expr is GetExpression || expr is OptionalChainingExpression {
                return AssignmentExpression(target: expr, value: value, op: equals.type)
            }

            throw self.error(equals, "Invalid assignment target.")
        }

        return expr
    }

    func ternary() throws -> ASTNode {
        let condition = try self.coalescing()

        if self.match(TokenType.QUESTION) {
            let thenBranch = try self.expression()
            try self.consume(TokenType.COLON, "Expect ':' in ternary expression.")
            let elseBranch = try self.expression()
            return TernaryExpression(condition: condition, thenBranch: thenBranch, elseBranch: elseBranch)
        }

        return condition
    }

    func coalescing() throws -> ASTNode {
        var expr = try self.or()

        while self.match(TokenType.QUESTION_QUESTION) {
            let op = self.previous()
            let right = try self.or()
            expr = BinaryExpression(left: expr, right: right, op: op.type)
        }

        return expr
    }

    func or() throws -> ASTNode {
        var expr = try self.and()

        while self.match(TokenType.PIPE_PIPE) {
            let op = self.previous()
            let right = try self.and()
            expr = LogicalExpression(left: expr, right: right, op: op.type)
        }

        return expr
    }

    func and() throws -> ASTNode {
        var expr = try self.equality()

        while self.match(TokenType.AMPERSAND_AMPERSAND) {
            let op = self.previous()
            let right = try self.equality()
            expr = LogicalExpression(left: expr, right: right, op: op.type)
        }

        return expr
    }

    func equality() throws -> ASTNode {
        var expr = try self.comparison()

        while self.match(TokenType.BANG_EQUAL, TokenType.EQUAL_EQUAL) {
            let op = self.previous()
            let right = try self.comparison()
            expr = BinaryExpression(left: expr, right: right, op: op.type)
        }

        return expr
    }

    func comparison() throws -> ASTNode {
        var expr = try self.isType()

        while self.match(TokenType.GREATER, TokenType.GREATER_EQUAL, TokenType.LESS, TokenType.LESS_EQUAL) {
            let op = self.previous()
            let right = try self.isType()
            expr = BinaryExpression(left: expr, right: right, op: op.type)
        }

        return expr
    }

    func isType() throws -> ASTNode {
        var expr = try self.range()

        if self.match(TokenType.IS) {
            let type = try self.typeIdentifier()
            expr = IsExpression(expression: expr, type: type)
        }

        return expr
    }

    func range() throws -> ASTNode {
        var expr = try self.term()

        while self.match(TokenType.DOT_DOT_DOT, TokenType.DOT_DOT_LESS) {
            let op = self.previous()
            let right = try self.term()
            expr = BinaryRangeExpression(left: expr, right: right, op: op.type)
        }

        return expr
    }

    func term() throws -> ASTNode {
        var expr = try self.factor()

        while self.match(TokenType.MINUS, TokenType.PLUS) {  
            let op = self.previous()
            let right = try self.factor()
            expr = BinaryExpression(left: expr, right: right, op: op.type)
        }

        return expr
    }

    func factor() throws -> ASTNode {
        var expr = try self.asType()

        while self.match(TokenType.SLASH, TokenType.STAR) {
            let op = self.previous()
            let right = try self.asType()
            expr = BinaryExpression(left: expr, right: right, op: op.type)
        }

        return expr
    }

    func asType() throws -> ASTNode {
        var expr = try self.tryExpression()

        if self.match(TokenType.AS) {
            let isOptional = self.match(TokenType.ATTACHED_QUESTION)
            let isForceUnwrap = !isOptional && self.match(TokenType.ATTACHED_BANG)
            let type = try typeIdentifier()
            expr = AsExpression(expression: expr, type: type, isOptional: isOptional, isForceUnwrap: isForceUnwrap)
        }

        return expr
    }

    func tryExpression() throws -> ASTNode {
        if self.match(TokenType.TRY) {
            let isOptional = self.match(TokenType.ATTACHED_QUESTION)
            let isForceUnwrap = !isOptional && self.match(TokenType.ATTACHED_BANG)
            let expression = try self.call()
            return TryExpression(expression: expression, isOptional: isOptional, isForceUnwrap: isForceUnwrap)
        }

        return try self.unary()
    }

    func unary() throws -> ASTNode {
        if self.match(TokenType.BANG, TokenType.MINUS) {
            let op = self.previous()
            let right = try self.unary()
            return UnaryExpression(op: op.type, operand: right)
        }

        return try self.call()
    }

    func call() throws -> ASTNode {
        var expr = try self.primary()

        while true {
            if self.match(TokenType.LEFT_PAREN) {
                expr = try self.finishCall(expr)
            } 
            else if self.match(TokenType.DOT) {
                let name = try self.consume(TokenType.IDENTIFIER, "Expect property name after '.'.")
                expr = GetExpression(object: expr, name: name)
            } 
            else if self.match(TokenType.LEFT_BRACKET) {
                let index = try self.expression()
                try self.consume(TokenType.RIGHT_BRACKET, "Expect ']' after index.")
                expr = IndexExpression(object: expr, index: index)
            } 
            else if self.match(TokenType.ATTACHED_QUESTION) || self.match(TokenType.ATTACHED_BANG) {
                let forceUnwrap = self.previous().type == TokenType.ATTACHED_BANG
                expr = OptionalChainingExpression(object: expr, forceUnwrap: forceUnwrap)

                if self.match(TokenType.LEFT_PAREN) {
                    expr = try self.finishCall(expr, isOptional: true)
                } 
                else if self.match(TokenType.IDENTIFIER) {
                    let name = self.previous()
                    expr = GetExpression(object: expr, name: name, isOptional: true)
                } 
                else if self.match(TokenType.LEFT_BRACKET) {
                    let index = try self.expression()
                    try self.consume(TokenType.RIGHT_BRACKET, "Expect ']' after index.")
                    expr = IndexExpression(object: expr, index: index, isOptional: true)
                } 
                else if !forceUnwrap {
                    throw self.error(self.peek(), "Expect property, subscript, or method call after '?'.")
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
        if !self.check(TokenType.RIGHT_PAREN) {
            repeat {
                var label: Token? = nil
                if self.check(TokenType.IDENTIFIER) && self.checkNext(TokenType.COLON) {
                    label = try self.consume(TokenType.IDENTIFIER, "Expect argument label.")
                    try self.consume(TokenType.COLON, "Expect ':' after argument label.")
                }
                let value = try self.expression()
                arguments.append(Argument(label: label, value: value))
            } while self.match(TokenType.COMMA)
        }
        try self.consume(TokenType.RIGHT_PAREN, "Expect ')' after arguments.")

        return CallExpression(callee: callee, arguments: arguments, isOptional: isOptional)
    }

    func primary() throws -> ASTNode {
        if self.match(TokenType.FALSE) { return LiteralExpression(value: false) }
        if self.match(TokenType.TRUE) { return LiteralExpression(value: true) }
        if self.match(TokenType.NIL) { return LiteralExpression(value: nil) }
        if self.match(TokenType.SELF) { return SelfExpression() }
        
        if self.match(TokenType.STRING) { 
            return StringLiteralExpression(value: previous().value) 
        }

        if self.match(TokenType.STRING_MULTILINE) { 
            return StringLiteralExpression(value: previous().value, isMultiLine: true) 
        }

        if self.match(TokenType.INT) { 
            if let value = Int(self.previous().value) {
                return IntLiteralExpression(value: value)
            }
            else {
                throw self.error(self.previous(), "Invalid number literal.")
            }
        }
        
        if self.match(TokenType.DOUBLE) { 
            if let value = Double(self.previous().value) {
                return DoubleLiteralExpression(value: value)
            }
            else {
                throw self.error(self.previous(), "Invalid number literal.")
            }
        }

        if self.match(TokenType.IDENTIFIER) { 
            return VariableExpression(name: self.previous()) 
        }

        if self.match(TokenType.DOLLAR) {
            let index = try self.consume(TokenType.INT, "Expect argument index after '$.'").value
            return VariableExpression(name: Token(type: TokenType.IDENTIFIER, value: "$" + index, line: 0, column: 0, endOfLine: false))
        }

        if self.match(TokenType.LEFT_PAREN) {
            let expr = try self.expression()
            try self.consume(TokenType.RIGHT_PAREN, "Expect ')' after expression.")
            return GroupingExpression(expression: expr)
        }

        if self.match(TokenType.LEFT_BRACKET) {
            return try self.arrayOrDictionaryLiteral()
        }

        throw self.error(self.peek(), "Expect expression.")
    }

    func arrayOrDictionaryLiteral() throws -> ASTNode {
        if self.match(TokenType.COLON) {
            try self.consume(TokenType.RIGHT_BRACKET, "Expect ']' after empty dictionary literal.")
            return DictionaryLiteralExpression(elements: [])
        }

        if self.match(TokenType.RIGHT_BRACKET) {
            return ArrayLiteralExpression(elements: [])
        }

        let firstElement = try expression()

        if self.match(TokenType.COLON) {
            return try self.finishDictionaryLiteral(firstElement)
        } else {
            return try self.finishArrayLiteral(firstElement)
        }
    }

    func finishArrayLiteral(_ firstElement: ASTNode) throws -> ASTNode {
        var elements = [firstElement]
        while self.match(TokenType.COMMA) {
            if self.check(TokenType.RIGHT_BRACKET) { break }
            elements.append(try self.expression())
        }
        try self.consume(TokenType.RIGHT_BRACKET, "Expect ']' after array elements.")
        return ArrayLiteralExpression(elements: elements)
    }

    func finishDictionaryLiteral(_ firstKey: ASTNode) throws -> ASTNode {
        var elements: [KeyValuePair] = []
        let firstValue = try self.expression()
        elements.append(KeyValuePair(key: firstKey, value: firstValue))

        while self.match(TokenType.COMMA) {
            if self.check(TokenType.RIGHT_BRACKET) { break }
            let key = try self.expression()
            try self.consume(TokenType.COLON, "Expect ':' after dictionary key.")
            let value = try expression()
            elements.append(KeyValuePair(key: key, value: value))
        }
        try self.consume(TokenType.RIGHT_BRACKET, "Expect ']' after dictionary pairs.")
        return DictionaryLiteralExpression(elements: elements)
    }

    // MARK: - Helpers

    @discardableResult
    func match(_ types: TokenType...) -> Bool {
        for type in types {
            if self.check(type) {
                self.advance()
                return true
            }
        }
        return false
    }

    @discardableResult
    func consume(_ type: TokenType, _ message: String) throws -> Token {
        if self.check(type) { return self.advance() }
        throw self.error(self.peek(), message)
    }

    func check(_ type: TokenType) -> Bool {
        if self.isAtEnd() { return false }
        return self.peek().type == type
    }

    func checkNext(_ type: TokenType) -> Bool {
        if self.isAtEnd() { return false }
        if self.current + 1 >= self.tokens.count { return false }
        return self.tokens[self.current + 1].type == type
    }

    @discardableResult
    func advance() -> Token {
        if !self.isAtEnd() { self.current += 1 }
        return self.previous()
    }
    
    func isAtEnd() -> Bool {
        return self.peek().type == TokenType.EOF
    }

    func peek() -> Token {
        return self.tokens[self.current]
    }

    func previous() -> Token {
        return self.tokens[self.current - 1]
    }
    
    func next() -> Token {
        return self.tokens[self.current + 1]
    }
    
    func error(_ token: Token, _ message: String) -> Error {
        print("Error at '\(token.value)' (\(token.type)), line \(token.line), column \(token.column): \(message)")
        print(token.value)
        print(token.type)
        print(token.line)
        print(token.column)
        print(message)
        return ParserError(message)
    }

    func synchronize() {
        self.advance()
        while !self.isAtEnd() {
            if self.previous().type == TokenType.SEMICOLON { return }

            switch self.peek().type {
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
            self.advance()
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
