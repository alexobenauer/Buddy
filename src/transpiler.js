import { PT } from "./parser.js";

class Transpiler {
  constructor(ast, emitTS = false) {
    this.ast = ast;
    this.emitTS = emitTS;
  }

  transpile({ excludeRuntime = false } = {}) {
    try {
      return (excludeRuntime ? '' : runtime + '\n\n') + this.ast.map(node => this.transpileNode(node)).join('\n');
    } catch (error) {
      console.error('Error during transpilation:');
      console.error(error.stack);
      throw error; // Re-throw the error after logging the stack trace
    }
  }

  transpileNode(node) {
    switch (node.type) {
      case PT.VAR_DECLARATION:
        return this.transpileVarDeclaration(node);
      case PT.FUNCTION:
        return this.transpileFunction(node);
      case PT.IF:
        return this.transpileIf(node);
      case PT.IF_LET:
        return this.transpileIfLet(node);
      case PT.GUARD:
        return this.transpileGuard(node);
      case PT.GUARD_LET:
        return this.transpileGuardLet(node);
      case PT.SWITCH:
        return this.transpileSwitch(node);
      case PT.WHILE:
        return this.transpileWhile(node);
      case PT.FOR:
        return this.transpileFor(node);
      case PT.RETURN:
        return this.transpileReturn(node);
      case PT.EXPRESSION_STATEMENT:
        return this.transpileExpressionStatement(node);
      case PT.ENUM_DECLARATION:
        return this.transpileEnumDeclaration(node);
      case PT.PROTOCOL_DECLARATION:
        return this.transpileProtocolDeclaration(node);
      case PT.STRUCT_DECLARATION:
        return this.transpileStructDeclaration(node);
      case PT.CLASS_DECLARATION:
        return this.transpileClassDeclaration(node);
      default:
        return this.transpileExpression(node);
    }
  }

  transpileVarDeclaration(node, isClass = false) {
    const keyword = isClass ? '' : (node.constant ? 'const ' : 'let ');
    const name = node.name.value;
    const type = this.emitTS && node.varType ? `: ${this.transpileType(node.varType)}` : '';
    const initializer = node.initializer ? ` = ${this.transpileExpression(node.initializer)}` : '';
    return `${keyword}${name}${type}${initializer};`;
  }

  transpileFunction(node) {
    const name = node.name.value;
    const params = 'params = {}'
    const returnType = this.emitTS && node.returnType ? `: ${this.transpileType(node.returnType)}` : '';
    const body = this.transpileFunctionBody(node.body, node.parameters);
    return `function ${name}(${params})${returnType} { ${body} }`;
  }

  transpileFunctionBody(body, parameters) {
    const bodyCode = this.transpileBlock(body);
    
    // Destructure parameters
    const paramDestructuring = parameters.map(param => {
      const externalName = param.externalName ? param.externalName.value : param.internalName.value;
      const internalName = param.internalName.value;
      const defaultValue = param.defaultValue ? ` = ${this.transpileExpression(param.defaultValue)}` : '';
      return externalName === internalName
        ? `${internalName}${defaultValue}`
        : `${externalName}: ${internalName}${defaultValue}`;
    }).join(', ');

    const destructuring = `const { ${paramDestructuring} } = params;`;

    return `${destructuring}\n${bodyCode}`;
  }

  transpileParameter(param) {
    const name = param.internalName.value;
    const type = this.emitTS ? `: ${this.transpileType(param.parameterType)}` : '';
    const defaultValue = param.defaultValue ? ` = ${this.transpileExpression(param.defaultValue)}` : '';
    return `${name}${type}${defaultValue}`;
  }

  transpileIf(node) {
    const condition = this.transpileExpression(node.condition);
    const thenBranch = this.transpileBlock(node.thenBranch);
    const elseBranch = node.elseBranch ? ` else { ${this.transpileBlock(node.elseBranch)} }` : '';
    return `if (${condition}) { ${thenBranch} }${elseBranch}`;
  }

  transpileIfLet(node) {
    const name = node.name.value;
    const value = this.transpileExpression(node.value);
    const thenBranch = this.transpileBlock(node.thenBranch);
    const elseBranch = node.elseBranch ? ` else { ${this.transpileBlock(node.elseBranch)} }` : '';
    const assignment = name === value ? '' : `const ${name} = ${value}; `;
    return `if (${value} !== undefined && ${value} !== null) { ${assignment}${thenBranch} }${elseBranch}`;
  }

  transpileGuard(node) {
    const condition = this.transpileExpression(node.condition);
    const body = this.transpileBlock(node.body);
    return `if (!(${condition})) { ${body} }`;
  }

  transpileGuardLet(node) {
    const name = node.name.value;
    const value = this.transpileExpression(node.value);
    const body = this.transpileBlock(node.body);
    return `if (${value} === undefined || ${value} === null) { ${body} return; } const ${name} = ${value};`;
  }

  transpileSwitch(node) {
    const expression = this.transpileExpression(node.expression);
    const cases = node.cases.map(this.transpileSwitchCase.bind(this)).join('\n');
    return `switch (${expression}) {\n${cases}\n}`;
  }

  transpileSwitchCase(caseNode) {
    if (caseNode.isDefault) {
      return `default: { \n${this.transpileBlock(caseNode.body)} \n}`;
    }
    const pattern = this.transpileExpression(caseNode.pattern);
    return `case ${pattern}: { \n${this.transpileBlock(caseNode.body)} \n}`;
  }

  transpileWhile(node) {
    const condition = this.transpileExpression(node.condition);
    const body = this.transpileBlock(node.body);
    return `while (${condition}) { ${body} }`;
  }

  transpileFor(node) {
    if (node.inExpression) {
      const item = node.item.value;
      const collection = this.transpileExpression(node.inExpression);
      const body = this.transpileBlock(node.body);
      return `for (const ${item} of ${collection}) { ${body} }`;
    } else {
      const initialization = this.transpileStatement(node.initialization);
      const condition = this.transpileExpression(node.condition);
      const increment = this.transpileExpression(node.increment);
      const body = this.transpileBlock(node.body);
      return `for (${initialization} ${condition}; ${increment}) { ${body} }`;
    }
  }

  transpileReturn(node) {
    const value = node.value ? this.transpileExpression(node.value) : '';
    return `return ${value};`;
  }

  transpileEnumDeclaration(node) {
    const name = node.name.value;
    if (this.emitTS) {
      const cases = node.cases.map(c => `${c.name.value} = '${c.name.value}'`).join(',\n  ');
      return `enum ${name} {\n  ${cases}\n}`;
    } 
    else {
      const cases = node.cases.map(c => `${c.name.value}: '${c.name.value}'`).join(',\n  ');
      return `const ${name} = Object.freeze({\n  ${cases}\n});`;
    }
  }

  transpileProtocolDeclaration(node) {
    const name = node.name.value;
    const members = node.members.map(this.transpileProtocolMember.bind(this)).join('\n  ');
    if (!this.emitTS) {
      return `class ${name} {\n  ${members}\n}`;
    } else {
      return `interface ${name} {\n  ${members}\n}`;
    }
  }

  transpileProtocolMember(member) {
    if (member.type === PT.PROTOCOL_PROPERTY) {
      return this.transpileProtocolProperty(member);
    } else if (member.type === PT.PROTOCOL_METHOD) {
      return this.transpileProtocolMethod(member);
    }
  }

  transpileProtocolProperty(property) {
    const name = property.name.value;
    const type = this.transpileType(property.propertyType);
    return `${name}: ${type};`;
  }

  transpileProtocolMethod(method) {
    const name = method.name.value;
    const params = method.parameters.map(this.transpileParameter.bind(this)).join(', ');
    const returnType = this.emitTS && method.returnType ? `: ${this.transpileType(method.returnType)}` : '';
    return `${name}(${params})${returnType} {}`;
  }

  transpileStructDeclaration(node) {
    // TODO: Need to adjust for JS's pass-by-reference behavior
    const name = node.name.value;
    const inheritedTypes = node.inheritedTypes.map(type => type.value).join(', ');
    const members = node.members.map(member => {
      if (member.type === PT.VAR_DECLARATION) {
        return this.transpileVarDeclaration(member, true);
      } 
      else if (member.type === PT.FUNCTION) {
        return this.transpileMethod(member);
      }
    }).join('\n  ');

    if (this.emitTS) {
      return `interface ${name}${inheritedTypes ? ` extends ${inheritedTypes}` : ''} {
  ${members}
}`;
    } else {
      return `class ${name} { // ${inheritedTypes ? `implements ${inheritedTypes}` : ''}
  constructor(params = {}) {
    Object.assign(this, params);
  }

  ${members}
}`;
    }
  }

  transpileClassDeclaration(node) {
    const name = node.name.value;
    const superclass = node.superclass ? ` extends ${node.superclass.value}` : '';
    const properties = node.properties.map(n => this.transpileVarDeclaration(n, true)).join('\n  ');
    const hasConstructor = node.methods.some(m => m.name === 'init');
    const defaultConstructor = hasConstructor ? '' : 'constructor(params = {}) { Object.assign(this, params); }';

    const methods = node.methods.map(this.transpileMethod.bind(this)).join('\n\n  ');

    return `class ${name}${superclass} {\n  ${properties}\n\n  ${defaultConstructor}\n\n${methods}\n}`;
  }

  transpileMethod(node) {
    const name = node.name === 'init' ? 'constructor' : node.name.value;
    const params = 'params = {}'
    const returnType = this.emitTS && node.returnType ? `: ${this.transpileType(node.returnType)}` : '';
    const body = this.transpileFunctionBody(node.body, node.parameters);
    const staticKeyword = node.isStatic ? 'static ' : '';
    
    // If it's a constructor, we need to add property declarations
    if (name === 'constructor') {
      const propertyDeclarations = node.parameters
        .filter(param => param.isProperty)
        .map(param => `this.${param.internalName.value} = ${param.internalName.value};`)
        .join('\n    ');
      
      return `${staticKeyword}${name}(${params})${returnType} { 
    ${propertyDeclarations}
    ${body} 
  }`;
    }
    
    return `${staticKeyword}${name}(${params})${returnType} { ${body} }`;
  }

  transpileExpressionStatement(node) {
    return `${this.transpileExpression(node.expression)};`;
  }

  transpileExpression(node) {
    switch (node.type) {
      case PT.ASSIGNMENT:
        return this.transpileAssignment(node);
      case PT.VARIABLE:
        return this.transpileVariable(node);
      case PT.LOGICAL:
        return this.transpileLogical(node);
      case PT.BINARY:
        return this.transpileBinary(node);
      case PT.UNARY:
        return this.transpileUnary(node);
      case PT.CALL:
        return this.transpileCall(node);
      case PT.OPTIONAL_CHAINING:
        return this.transpileOptionalChaining(node);
      case PT.GET:
        return this.transpileGet(node);
      case PT.INDEX:
        return this.transpileIndex(node);
      case PT.LITERAL:
        return this.transpileLiteral(node);
      case PT.NUMBER_LITERAL:
        return this.transpileNumberLiteral(node);
      case PT.ARRAY_LITERAL:
        return this.transpileArray(node);
      case PT.DICTIONARY_LITERAL:
        return this.transpileDictionary(node);
      case PT.GROUPING:
        return this.transpileGrouping(node);
      case PT.SELF:
        return this.transpileSelf(node);
      default:
        throw new Error(`Unsupported expression type: ${node.type}`);
    }
  }

  transpileAssignment(node) {
    const target = this.transpileExpression(node.target);
    const value = this.transpileExpression(node.value);
    return `${target} = ${value}`;
  }

  transpileVariable(node) {
    return node.name.value;
  }

  transpileLogical(node) {
    const left = this.transpileExpression(node.left);
    const right = this.transpileExpression(node.right);
    return `${left} ${node.operator.value} ${right}`;
  }

  transpileBinary(node) {
    const left = this.transpileExpression(node.left);
    const right = this.transpileExpression(node.right);
    return `${left} ${node.operator.value} ${right}`;
  }

  transpileUnary(node) {
    const operand = this.transpileExpression(node.operand);
    return `${node.operator.value}${operand}`;
  }

  transpileCall(node) {
    const callee = this.transpileExpression(node.callee);
    const args = node.arguments.map(arg => {
      if (arg.label) {
        // For named arguments, we'll use object property shorthand
        return `${arg.label.value}: ${this.transpileExpression(arg.value)}`;
      }
      return this.transpileExpression(arg.value);
    }).join(', ');
    
    // Wrap arguments in an object for named parameters
    const wrappedArgs = node.arguments.some(arg => arg.label) ? `{ ${args} }` : args;
    
    const isClass = callee.charAt(0) === callee.charAt(0).toUpperCase(); // TODO: We want to  do this during a semantic analysis pass; checking capitalization just for now
    return `${isClass ? 'new ' : ''}${callee}(${wrappedArgs})`;
  }

  transpileOptionalChaining(node) {
    const object = this.transpileExpression(node.object);
    const property = this.transpileExpression(node.name);
    return `${object}?.${property}`;
  }

  transpileGet(node) {
    const object = this.transpileExpression(node.object);
    const property = node.name.value;
    return `${object}.${property}`;
  }

  transpileIndex(node) {
    const object = this.transpileExpression(node.object);
    const index = this.transpileExpression(node.index);
    return `${object}[${index}]`;
  }

  transpileLiteral(node) {
    return JSON.stringify(node.value);
  }

  transpileNumberLiteral(node) {
    return node.value;
  }

  transpileArray(node) {
    const elements = node.elements.map(this.transpileExpression.bind(this)).join(', ');
    return `[${elements}]`;
  }

  transpileDictionary(node) {
    const pairs = node.pairs.map(({key, value}) => `${this.transpileExpression(key)}: ${this.transpileExpression(value)}`).join(', ');
    return `({ ${pairs} })`;
  }

  transpileGrouping(node) {
    const expression = this.transpileExpression(node.expression);
    return `(${expression})`;
  }

  transpileSelf() {
    return 'this';
  }

  transpileType(type) {
    switch (type.value) {
      case 'Int':
      case 'Double':
      case 'Float':
        return 'number';
      case 'String':
      case 'Character':
        return 'string';
      case 'Bool':
        return 'boolean';
      case 'Any':
        return 'any';
      case 'Void':
        return 'void';
      case 'Array':
        if (type.genericTypes && type.genericTypes.length > 0) {
          return `${this.transpileType(type.genericTypes[0])}[]`;
        }
        return 'any[]';
      case 'Dictionary':
        if (type.genericTypes && type.genericTypes.length > 1) {
          const keyType = this.transpileType(type.genericTypes[0]);
          const valueType = this.transpileType(type.genericTypes[1]);
          return `{ [key: ${keyType}]: ${valueType} }`;
        }
        return '{ [key: string]: any }';
      case 'Optional':
        if (type.genericTypes && type.genericTypes.length > 0) {
          return `${this.transpileType(type.genericTypes[0])} | null | undefined`;
        }
        return 'any | null | undefined';
      default:
        return type.value;
    }
  }

  transpileBlock(block) {
    const statements = block.statements.map(this.transpileNode.bind(this)).join('\n');
    return statements
  }

  transpileStatement(statement) {
    return this.transpileNode(statement);
  }
}

const runtime = `
function print(value) {
  console.log(value);
}

function range(start, end) {
  return Array.from({ length: end - start + 1 }, (_, i) => start + i);
}
`;

export default Transpiler;