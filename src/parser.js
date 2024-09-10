import { TT } from "./lexer.js";

class Parser {
  constructor(tokens) {
    this.tokens = tokens;
    this.current = 0;
  }

  parse() {
    const ast = [];
    while (!this.isAtEnd()) {
      ast.push(this.declaration());
    }
    return ast;
  }

  // MARK: - Declarations

  declaration() {
    try {
      if (this.match(TT.STRUCT)) return this.structDeclaration();
      if (this.match(TT.CLASS)) return this.classDeclaration();
      if (this.match(TT.VAR, TT.LET)) return this.varDeclaration();
      if (this.match(TT.FUNC)) return this.function('function');
      if (this.match(TT.ENUM)) return this.enumDeclaration();
      if (this.match(TT.PROTOCOL)) return this.protocolDeclaration();
      return this.statement();
    } catch (error) {
      this.synchronize();
      return null;
    }
  }

  structDeclaration() {
    const name = this.consume(TT.IDENTIFIER, 'Expect struct name.');
    
    let inheritedTypes = [];
    if (this.match(TT.COLON)) {
      do {
        inheritedTypes.push(this.consume(TT.IDENTIFIER, 'Expect inherited type name.'));
      } while (this.match(TT.COMMA));
    }

    this.consume(TT.LEFT_BRACE, "Expect '{' before struct body.");

    const members = [];

    while (!this.check(TT.RIGHT_BRACE) && !this.isAtEnd()) {
      if (this.check(TT.INIT)) {
        members.push(this.method('constructor'));
      } 
      else if (this.match(TT.FUNC)) {
        members.push(this.method('method'));
      } 
      else if (this.match(TT.VAR, TT.LET)) {
        members.push(this.varDeclaration());
      } 
      else {
        throw this.error(this.peek(), "Expect method or property declaration in struct.");
      }
    }

    this.consume(TT.RIGHT_BRACE, "Expect '}' after struct body.");

    return {
      type: PT.STRUCT_DECLARATION,
      name,
      inheritedTypes,
      members
    };
  }

  classDeclaration() {
    const name = this.consume(TT.IDENTIFIER, 'Expect class name.');
    
    let superclass = null;
    if (this.match(TT.COLON)) {
      superclass = this.consume(TT.IDENTIFIER, 'Expect superclass name.');
    }

    this.consume(TT.LEFT_BRACE, "Expect '{' before class body.");

    const methods = [];
    const properties = [];

    while (!this.check(TT.RIGHT_BRACE) && !this.isAtEnd()) {
      if (this.check(TT.INIT)) {
        methods.push(this.method('constructor'));
      } 
      else if (this.match(TT.FUNC)) {
        methods.push(this.method('method'));
      } 
      else if (this.match(TT.VAR, TT.LET)) {
        properties.push(this.varDeclaration());
      } 
      else {
        throw this.error(this.peek(), "Expect method or property declaration in class.");
      }
    }

    this.consume(TT.RIGHT_BRACE, "Expect '}' after class body.");

    return {
      type: PT.CLASS_DECLARATION,
      name,
      superclass,
      methods,
      properties
    };
  }

  method(kind) {
    const isStatic = this.match(TT.STATIC);
    const isOverride = this.match(TT.OVERRIDE);
    const name = this.match(TT.INIT) ? 'init' : this.consume(TT.IDENTIFIER, `Expect ${kind} name.`);

    this.consume(TT.LEFT_PAREN, `Expect '(' after ${kind} name.`);
    const parameters = [];
    if (!this.check(TT.RIGHT_PAREN)) {
      do {
        parameters.push(this.parameter());
      } while (this.match(TT.COMMA));
    }
    this.consume(TT.RIGHT_PAREN, "Expect ')' after parameters.");
    
    let returnType = null;
    if (this.match(TT.RIGHT_ARROW)) {
      returnType = this.type();
    }

    this.consume(TT.LEFT_BRACE, `Expect '{' before ${kind} body.`);
    const body = this.block();
    return { type: PT.FUNCTION, name, parameters, returnType, body, isStatic, isOverride };
  }

  varDeclaration() {
    const constant = this.previous().type === TT.LET;
    const name = this.consume(TT.IDENTIFIER, 'Expect variable name.');
    
    let type = null;
    if (this.match(TT.COLON)) {
      type = this.type();
    }
    
    let initializer = null;
    if (this.match(TT.EQUAL)) {
      initializer = this.expression();
    } 
    // TODO: This shouldn't error for let declarations in classes, unless if it isn't set in the initializer. Should do these checks in the semantic analyzer.
    // else if (constant) {
    //   throw this.error(this.previous(), "Constant declarations must be initialized.");
    // }

    this.match(TT.SEMICOLON);

    return {
      type: PT.VAR_DECLARATION,
      name,
      varType: type,
      initializer,
      constant,
      isOptional: (type && type.isOptional) || false
    };
  }

  function(kind) {
    const name = this.consume(TT.IDENTIFIER, `Expect ${kind} name.`);
    this.consume(TT.LEFT_PAREN, `Expect '(' after ${kind} name.`);
    const parameters = [];
    if (!this.check(TT.RIGHT_PAREN)) {
      do {
        parameters.push(this.parameter());
      } while (this.match(TT.COMMA));
    }
    this.consume(TT.RIGHT_PAREN, "Expect ')' after parameters.");
    
    let returnType = null;
    if (this.match(TT.RIGHT_ARROW)) {
      returnType = this.type();
    }

    this.consume(TT.LEFT_BRACE, `Expect '{' before ${kind} body.`);
    const body = this.block();
    return { type: PT.FUNCTION, name, parameters, returnType, body };
  }

  parameter() {
    let externalName = null;
    let internalName = null;
    let isVariadic = false;
    let defaultValue = null;

    if (this.check(TT.IDENTIFIER) && this.checkNext(TT.IDENTIFIER)) {
      externalName = this.previous();
      internalName = this.consume(TT.IDENTIFIER, 'Expect parameter internal name.');
    } else {
      internalName = this.consume(TT.IDENTIFIER, 'Expect parameter name.');
    }

    this.consume(TT.COLON, "Expect ':' after parameter name.");
    
    const type = this.type();
    
    // Check for variadic parameter
    if (this.match(TT.DOT, TT.DOT, TT.DOT)) {
      isVariadic = true;
    }

    // Check for default value
    if (this.match(TT.EQUAL)) {
      defaultValue = this.expression();
    }

    return { 
      type: PT.PARAMETER,
      externalName,
      internalName,
      parameterType: type,
      isVariadic,
      defaultValue
    };
  }

  type() {
    let type;

    if (this.match(TT.LEFT_BRACKET)) {
      if (this.checkNext(TT.COLON)) {
        const keyType = this.type();
        this.consume(TT.COLON, "Expect ':' after dictionary key type.");
        const valueType = this.type();
        this.consume(TT.RIGHT_BRACKET, "Expect ']' after dictionary value type.");
        type = { type: PT.DICTIONARY_TYPE, keyType, valueType };
      } 
      else {
        const elementType = this.type();
        this.consume(TT.RIGHT_BRACKET, "Expect ']' after array type.");
        type = { type: PT.ARRAY_TYPE, elementType };
      }
    }
    else {
      type = { type: PT.TYPE, name: this.consume(TT.IDENTIFIER, 'Expect type name.') };
    }

    if (this.match(TT.QUESTION)) {
      type = { type: PT.OPTIONAL_TYPE, baseType: type };
    }
    return type;
  }

  enumDeclaration() {
    const name = this.consume(TT.IDENTIFIER, 'Expect enum name.');
    this.consume(TT.LEFT_BRACE, "Expect '{' before enum cases.");

    const cases = [];
    while (!this.check(TT.RIGHT_BRACE) && !this.isAtEnd()) {
      this.consume(TT.CASE, "Expect 'case' before enum case name.");
      const caseName = this.consume(TT.IDENTIFIER, 'Expect case name.');
      
      let rawValue = null;
      let associatedValue = null;

      if (this.match(TT.EQUAL)) {
        rawValue = this.expression();
      } else if (this.match(TT.LEFT_PAREN)) {
        associatedValue = [];
        if (!this.check(TT.RIGHT_PAREN)) {
          do {
            const paramName = this.match(TT.IDENTIFIER) ? this.previous() : null;
            if (paramName) this.consume(TT.COLON, "Expect ':' after parameter name.");
            const paramType = this.type();
            associatedValue.push({ name: paramName, type: paramType });
          } while (this.match(TT.COMMA));
        }
        this.consume(TT.RIGHT_PAREN, "Expect ')' after associated value(s).");
      }

      cases.push({ name: caseName, rawValue, associatedValue });
      
      this.match(TT.COMMA); // allow trailing comma
    }

    this.consume(TT.RIGHT_BRACE, "Expect '}' after enum cases.");
    return { type: PT.ENUM_DECLARATION, name, cases };
  }

  protocolDeclaration() {
    const name = this.consume(TT.IDENTIFIER, 'Expect protocol name.');
    
    // Parse protocol inheritance if present
    let inheritedProtocols = [];
    if (this.match(TT.COLON)) {
      do {
        inheritedProtocols.push(this.consume(TT.IDENTIFIER, 'Expect inherited protocol name.'));
      } while (this.match(TT.COMMA));
    }

    this.consume(TT.LEFT_BRACE, "Expect '{' before protocol body.");

    const members = [];
    while (!this.check(TT.RIGHT_BRACE) && !this.isAtEnd()) {
      if (this.match(TT.VAR, TT.LET)) {
        members.push(this.protocolPropertyDeclaration());
      } 
      else if (this.match(TT.FUNC)) {
        members.push(this.protocolMethodDeclaration());
      } 
      else {
        throw this.error(this.peek(), "Expect property or method declaration in protocol.");
      }
    }

    this.consume(TT.RIGHT_BRACE, "Expect '}' after protocol body.");

    return {
      type: PT.PROTOCOL_DECLARATION,
      name,
      inheritedProtocols,
      members
    };
  }

  protocolPropertyDeclaration() {
    const isConstant = this.previous().type === TT.LET;
    const name = this.consume(TT.IDENTIFIER, 'Expect property name.');
    this.consume(TT.COLON, "Expect ':' after property name.");
    const propertyType = this.type();

    let getter = true;
    let setter = false;

    if (this.match(TT.LEFT_BRACE)) {
      getter = false;
      setter = false;
      if (this.match(TT.GET)) {
        getter = true;
        if (this.match(TT.SET)) setter = true;
      } 
      else if (this.match(TT.SET)) {
        setter = true;
        if (this.match(TT.GET)) getter = true;
      }
      this.consume(TT.RIGHT_BRACE, "Expect '}' after getter/setter specification.");
    }

    return {
      type: PT.PROTOCOL_PROPERTY,
      name,
      propertyType,
      isConstant,
      getter,
      setter
    };
  }

  protocolMethodDeclaration() {
    const name = this.consume(TT.IDENTIFIER, 'Expect method name.');
    this.consume(TT.LEFT_PAREN, "Expect '(' after method name.");
    const parameters = [];
    if (!this.check(TT.RIGHT_PAREN)) {
      do {
        parameters.push(this.parameter());
      } while (this.match(TT.COMMA));
    }
    this.consume(TT.RIGHT_PAREN, "Expect ')' after parameters.");
    
    let returnType = null;
    if (this.match(TT.RIGHT_ARROW)) {
      returnType = this.type();
    }

    return {
      type: PT.PROTOCOL_METHOD,
      name,
      parameters,
      returnType
    };
  }

  // MARK: - Statements

  statement() {
    if (this.match(TT.IF)) return this.ifStatement();
    if (this.match(TT.GUARD)) return this.guardStatement();
    if (this.match(TT.SWITCH)) return this.switchStatement();
    if (this.match(TT.RETURN)) return this.returnStatement();
    if (this.match(TT.WHILE)) return this.whileStatement();
    if (this.match(TT.FOR)) return this.forStatement();
    if (this.match(TT.LEFT_BRACE)) return this.block();
    return this.expressionStatement();
  }

  ifStatement() {
    if (this.match(TT.LET)) {
      return this.ifLetStatement();
    }

    const parens = this.match(TT.LEFT_PAREN);
    const condition = this.expression();
    if (parens) this.consume(TT.RIGHT_PAREN, "Expect ')' after if condition.");

    const thenBranch = this.statement();
    
    let elseBranch = null;
    if (this.match(TT.ELSE)) {
      elseBranch = this.statement();
    }

    return { type: PT.IF, condition, thenBranch, elseBranch };
  }
    
  ifLetStatement() {
    const name = this.consume(TT.IDENTIFIER, 'Expect variable name after if let.');
    let value;
    if (this.match(TT.EQUAL)) {
      value = this.expression();
    } else {
      value = { type: 'Variable', name: name };
    }
    
    this.consume(TT.LEFT_BRACE, "Expect '{' after if let condition.");
    const thenBranch = this.block();
    let elseBranch = null;
    if (this.match(TT.ELSE)) {
      elseBranch = this.statement(); // TODO: Are returns required here?
    }

    return { type: PT.IF_LET, name, value, thenBranch, elseBranch };
  }

  guardStatement() {
    if (this.match(TT.LET)) {
      return this.guardLetStatement();
    }

    const condition = this.expression();
    this.consume(TT.ELSE, "Expect 'else' after guard condition.");
    this.consume(TT.LEFT_BRACE, "Expect '{' after guard condition.");
    const body = this.block();
    return { type: PT.GUARD, condition, body };
  }

  guardLetStatement() {
    const name = this.consume(TT.IDENTIFIER, 'Expect variable name after guard let.');
    this.consume(TT.EQUAL, "Expect '=' after variable name in guard let.");
    const value = this.expression();
    this.consume(TT.ELSE, "Expect 'else' after guard let condition.");
    this.consume(TT.LEFT_BRACE, "Expect '{' after guard let condition.");
    const body = this.block(); // TODO: Require return in here
    return { type: PT.GUARD_LET, name, value, body };
  }

  switchStatement() {
    const expression = this.expression();
    this.consume(TT.LEFT_BRACE, "Expect '{' after switch expression.");

    const cases = [];
    let defaultCase = null;

    while (!this.check(TT.RIGHT_BRACE) && !this.isAtEnd()) {
      if (this.match(TT.CASE)) {
        const caseExpressions = [];
        do {
          caseExpressions.push(this.expression());
        } while (this.match(TT.COMMA));

        this.consume(TT.COLON, "Expect ':' after case value.");
        const statements = [];
        while (!this.check(TT.CASE) && !this.check(TT.DEFAULT) && !this.check(TT.RIGHT_BRACE)) {
          statements.push(this.statement());
        }
        cases.push({ expressions: caseExpressions, statements });
      } 
      else if (this.match(TT.DEFAULT)) {
        this.consume(TT.COLON, "Expect ':' after 'default'.");
        const statements = [];
        while (!this.check(TT.RIGHT_BRACE)) {
          statements.push(this.statement());
        }
        defaultCase = { default: true, statements };
      } 
      else {
        throw this.error(this.peek(), "Expect 'case' or 'default' in switch statement.");
      }
    }

    this.consume(TT.RIGHT_BRACE, "Expect '}' after switch cases.");

    return { type: PT.SWITCH, expression, cases, defaultCase };
  }

  returnStatement() {
    let value = null;
    if (!this.check('RIGHT_BRACE') && !this.check('SEMICOLON') && !this.isAtEnd()) {
      value = this.expression();
    }
    this.match(TT.SEMICOLON);
    return { type: PT.RETURN, value };
  }

  whileStatement() {
    const condition = this.expression();
    this.consume(TT.LEFT_BRACE, "Expect '{' after while condition.");
    const body = this.block();
    return { type: PT.WHILE, condition, body };
  }

  forStatement() {
    const paren = this.match(TT.LEFT_PAREN);

    const item = this.consume(TT.IDENTIFIER, "Expect item name in for-in loop.");
    this.consume(TT.IN, "Expect 'in' after loop item in for-in loop.");
    const iterable = this.expression();

    if (paren) this.consume(TT.RIGHT_PAREN, "Expect matching ')' after for-in loop.");

    this.consume(TT.LEFT_BRACE, "Expect '{' before for loop body.");
    const body = this.block();

    return { 
      type: PT.FOR, 
      item, 
      iterable, 
      body 
    };
  }

  block() {
    const statements = [];
    while (!this.check(TT.RIGHT_BRACE) && !this.isAtEnd()) {
      statements.push(this.declaration());
    }

    this.consume(TT.RIGHT_BRACE, "Expect '}' after block.");
    return { statements };
  }

  expressionStatement() {
    const expr = this.expression();
    this.match(TT.SEMICOLON);
    return { type: PT.EXPRESSION_STATEMENT, expression: expr };
  }

  // MARK: - Expressions

  expression() {
    return this.assignment();
  }

  assignment() {
    const expr = this.coalescing();

    if (this.match(TT.EQUAL)) {
      const equals = this.previous();
      const value = this.assignment();

      if (expr.type === PT.VARIABLE || expr.type === PT.INDEX || expr.type === PT.GET || expr.type === PT.OPTIONAL_CHAINING) {
        return { type: PT.ASSIGNMENT, target: expr, value };
      }

      this.error(equals, `Invalid assignment target (${expr.type}).`);
    }

    return expr;
  }

  coalescing() {
    let expr = this.or();

    while (this.match(TT.QUESTION_QUESTION)) {
      const operator = this.previous();
      const right = this.or(); 
      expr = { type: PT.BINARY, left: expr, operator, right };
    }

    return expr;
  }

  or() {
    let expr = this.and();

    while (this.match(TT.PIPE_PIPE)) {
      const operator = this.previous();
      const right = this.and(); 
      expr = { type: PT.LOGICAL, left: expr, operator, right };
    }

    return expr;
  }

  and() {
    let expr = this.equality();

    while (this.match(TT.AMPERSAND_AMPERSAND)) {
      const operator = this.previous();
      const right = this.equality();
      expr = { type: PT.LOGICAL, left: expr, operator, right };
    }

    return expr;
  }

  equality() {
    let expr = this.comparison();

    while (this.match(TT.BANG_EQUAL, TT.EQUAL_EQUAL)) {
      const operator = this.previous();
      const right = this.comparison();
      expr = { type: PT.BINARY, left: expr, operator, right };
    }

    return expr;
  }

  comparison() {
    let expr = this.range();

    while (this.match(TT.GREATER, TT.GREATER_EQUAL, TT.LESS, TT.LESS_EQUAL)) {
      const operator = this.previous();
      const right = this.range();
      expr = { type: PT.BINARY, left: expr, operator, right };
    }

    return expr;
  }

  range() {
    let expr = this.term();

    while (this.match(TT.CLOSED_RANGE, TT.HALF_OPEN_RANGE)) {
      const operator = this.previous();
      const right = this.term();
      expr = { type: PT.BINARY, left: expr, operator, right };
    }

    return expr;
  }

  term() {
    let expr = this.factor();

    while (this.match(TT.MINUS, TT.PLUS)) {
      const operator = this.previous();
      const right = this.factor();
      expr = { type: PT.BINARY, left: expr, operator, right };
    }

    return expr;
  }

  factor() {
    let expr = this.unary();

    while (this.match(TT.SLASH, TT.STAR)) {
      const operator = this.previous();
      const right = this.unary();
      expr = { type: PT.BINARY, left: expr, operator, right };
    }

    return expr;
  }

  unary() {
    if (this.match(TT.BANG, TT.MINUS)) {
      const operator = this.previous();
      const right = this.unary();
      return { type: PT.UNARY, operator, right };
    }

    return this.call();
  }

  call() {
    let expr = this.primary();

    while (true) {
      if (this.match(TT.LEFT_PAREN)) {
        expr = this.finishCall(expr);
      } 
      else if (this.match(TT.DOT)) {
        const name = this.consume(TT.IDENTIFIER, "Expect property name after '.'.");
        expr = { type: PT.GET, object: expr, name };
      }
      else if (this.match(TT.LEFT_BRACKET)) {
        const index = this.expression();
        this.consume(TT.RIGHT_BRACKET, "Expect ']' after index.");
        expr = { type: PT.INDEX, object: expr, index };
      } 
      else if (this.match(TT.QUESTION)) {
        // Handle optional chaining
        const object = expr;
        expr = { type: PT.OPTIONAL_CHAINING, object };

        // Check for method call or property access after optional chaining
        if (this.match(TT.LEFT_PAREN)) {
          expr = this.finishCall(expr, true);
        } 
        else if (this.match(TT.IDENTIFIER)) {
          const name = this.previous();
          expr = { type: PT.GET, object: expr, name, isOptional: true };
        } 
        else if (this.match(TT.LEFT_BRACKET)) {
          const index = this.expression();
          this.consume(TT.RIGHT_BRACKET, "Expect ']' after index.");
          expr = { type: PT.INDEX, object: expr, index, isOptional: true };
        } 
        else {
          throw this.error(this.peek(), "Expect property, subscript, or method call after '?'.");
        }
      } 
      else {
        break;
      }
    }

    return expr;
  }

  finishCall(callee, isOptional = false) {
    const args = [];
    if (!this.check(TT.RIGHT_PAREN)) {
      do {
        let label = null;
        if (this.check(TT.IDENTIFIER) && this.checkNext(TT.COLON)) {
          label = this.consume(TT.IDENTIFIER, "Expect argument label.");
          this.consume(TT.COLON, "Expect ':' after argument label.");
        }
        const value = this.expression();
        args.push({ label, value });
      } while (this.match(TT.COMMA));
    }
    this.consume(TT.RIGHT_PAREN, "Expect ')' after arguments.");

    return { type: PT.CALL, callee, arguments: args, isOptional };
  }

  primary() {
    if (this.match(TT.FALSE)) return { type: PT.LITERAL, value: false };
    if (this.match(TT.TRUE)) return { type: PT.LITERAL, value: true };
    if (this.match(TT.NIL)) return { type: PT.LITERAL, value: null };
    if (this.match(TT.SELF)) return { type: PT.SELF };

    if (this.match(TT.STRING)) {
      return { type: PT.LITERAL, value: this.previous().value };
    }

    if (this.match(TT.NUMBER)) {
      return { type: PT.NUMBER_LITERAL, value: this.previous().value };
    }

    if (this.match(TT.IDENTIFIER)) {
      return { type: PT.VARIABLE, name: this.previous() };
    }

    if (this.match(TT.LEFT_PAREN)) {
      const expr = this.expression();
      this.consume(TT.RIGHT_PAREN, "Expect ')' after expression.");
      return { type: PT.GROUPING, expression: expr };
    }

    if (this.match(TT.LEFT_BRACKET)) {
      return this.arrayOrDictionaryLiteral();
    }

    throw this.error(this.peek(), 'Expect expression.');
  }

  arrayOrDictionaryLiteral() {
    if (this.match(TT.COLON)) {
      this.consume(TT.RIGHT_BRACKET, "Expect ']' after empty dictionary literal.");
      return { type: PT.DICTIONARY_LITERAL, pairs: [] };
    }

    if (this.match(TT.RIGHT_BRACKET)) {
      return { type: PT.ARRAY_LITERAL, elements: [] };
    }

    const firstElement = this.expression();

    if (this.match(TT.COLON)) {
      return this.finishDictionaryLiteral(firstElement);
    } else {
      return this.finishArrayLiteral(firstElement);
    }
  }

  finishArrayLiteral(firstElement) {
    const elements = [firstElement];
    while (this.match(TT.COMMA)) {
      if (this.check(TT.RIGHT_BRACKET)) {
        break;
      }
      elements.push(this.expression());
    }
    this.consume(TT.RIGHT_BRACKET, "Expect ']' after array elements.");
    return { type: PT.ARRAY_LITERAL, elements };
  }

  finishDictionaryLiteral(firstKey) {
    const pairs = [];
    const firstValue = this.expression();
    pairs.push({ key: firstKey, value: firstValue });

    while (this.match(TT.COMMA)) {
      if (this.check(TT.RIGHT_BRACKET)) {
        break;
      }
      const key = this.expression();
      this.consume(TT.COLON, "Expect ':' after dictionary key.");
      const value = this.expression();
      pairs.push({ key, value });
    }
    this.consume(TT.RIGHT_BRACKET, "Expect ']' after dictionary pairs.");
    return { type: PT.DICTIONARY_LITERAL, pairs };
  }

  // MARK: - Helpers

  match(...types) {
    for (const type of types) {
      if (this.check(type)) {
        this.advance();
        return true;
      }
    }
    return false;
  }

  consume(type, message) {
    if (this.check(type)) return this.advance();
    console.trace();
    throw this.error(this.peek(), message);
  }

  check(type) {
    if (this.isAtEnd()) return false;
    return this.peek().type === type;
  }

  checkNext(type) {
    if (this.isAtEnd()) return false;
    if (this.current + 1 >= this.tokens.length) return false;
    return this.tokens[this.current + 1].type === type;
  }

  advance() {
    if (!this.isAtEnd()) this.current++;
    return this.previous();
  }

  isAtEnd() {
    return this.peek().type === TT.EOF;
  }

  peek() {
    return this.tokens[this.current];
  }

  previous() {
    return this.tokens[this.current - 1];
  }

  error(token, message) {
    console.error(`Error at '${token.value}', line ${token.line}, column ${token.column}: ${message}`);
    return new Error(message);
  }
  
  synchronize() {
    this.advance();

    while (!this.isAtEnd()) {
      if (this.previous().type === TT.SEMICOLON) return;

      switch (this.peek().type) {
        case TT.FUNC:
        case TT.VAR:
        case TT.LET:
        case TT.FOR:
        case TT.IF:
        case TT.WHILE:
        case TT.RETURN:
        case TT.STRUCT:
        case TT.ENUM:
        case TT.PROTOCOL:
        case TT.EXTENSION:
        case TT.GUARD:
        case TT.SWITCH:
          return;
      }

      this.advance();
    }
  }
}

const ParserTypes = Object.freeze({
  VAR_DECLARATION: 'VarDeclaration',
  TYPE: 'Type',
  OPTIONAL_TYPE: 'OptionalType',
  ARRAY_TYPE: 'ArrayType',
  DICTIONARY_TYPE: 'DictionaryType',
  FUNCTION: 'Function',
  PARAMETER: 'Parameter',
  ENUM_DECLARATION: 'EnumDeclaration',
  PROTOCOL_DECLARATION: 'ProtocolDeclaration',
  PROTOCOL_PROPERTY: 'ProtocolProperty',
  PROTOCOL_METHOD: 'ProtocolMethod',
  IF: 'If',
  IF_LET: 'IfLet',
  GUARD: 'Guard',
  GUARD_LET: 'GuardLet',
  SWITCH: 'Switch',
  WHILE: 'While',
  FOR: 'For',
  RETURN: 'Return',
  EXPRESSION_STATEMENT: 'ExpressionStatement',
  ASSIGNMENT: 'Assignment',
  VARIABLE: 'Variable',
  LOGICAL: 'Logical',
  BINARY: 'Binary',
  UNARY: 'Unary',
  CALL: 'Call',
  OPTIONAL_CHAINING: 'OptionalChaining',
  GET: 'Get',
  INDEX: 'Index',
  LITERAL: 'Literal',
  NUMBER_LITERAL: 'NumberLiteral',
  ARRAY_LITERAL: 'ArrayLiteral',
  DICTIONARY_LITERAL: 'DictionaryLiteral',
  GROUPING: 'Grouping',
  CLASS_DECLARATION: 'ClassDeclaration',
  SELF: 'Self',
  STRUCT_DECLARATION: 'StructDeclaration',
});

const PT = ParserTypes;

export default Parser;
export { ParserTypes, PT };