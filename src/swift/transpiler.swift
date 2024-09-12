protocol Transpiler {
  func transpile(ast: [ASTNode]) -> String
}

struct TranspilerError: Error {
    let message: String
}

struct JSTranspiler: Transpiler {
    let emitTS: Bool
    
    init(emitTS: Bool = false) {
        self.emitTS = emitTS
    }

    func transpile(ast: [ASTNode]) -> String {
        return runtime + "\n\n// Compiled code\n\n" + ast.map { transpileNode($0) }.joined(separator: "\n")
    }

    private func transpileNode(_ node: ASTNode, isInClass: Bool = false) -> String {
        switch node {
        case let node as VarDeclaration:
            return transpileVarDeclaration(node, isInClass: isInClass)
        case let node as StructDeclaration:
            return transpileStructDeclaration(node)
        case let node as ClassDeclaration:
            return transpileClassDeclaration(node)
        case let node as FunctionDeclaration:
            return transpileFunction(node)
        case let node as EnumDeclaration:
            return transpileEnumDeclaration(node, isInClass: isInClass)
        case let node as ProtocolDeclaration:
            return transpileProtocolDeclaration(node)
        case let node as TypealiasDeclaration:
            return transpileTypealias(node)
        case let node as IfStatement:
            return transpileIf(node)
        case let node as IfLetStatement:
            return transpileIfLet(node)
        case let node as GuardStatement:
            return transpileGuard(node)
        case let node as GuardLetStatement:
            return transpileGuardLet(node)
        case let node as SwitchStatement:
            return transpileSwitch(node)
        case let node as ForStatement:
            return transpileFor(node)
        case let node as WhileStatement:
            return transpileWhile(node)
        case let node as RepeatStatement:
            return transpileRepeat(node)
        case let node as ReturnStatement:
            return transpileReturn(node)
        case let node as BreakStatement:
            return transpileBreak(node)
        case let node as ContinueStatement:
            return transpileContinue(node)
        case let node as BlankStatement:
            return transpileBlank(node)
        case let node as BlockStatement:
            return transpileBlock(node)
        case let node as ExpressionStatement:
            return transpileExpressionStatement(node)
        default:
            print("Transpiler error: Unknown node type: \(type(of: node))")
            return ""
        }
    }

    private func transpileVarDeclaration(_ node: VarDeclaration, isInClass: Bool = false) -> String {
        let keyword = isInClass ? "" : (node.isConstant ? "const" : "let")
        let name = node.name.value
        let type = emitTS && node.type != nil ? ": \(transpileType(node.type!))" : ""
        let initializer = node.initializer != nil ? " = \(transpileExpression(node.initializer!))" : ""
        return "\(keyword) \(name)\(type)\(initializer);"
    }

    private func transpileStructDeclaration(_ node: StructDeclaration) -> String {
      // TODO: Need to adjust for JS's pass-by-reference behavior
        let name = node.name.value
        let inheritedTypes = node.inheritedTypes.map { $0.value }.joined(separator: ", ")
        let members = node.members.map { transpileNode($0, isInClass: true) }.joined(separator: "\n  ")
        
        if emitTS {
            return "interface \(name)\(inheritedTypes.isEmpty ? "" : " extends \(inheritedTypes)") {\n  \(members)\n}"
        } else {
            var constructor = ""
            if !node.members.contains(where: { node in
                if let node = node as? FunctionDeclaration {
                    return node.name.value == "init"
                }
                return false
            }) {
                constructor = "  constructor(params = {}) {\n    Object.assign(this, params);\n  }\n\n"
            }
            return "class \(name) {\n\(constructor)  \(members)\n}"
        }
    }

    private func transpileClassDeclaration(_ node: ClassDeclaration) -> String {
        let name = node.name.value
        let superclass = node.inheritedTypes.first?.value ?? ""
        let properties = node.properties.map { transpileVarDeclaration($0 as! VarDeclaration, isInClass: true) }.joined(separator: "\n  ")
        let methods = node.methods.map { transpileFunction($0) }.joined(separator: "\n\n  ")
        
        return "class \(name)\(superclass.isEmpty ? "" : " extends \(superclass)") {\n  \(properties)\n\n  \(methods)\n}"
    }

    private func transpileFunction(_ node: FunctionDeclaration) -> String {
        // Function names, except for constructor, should include external names of parameters that don't have default values, e.g. "print_message"
        // But we may need to do that in the resolver

        let name = node.name.value == "init" ? "constructor" : node.name.value
        let params = "params = {}"
        let returnType = emitTS && node.returnType != nil ? ": \(transpileType(node.returnType!))" : ""
        let paramsInBody = transpileParamsIntoBody(node.parameters)
        let bodyBlock = transpileBlock(node.body)
        let body = "\(paramsInBody)\n\(bodyBlock)"

        let staticKeyword = node.isStatic ? "static " : ""
        
        return "\(staticKeyword)\(node.kind == .function ? "function " : "")\(name)(\(params))\(returnType) { \(body) }"
    }

    private func transpileParamsIntoBody(_ parameters: [Parameter]) -> String {
        let paramDestructuring = parameters.map { param in
            let externalName = param.externalName?.value ?? param.internalName.value
            let internalName = param.internalName.value
            let defaultValue = param.defaultValue != nil ? " = \(transpileExpression(param.defaultValue!))" : ""
            return externalName == internalName ? "\(internalName)\(defaultValue)" : "\(externalName): \(internalName)\(defaultValue)"
        }.joined(separator: ", ")
        
        return "const { \(paramDestructuring) } = params;"
    }

    private func transpileEnumDeclaration(_ node: EnumDeclaration, isInClass: Bool = false) -> String {
        let name = node.name.value
        
        if emitTS {
          let cases = node.cases.map { c in
            let caseName = c.name.value
                return "\(caseName) = '\(caseName)'"
            }.joined(separator: ",\n  ")
            return "enum \(name) {\n  \(cases)\n}"
        } else {
            let cases = node.cases.map { c in
                let caseName = c.name.value
                return "\(caseName): '\(caseName)'"
            }.joined(separator: ",\n  ")
            return "\(isInClass ? "":"const ")\(name) = Object.freeze({\n  \(cases)\n});"
        }
    }

    private func transpileProtocolDeclaration(_ node: ProtocolDeclaration) -> String {
        let name = node.name.value
        let members = node.members.map { transpileNode($0, isInClass: true) }.joined(separator: "\n  ")
        
        if emitTS {
            return "interface \(name) {\n  \(members)\n}"
        } else {
            return "class \(name) {\n  \(members)\n}"
        }
    }

    private func transpileTypealias(_ node: TypealiasDeclaration) -> String {
        let name = node.name.value
        let value = transpileType(node.type)
        return "const \(name) = \(value);"
    }

    private func transpileIf(_ node: IfStatement) -> String {
        let condition = transpileExpression(node.condition)
        let thenBranch = transpileBlock(node.thenBranch as! BlockStatement)
        var elseBranch = ""
        if let elseBranchNode = node.elseBranch {
            elseBranch = " else { \(transpileNode(elseBranchNode)) }"
        }
        return "if (\(condition)) { \(thenBranch) }\(elseBranch)"
    }

    private func transpileIfLet(_ node: IfLetStatement) -> String {
        let name = node.name.value
        let value = transpileExpression(node.value!)
        let thenBranch = transpileBlock(node.thenBranch as! BlockStatement)
        var elseBranch = ""
        if let elseBranchNode = node.elseBranch {
            elseBranch = " else { \(transpileNode(elseBranchNode)) }"
        }
        let assignment = name == value ? "" : "const \(name) = \(value); "
        return "if (\(value) !== undefined && \(value) !== null) { \(assignment)\(thenBranch) }\(elseBranch)"
    }

    private func transpileGuard(_ node: GuardStatement) -> String {
        let condition = transpileExpression(node.condition)
        let body = transpileBlock(node.body as! BlockStatement)
        return "if (!(\(condition))) { \(body) }"
    }

    private func transpileGuardLet(_ node: GuardLetStatement) -> String {
        let name = node.name.value
        let value = transpileExpression(node.value!)
        let body = transpileBlock(node.body as! BlockStatement)
        return "if (\(value) === undefined || \(value) === null) { \(body) return; } const \(name) = \(value);"
    }

    private func transpileSwitch(_ node: SwitchStatement) -> String {
        let expression = transpileExpression(node.expression)
        let cases = node.cases.map { transpileSwitchCase($0) }.joined(separator: "\n")
        let defaultCase = node.defaultCase != nil ? "default: { \(transpileBlock(BlockStatement(statements: node.defaultCase!))) }" : ""
        return "switch (\(expression)) {\n\(cases)\n\(defaultCase)\n}"
    }

    private func transpileSwitchCase(_ caseNode: SwitchCase) -> String {
        let expressions = caseNode.expressions.map { transpileExpression($0) }.joined(separator: ":\n  case ")
        let statements = caseNode.statements.map { transpileNode($0) }.joined(separator: "\n")
        return "  case \(expressions): { \n\(statements) \n break; }"
    }

    private func transpileFor(_ node: ForStatement) -> String {
        let variable = node.variable.value
        let iterable = transpileExpression(node.iterable)
        let body = transpileBlock(node.body as! BlockStatement)
        return "for (const \(variable) of \(iterable)) { \(body) }"
    }

    private func transpileWhile(_ node: WhileStatement) -> String {
        let condition = transpileExpression(node.condition)
        let body = transpileBlock(node.body as! BlockStatement)
        return "while (\(condition)) { \(body) }"
    }

    private func transpileRepeat(_ node: RepeatStatement) -> String {
        let body = transpileBlock(node.body as! BlockStatement)
        let condition = transpileExpression(node.condition)
        return "do { \(body) } while (\(condition));"
    }

    private func transpileReturn(_ node: ReturnStatement) -> String {
        if let value = node.value {
            return "return \(transpileExpression(value));"
        } else {
            return "return;"
        }
    }

    private func transpileBreak(_ node: BreakStatement) -> String {
        return "break;"
    }

    private func transpileContinue(_ node: ContinueStatement) -> String {
        return "continue;"
    }

    private func transpileBlank(_ node: BlankStatement) -> String {
        return ""
    }

    private func transpileExpressionStatement(_ node: ExpressionStatement) -> String {
        return "\(transpileExpression(node.expression));"
    }

    private func transpileExpression(_ node: ASTNode) -> String {
        switch node {
        case let node as AssignmentExpression:
            return transpileAssignment(node)
        case let node as BinaryExpression:
            return transpileBinary(node)
        case let node as LogicalExpression:
            return transpileLogical(node)
        case let node as BinaryRangeExpression:
            return transpileBinaryRange(node)
        case let node as UnaryExpression:
            return transpileUnary(node)
        case let node as CallExpression:
            return transpileCall(node)
        case let node as GetExpression:
            return transpileGet(node)
        case let node as IndexExpression:
            return transpileIndex(node)
        case let node as OptionalChainingExpression:
            return transpileOptionalChaining(node)
        case let node as LiteralExpression:
            return transpileLiteral(node)
        case let node as StringLiteralExpression:
            return transpileStringLiteral(node)
        case let node as IntLiteralExpression:
            return transpileIntLiteral(node)
        case let node as DoubleLiteralExpression:
            return transpileDoubleLiteral(node)
        case let node as SelfExpression:
            return transpileSelf(node)
        case let node as VariableExpression:
            return transpileVariable(node)
        case let node as GroupingExpression:
            return transpileGrouping(node)
        case let node as ArrayLiteralExpression:
            return transpileArrayLiteral(node)
        case let node as DictionaryLiteralExpression:
            return transpileDictionaryLiteral(node)
        default:
            print("Transpiler error: Unknown expression type: \(type(of: node))")
            return ""
        }
    }

    private func transpileAssignment(_ node: AssignmentExpression) -> String {
        let target = transpileExpression(node.target)
        let value = transpileExpression(node.value)
        switch node.op {
        case .PLUS_EQUAL:
            return "\(target) += \(value)"
        case .MINUS_EQUAL:
            return "\(target) -= \(value)"
        default:
            return "\(target) = \(value)"
        }
    }

    private func transpileBinary(_ node: BinaryExpression) -> String {
        let left = transpileExpression(node.left)
        let right = transpileExpression(node.right)
        let op = transpileOperator(node.op)
        return "\(left) \(op) \(right)"
    }

    private func transpileLogical(_ node: LogicalExpression) -> String {
        let left = transpileExpression(node.left)
        let right = transpileExpression(node.right)
        let op = transpileOperator(node.op)
        return "\(left) \(op) \(right)"
    }

    private func transpileBinaryRange(_ node: BinaryRangeExpression) -> String {
        let left = transpileExpression(node.left)
        let right = transpileExpression(node.right)
        
        switch node.op {
        case .DOT_DOT_DOT:
            return ".slice(\(left), \(right) + 1)"
        case .DOT_DOT_LESS:
            return ".slice(\(left), \(right))"
        default:
            let op = transpileOperator(node.op)
            return "\(left) \(op) \(right)"
        }
    }

    private func transpileUnary(_ node: UnaryExpression) -> String {
        let operand = transpileExpression(node.operand)
        let op = transpileOperator(node.op)
        return "\(op)\(operand)"
    }

    private func transpileOperator(_ op: TokenType) -> String {
        switch op {
        case .PLUS:
            return "+"
        case .MINUS:
            return "-"
        case .STAR:
            return "*"
        case .SLASH:
            return "/"
//        case .PERCENT:
//            return "%"
        case .BANG:
            return "!"
        case .BANG_EQUAL:
            return "!=="
        case .EQUAL:
            return "=="
        case .EQUAL_EQUAL:
            return "==="
        case .LESS:
            return "<"
        case .LESS_EQUAL:
            return "<="
        case .GREATER:
            return ">"
        case .GREATER_EQUAL:
            return ">="
            
        case .AMPERSAND_AMPERSAND:
            return "&&"
        case .PIPE_PIPE:
            return "||"
        case .QUESTION_QUESTION:
            return "??"

        default:
            print("Transpiler error: Unknown operator: \(op)")
            return ""
        }
    }

    private func transpileCall(_ node: CallExpression) -> String {
        let callee = transpileExpression(node.callee)
        let args = node.arguments.map { arg in
            if let label = arg.label {
                return "\(label.value): \(transpileExpression(arg.value))"
            }
            else {
                return "_: \(transpileExpression(arg.value))"
            }
        }.joined(separator: ", ")
        
        let wrappedArgs = "{ \(args) }" //node.arguments.contains(where: { $0.label != nil }) ? "{ \(args) }" : args
        let isClass = callee.first?.isUppercase == true
        return "\(isClass ? "new " : "")\(callee)(\(wrappedArgs))"
    }

    private func transpileGet(_ node: GetExpression) -> String {
        let object = transpileExpression(node.object)
        let property = node.name.value
        return "\(object).\(property)"
    }

    private func transpileIndex(_ node: IndexExpression) -> String {
        let object = transpileExpression(node.object)
        let index = transpileExpression(node.index)
        if let rangeIndex = node.index as? BinaryRangeExpression {
            return "\(object)\(transpileBinaryRange(rangeIndex))"
        } else {
            return "\(object)[\(index)]"
        }
    }

    private func transpileOptionalChaining(_ node: OptionalChainingExpression) -> String {
        let object = transpileExpression(node.object)
        return "\(object)\(node.forceUnwrap ? "" : "?.")"
    }

    private func transpileLiteral(_ node: LiteralExpression) -> String {
        if let value = node.value {
            return "\(value)"
        }
        return "null"
    }

    private func transpileStringLiteral(_ node: StringLiteralExpression) -> String {
        if node.isMultiLine {
            return "`\(node.value)`"
        }
        else {
            return "\"\(node.value)\""
        }
    }

    private func transpileIntLiteral(_ node: IntLiteralExpression) -> String {
        return "\(node.value)"
    }

    private func transpileDoubleLiteral(_ node: DoubleLiteralExpression) -> String {
        return "\(node.value)"
    }

    private func transpileArray(_ node: ArrayLiteralExpression) -> String {
        let elements = node.elements.map { transpileExpression($0) }.joined(separator: ", ")
        return "[\(elements)]"
    }

    private func transpileDictionary(_ node: DictionaryLiteralExpression) -> String {
        let pairs = node.elements.map { pair in
            let key = transpileExpression(pair.key)
            let value = transpileExpression(pair.value)
            return "\(key): \(value)"
        }.joined(separator: ", ")
        return "({ \(pairs) })"
    }

    private func transpileGrouping(_ node: GroupingExpression) -> String {
        let expression = transpileExpression(node.expression)
        return "(\(expression))"
    }

    private func transpileSelf(_ node: SelfExpression) -> String {
        return "this"
    }

    private func transpileVariable(_ node: VariableExpression) -> String {
        return node.name.value
    }

    private func transpileArrayLiteral(_ node: ArrayLiteralExpression) -> String {
        let elements = node.elements.map { transpileExpression($0) }.joined(separator: ", ")
        return "[\(elements)]"
    }

    private func transpileDictionaryLiteral(_ node: DictionaryLiteralExpression) -> String {
        let pairs = node.elements.map { pair in
            let key = transpileExpression(pair.key)
            let value = transpileExpression(pair.value)
            return "\(key): \(value)"
        }.joined(separator: ", ")
        return "({ \(pairs) })"
    }

    private func transpileType(_ type: TypeIdentifier) -> String {
        switch type {
        case .identifier(let token):
            switch token.value {
            case "Int", "Double", "Float":
                return "number"
            case "String", "Character":
                return "string"
            case "Bool":
                return "boolean"
            case "Any":
                return "any"
            case "Void":
                return "void"
            default:
                return token.value
            }
        case .array(let elementType):
            return "\(transpileType(elementType))[]"
        case .dictionary(let keyType, let valueType):
            return "{ [key: \(transpileType(keyType))]: \(transpileType(valueType)) }"
        case .optional(let baseType):
            return "\(transpileType(baseType)) | null | undefined"
        }
    }

    private func transpileBlock(_ node: BlockStatement) -> String {
        return node.statements.map { transpileNode($0) }.joined(separator: "\n")
    }
}
