class Scope {
    init(type: Resolver.ScopeType, parent: Scope? = nil, entities: [String : Resolver.Entity] = [:]) {
        self.type = type
        self.parent = parent
        self.entities = entities
    }
    
    var type: Resolver.ScopeType
    var parent: Scope?
    var entities: [String: Resolver.Entity]
}
    
class Resolver {
    enum ScopeType {
        case GLOBAL
        case STRUCT
        case CLASS
        case ENUM
        case PROTOCOL
        case EXTENSION
        case FUNCTION
        case BLOCK
    }
    
    enum EntityType {
        case VARIABLE
        case FUNCTION
        case STRUCT
        case CLASS
        case ENUM
        case PROTOCOL
        case EXTENSION
    }
    
    struct Entity {
        var type: EntityType
        var isInitialized: Bool
    }
    
    private var currentScope: Scope? = nil
    var errors: [Error] = []
    
    func resolve(_ statements: [ASTNode]) -> [ASTNode] {
        var statements = statements
        
        self.currentScope = Scope(type: .GLOBAL, parent: nil)
        
        for index in 0 ..< statements.count {
            do {
                statements[index] = try resolveNode(statements[index])
            } catch {
                print("Error during resolution: \(error)")
                errors.append(error)
            }
        }
        
        return statements
    }
    
    private func resolveNode(_ node: ASTNode) throws -> ASTNode {
        switch node {
        case let node as VarDeclaration:
            return try resolveVarDeclaration(node)
        case let node as StructDeclaration:
            return try resolveStructDeclaration(node)
        case let node as ClassDeclaration:
            return try resolveClassDeclaration(node)
        case let node as FunctionDeclaration:
            return try resolveFunctionDeclaration(node)
        case let node as EnumDeclaration:
            return try resolveEnumDeclaration(node)
        case let node as ProtocolDeclaration:
            return try resolveProtocolDeclaration(node)
        case let node as ProtocolPropertyDeclaration:
            return try resolveProtocolPropertyDeclaration(node)
        case let node as ProtocolMethodDeclaration:
            return try resolveProtocolMethodDeclaration(node)
        case let node as TypealiasDeclaration:
            return try resolveTypealiasDeclaration(node)
        case let node as TernaryExpression:
            return try resolveTernaryExpression(node)
        case let node as IfStatement:
            return try resolveIfStatement(node)
        case let node as IfLetStatement:
            return try resolveIfLetStatement(node)
        case let node as GuardStatement:
            return try resolveGuardStatement(node)
        case let node as GuardLetStatement:
            return try resolveGuardLetStatement(node)
        case let node as SwitchStatement:
            return try resolveSwitchStatement(node)
        case let node as ForStatement:
            return try resolveForStatement(node)
        case let node as WhileStatement:
            return try resolveWhileStatement(node)
        case let node as RepeatStatement:
            return try resolveRepeatStatement(node)
        case let node as ReturnStatement:
            return try resolveReturnStatement(node)
        case let node as BreakStatement:
            return try resolveBreakStatement(node)
        case let node as ContinueStatement:
            return try resolveContinueStatement(node)
        case let node as BlankStatement:
            return try resolveBlankStatement(node)
        case let node as DoCatchStatement:
            return try resolveDoCatchStatement(node)
        case let node as ThrowStatement:
            return try resolveThrowStatement(node)
        case let node as TryExpression:
            return try resolveTryExpression(node)
        case let node as AsExpression:
            return try resolveAsExpression(node)
        case let node as IsExpression:
            return try resolveIsExpression(node)
        case let node as BlockStatement:
            return try resolveBlockStatement(node)
        case let node as ExpressionStatement:
            return try resolveExpressionStatement(node)
        case let node as AssignmentExpression:
            return try resolveAssignmentExpression(node)
        case let node as BinaryExpression:
            return try resolveBinaryExpression(node)
        case let node as LogicalExpression:
            return try resolveLogicalExpression(node)
        case let node as BinaryRangeExpression:
            return try resolveBinaryRangeExpression(node)
        case let node as UnaryExpression:
            return try resolveUnaryExpression(node)
        case let node as CallExpression:
            return try resolveCallExpression(node)
        case let node as GetExpression:
            return try resolveGetExpression(node)
        case let node as IndexExpression:
            return try resolveIndexExpression(node)
        case let node as OptionalChainingExpression:
            return try resolveOptionalChainingExpression(node)
        case let node as LiteralExpression:
            return try resolveLiteralExpression(node)
        case let node as StringLiteralExpression:
            return try resolveStringLiteralExpression(node)
        case let node as IntLiteralExpression:
            return try resolveIntLiteralExpression(node)
        case let node as DoubleLiteralExpression:
            return try resolveDoubleLiteralExpression(node)
        case let node as SelfExpression:
            return try resolveSelfExpression(node)
        case let node as VariableExpression:
            return try resolveVariableExpression(node)
        case let node as GroupingExpression:
            return try resolveGroupingExpression(node)
        case let node as ArrayLiteralExpression:
            return try resolveArrayLiteralExpression(node)
        case let node as DictionaryLiteralExpression:
            return try resolveDictionaryLiteralExpression(node)
        default:
            fatalError("Unexpected node type: \(type(of: node))")
        }
    }

    private func resolveVarDeclaration(_ node: VarDeclaration) throws -> VarDeclaration {
        var newNode = node

        try declare(node.name.value, type: EntityType.VARIABLE)
        
        if let initializer = node.initializer {
            newNode.initializer = try resolveNode(initializer)
            try define(node.name.value)
        }

        return newNode
    }

    private func resolveStructDeclaration(_ node: StructDeclaration) throws -> StructDeclaration {
        var newNode = node

        try declare(node.name.value, type: EntityType.STRUCT)
        beginScope(Scope(type: ScopeType.STRUCT))
        
        for (index, member) in node.members.enumerated() {
            newNode.members[index] = try resolveNode(member)
        }
        
        endScope()
        try define(node.name.value)
        
        return newNode
    }

    private func resolveClassDeclaration(_ node: ClassDeclaration) throws -> ClassDeclaration {
        var newNode = node
        
        try declare(node.name.value, type: EntityType.CLASS)
        beginScope(Scope(type: ScopeType.CLASS))
        
        for (index, method) in node.methods.enumerated() {
            newNode.methods[index] = try resolveFunctionDeclaration(method)
        }

        for (index, property) in node.properties.enumerated() {
            newNode.properties[index] = try resolveNode(property)
        }
        
        endScope()
        try define(node.name.value)
        
        return newNode
    }

    private func resolveFunctionDeclaration(_ node: FunctionDeclaration) throws -> FunctionDeclaration {
        var newNode = node

        try declare(node.name.value, type: EntityType.FUNCTION)
        
        beginScope(Scope(type: ScopeType.FUNCTION))
        
        for (index, parameter) in node.parameters.enumerated() {
            try declare(parameter.internalName.value, type: EntityType.VARIABLE)
            try define(parameter.internalName.value)
            newNode.parameters[index] = try resolveParameter(parameter)
        }

        for (index, attribute) in node.attributes.enumerated() {
            newNode.attributes[index] = try resolveAttribute(attribute)
        }
        
        newNode.body = try resolveBlockStatement(node.body)
        
        endScope()

        try define(node.name.value)
        
        return newNode
    }

    private func resolveParameter(_ node: Parameter) throws -> Parameter {
        var newNode = node
        if let defaultValue = node.defaultValue {
            newNode.defaultValue = try resolveNode(defaultValue)
        }
        return newNode
    }

    private func resolveAttribute(_ node: Attribute) throws -> Attribute {
        var newNode = node
        for (index, argument) in node.arguments.enumerated() {
            newNode.arguments[index] = try resolveNode(argument)
        }
        return newNode
    }
    
    private func resolveEnumDeclaration(_ node: EnumDeclaration) throws -> EnumDeclaration {
        var newNode = node

        try declare(node.name.value, type: EntityType.ENUM)
        try define(node.name.value)
        
        beginScope(Scope(type: ScopeType.ENUM))
        
        for (case_index, case_) in node.cases.enumerated() {
            if let rawValue = case_.rawValue {
                newNode.cases[case_index].rawValue = try resolveNode(rawValue)
            }

            for (index, associatedValue) in case_.associatedValues.enumerated() {
                newNode.cases[case_index].associatedValues[index] = try resolveParameter(associatedValue)
            }
        }
        
        endScope()
        
        return newNode
    }

    private func resolveProtocolDeclaration(_ node: ProtocolDeclaration) throws -> ProtocolDeclaration {
        var newNode = node
        
        try declare(node.name.value, type: EntityType.PROTOCOL)
        try define(node.name.value)
        
        beginScope(Scope(type: ScopeType.PROTOCOL))
        
        for (index, member) in node.members.enumerated() {
            newNode.members[index] = try resolveNode(member)
        }
        
        endScope()
        
        return newNode
    }

    private func resolveProtocolPropertyDeclaration(_ node: ProtocolPropertyDeclaration) throws -> ProtocolPropertyDeclaration {
        return node
    }

    private func resolveProtocolMethodDeclaration(_ node: ProtocolMethodDeclaration) throws -> ProtocolMethodDeclaration {
        var newNode = node

        for (index, parameter) in node.parameters.enumerated() {
            newNode.parameters[index] = try resolveParameter(parameter)
        }

        return newNode
    }
    
    private func resolveTypealiasDeclaration(_ node: TypealiasDeclaration) throws -> TypealiasDeclaration {
        let newNode = node
        
        try declare(node.name.value, type: EntityType.VARIABLE)
        try define(node.name.value)
        
        return newNode
    }

    private func resolveTernaryExpression(_ node: TernaryExpression) throws -> TernaryExpression {
        var newNode = node
        newNode.condition = try resolveNode(node.condition)
        newNode.thenBranch = try resolveNode(node.thenBranch)
        newNode.elseBranch = try resolveNode(node.elseBranch)
        return newNode
    }

    private func resolveIfStatement(_ node: IfStatement) throws -> IfStatement {
        var newNode = node
        newNode.condition = try resolveNode(node.condition)
        newNode.thenBranch = try resolveNode(node.thenBranch) as! BlockStatement
        if let elseBranch = node.elseBranch {
            newNode.elseBranch = try resolveNode(elseBranch)
        }
        return newNode
    }

    private func resolveIfLetStatement(_ node: IfLetStatement) throws -> IfLetStatement {
        var newNode = node

        beginScope(Scope(type: ScopeType.BLOCK))
        
        try declare(node.name.value, type: EntityType.VARIABLE)
        try define(node.name.value)

        newNode.thenBranch = try resolveNode(node.thenBranch)

        endScope()
        
        if let elseBranch = node.elseBranch {
            newNode.elseBranch = try resolveNode(elseBranch)
        }

        return newNode
    }

    private func resolveGuardStatement(_ node: GuardStatement) throws -> GuardStatement {
        var newNode = node
        newNode.condition = try resolveNode(node.condition)
        newNode.body = try resolveNode(node.body)
        return newNode
    }

    private func resolveGuardLetStatement(_ node: GuardLetStatement) throws -> GuardLetStatement {
        var newNode = node
        if let value = node.value {
            newNode.value = try resolveNode(value)
        }

        beginScope(Scope(type: ScopeType.BLOCK))
        newNode.body = try resolveNode(node.body)
        endScope()

        try declare(node.name.value, type: EntityType.VARIABLE)
        try define(node.name.value)
        
        return newNode
    }

    private func resolveSwitchStatement(_ node: SwitchStatement) throws -> SwitchStatement {
        var newNode = node
        
        newNode.expression = try resolveNode(node.expression)
        
        for (case_index, case_) in node.cases.enumerated() {
            for (index, expression) in case_.expressions.enumerated() {
                newNode.cases[case_index].expressions[index] = try resolveNode(expression)
            }
            
            for (index, statement) in case_.statements.enumerated() {
                newNode.cases[case_index].statements[index] = try resolveNode(statement)
            }
        }

        if let defaultCase = node.defaultCase {
            for (index, statement) in defaultCase.enumerated() {
                newNode.defaultCase![index] = try resolveNode(statement)
            }
        }

        return newNode
    }

    private func resolveForStatement(_ node: ForStatement) throws -> ForStatement {
        var newNode = node
        beginScope(Scope(type: ScopeType.BLOCK))
        newNode.iterable = try resolveNode(node.iterable)
        newNode.body = try resolveNode(node.body)
        endScope()
        return newNode
    }

    private func resolveWhileStatement(_ node: WhileStatement) throws -> WhileStatement {
        var newNode = node
        newNode.condition = try resolveNode(node.condition)
        newNode.body = try resolveNode(node.body)
        return newNode
    }

    private func resolveRepeatStatement(_ node: RepeatStatement) throws -> RepeatStatement {
        var newNode = node
        newNode.body = try resolveNode(node.body)
        newNode.condition = try resolveNode(node.condition)
        return newNode
    }

    private func resolveReturnStatement(_ node: ReturnStatement) throws -> ReturnStatement {
        var newNode = node
        if let value = node.value {
            newNode.value = try resolveNode(value)
        }
        return newNode
    }

    private func resolveBreakStatement(_ node: BreakStatement) throws -> BreakStatement {
        return node
    }

    private func resolveContinueStatement(_ node: ContinueStatement) throws -> ContinueStatement {
        return node
    }

    private func resolveBlankStatement(_ node: BlankStatement) throws -> BlankStatement {
        return node
    }

    private func resolveDoCatchStatement(_ node: DoCatchStatement) throws -> DoCatchStatement {
        var newNode = node
        newNode.body = try resolveNode(node.body)
        newNode.catchBlock = try resolveNode(node.catchBlock)
        return newNode
    }

    private func resolveThrowStatement(_ node: ThrowStatement) throws -> ThrowStatement {
        var newNode = node
        newNode.expression = try resolveNode(node.expression)
        return newNode
    }

    private func resolveTryExpression(_ node: TryExpression) throws -> TryExpression {
        var newNode = node
        newNode.expression = try resolveNode(node.expression)
        return newNode
    }

    private func resolveAsExpression(_ node: AsExpression) throws -> AsExpression {
        var newNode = node
        newNode.expression = try resolveNode(node.expression)
        return newNode
    }

    private func resolveIsExpression(_ node: IsExpression) throws -> IsExpression {
        var newNode = node
        newNode.expression = try resolveNode(node.expression)
        return newNode
    }

    private func resolveBlockStatement(_ node: BlockStatement) throws -> BlockStatement {
        var newNode = node
        beginScope(Scope(type: .FUNCTION))
        for (index, parameter) in node.inBodyParameters.enumerated() {
            try declare(parameter.internalName.value, type: EntityType.VARIABLE)
            try define(parameter.internalName.value)
            newNode.inBodyParameters[index] = try resolveParameter(parameter)
        }
        for (index, statement) in node.statements.enumerated() {
            newNode.statements[index] = try resolveNode(statement)
        }
        endScope()
        return newNode
    }

    private func resolveExpressionStatement(_ node: ExpressionStatement) throws -> ExpressionStatement {
        var newNode = node
        newNode.expression = try resolveNode(node.expression)
        return newNode
    }

    private func resolveAssignmentExpression(_ node: AssignmentExpression) throws -> AssignmentExpression {
        var newNode = node
        newNode.target = try resolveNode(node.target)
        newNode.value = try resolveNode(node.value)
        return newNode
    }

    private func resolveBinaryExpression(_ node: BinaryExpression) throws -> BinaryExpression {
        var newNode = node
        newNode.left = try resolveNode(node.left)
        newNode.right = try resolveNode(node.right)
        return newNode
    }

    private func resolveLogicalExpression(_ node: LogicalExpression) throws -> LogicalExpression {
        var newNode = node
        newNode.left = try resolveNode(node.left)
        newNode.right = try resolveNode(node.right)
        return newNode
    }

    private func resolveBinaryRangeExpression(_ node: BinaryRangeExpression) throws -> BinaryRangeExpression {
        var newNode = node
        newNode.left = try resolveNode(node.left)
        newNode.right = try resolveNode(node.right)
        return newNode
    }

    private func resolveUnaryExpression(_ node: UnaryExpression) throws -> UnaryExpression {
        var newNode = node
        newNode.operand = try resolveNode(node.operand)
        return newNode
    }

    private func resolveCallExpression(_ node: CallExpression) throws -> CallExpression {
        var newNode = node

        var currentScope = self.currentScope
        while currentScope != nil {

            // Find the callee in the scope ancestry, and mark if it is an initializer
            if let name = (node.callee as? VariableExpression)?.name.value, 
               let entity = currentScope!.entities[name] {
                if entity.type == .CLASS || entity.type == .STRUCT {
                    newNode.isInitializer = true
                    break
                }
            }
            
            currentScope = currentScope!.parent
        }

        // Resolve

        newNode.callee = try resolveNode(node.callee)

        for (index, argument) in node.arguments.enumerated() {
            newNode.arguments[index].value = try resolveNode(argument.value)
        }
        
        return newNode
    }

    private func resolveGetExpression(_ node: GetExpression) throws -> GetExpression {
        var newNode = node
        newNode.object = try resolveNode(node.object)
        return newNode
    }

    private func resolveIndexExpression(_ node: IndexExpression) throws -> IndexExpression {
        var newNode = node
        newNode.object = try resolveNode(node.object)
        newNode.index = try resolveNode(node.index)
        return newNode
    }

    private func resolveOptionalChainingExpression(_ node: OptionalChainingExpression) throws -> OptionalChainingExpression {
        var newNode = node
        newNode.object = try resolveNode(node.object)
        return newNode
    }

    private func resolveLiteralExpression(_ node: LiteralExpression) throws -> LiteralExpression {
        return node
    }

    private func resolveStringLiteralExpression(_ node: StringLiteralExpression) throws -> StringLiteralExpression {
        return node
    }

    private func resolveIntLiteralExpression(_ node: IntLiteralExpression) throws -> IntLiteralExpression {
        return node
    }

    private func resolveDoubleLiteralExpression(_ node: DoubleLiteralExpression) throws -> DoubleLiteralExpression {
        return node
    }

    private func resolveSelfExpression(_ node: SelfExpression) throws -> SelfExpression {
        return node
    }

    private func resolveVariableExpression(_ node: VariableExpression) throws -> VariableExpression {
        let newNode = node

        // TODO: Check if the variable is declared in the current scope
        // and mark it as used
        var currentScope = self.currentScope
        while currentScope != nil {
            if let entity = currentScope?.entities[node.name.value] {
                if entity.isInitialized {
                    // TODO: Mark variable as used
                    break
                }
                else {
                    // TODO
                    // throw ParserError("Variable '\(node.name.value)' used before being initialized.")
                }
            }
            else {
                // TODO
                // throw ParserError("Undefined variable '\(node.name.value)'.")
            }

            currentScope = currentScope?.parent
        }

        return newNode
    }

    private func resolveGroupingExpression(_ node: GroupingExpression) throws -> GroupingExpression {
        var newNode = node
        newNode.expression = try resolveNode(node.expression)
        return newNode
    }

    private func resolveArrayLiteralExpression(_ node: ArrayLiteralExpression) throws -> ArrayLiteralExpression {
        var newNode = node
        for (index, element) in node.elements.enumerated() {
            newNode.elements[index] = try resolveNode(element)
        }
        return newNode
    }

    private func resolveDictionaryLiteralExpression(_ node: DictionaryLiteralExpression) throws -> DictionaryLiteralExpression {
        var newNode = node
        for (index, pair) in node.elements.enumerated() {
            newNode.elements[index].key = try resolveNode(pair.key)
            newNode.elements[index].value = try resolveNode(pair.value)
        }
        return newNode
    }
    
    // MARK: - Helpers
    
    private func beginScope(_ newScope: Scope) {
        newScope.parent = self.currentScope
        self.currentScope = newScope
    }
    
    private func endScope() {
        self.currentScope = currentScope?.parent
    }
   
    private func declare(_ name: String, type: EntityType) throws {
        if currentScope == nil {
            throw ParserError("No current scope.")
        }
        
        if currentScope!.entities.keys.contains(name) {
            throw ParserError("Variable with this name already declared in this scope.")
        }

        currentScope!.entities[name] = Entity(type: type, isInitialized: false)
    }
    
    private func define(_ name: String) throws {
        if currentScope == nil {
            throw ParserError("No current scope.")
        }

        if let scope = currentScope {
            // TODO: Walk up tree and make sure it exists somewhere
            //  If it exists in a class, we need to mark it as such so the transpiler knows to access it via the class instance rather than a standalone variable.
            //  Really, we probably just want to store an indication of who owns the variable and then let the transpiler deal with it.
            // if scope.entities[name.lexeme] == nil {
            //     throw ParserError("Undefined variable \(name.lexeme).")
            // }

            scope.entities[name]?.isInitialized = true
        }
    }
}

// TODO: When inside of something that will become a class, any references to members needs to be marked as such so the transpiler knows to access the member via the class instance rather than a standalone variable.

// TODO: Ensure optionals are accessed with ? or ! (or in an if let)
