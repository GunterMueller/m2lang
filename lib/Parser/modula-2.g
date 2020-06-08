/*
 * ISO/IEC 10514-1 Modula-2 grammar.
 * Includes ISO/IEC 10514-2 (generics) and 10514-3 (OO layer).
 * See https://www.arjay.bc.ca/Modula-2/Text/Appendices/Ap3.html
 *
 * The following expressions are used in predicates:
 * - getLangOpts().ISOGenerics is true iff language level is ISO/IEC 10514-2
 * - getLangOpts().ISOObjects is true iff language level is ISO/IEC 10514-3
 *
 * Assumption is that the lexer classifies identifiers as keywords according
 * to the supported language. E.g. "GENERIC" is only a keyword if the language
 * level is ISO/IEC 10514-2 and otherwise it's an identifier.
 *
 * The following changes were made:
 * - For symbols with alternative representations, it is expected that the lexer
 *   only returns the main representation. This is the list of tokens:
 *   AND: "&"
 *   NOT: "~"
 *   "#": "<>"
 *   "[": "(!"
 *   "]": "!)"
 *   "{": "(:"
 *   "}": ":)"
 *   "|": "!"
 *
 * Resolved LL(1) conflicts:
 * - Various changes to compilationModule:
 *   - Moved "UNSAFEGUARDED" and "GENERIC" into this rule.
 *   - Passes flag if "UNSAFEGUARDED" has bin parsed.
 * - Integrate refiningDefinitionModule into definitionModule.
 * - Integrate refiningImplementationModule into implementationModule.
 * - Integrate refiningLocalModuleDeclaration into localModuleDeclaration.
 * - Between properProcedureType and functionProcedureType.
 *   Integrated into procedureType using a predicate.
 * - Moved "TRACED" from normalTracedClassDeclaration and
 *   abstractTracedClassDeclaration into tracedClassDeclaration.
 * - Moved singleReturnStatement and functionReturnStatement into rule
 *   returnStatement.
 *
 * To enable predicates:
 * - Moved symbol definition into single parent rule definitions.
 * - Moved symbol declaration into single parent rule declarations.
 */
%language "c++"
%define api.parser.class {M2Parser}
%token identifier, integer_literal, char_literal, real_literal, string_literal
%start compilationModule
%eoi eof
%%
compilationModule<CompilationModule *&CM>
  : "UNSAFEGUARDED"
      ( programModule<CM, true>
      | definitionModule<CM, true>
      | implementationModule<CM, true>
      )
    | "GENERIC"
      ( genericDefinitionModule<CM>
      | genericImplementationModule<CM>
      )
    | programModule<CM, false>
    | definitionModule<CM, false>
    | implementationModule<CM, false>
  ;
programModule<CompilationModule *&CM, bool HasUnsafeGuarded>
  : "MODULE"
    identifier                { ProgramModule *PM = Actions.actOnProgramModule(tokenAs<Identifier>(Tok)); }
                              { EnterDeclScope S(Actions, PM); }
                              { DeclarationList Decls; Block InitBlk, FinalBlk; }
                              { Expression *ProtectionExpr = nullptr; }
    ( protection<ProtectionExpr> )? ";"
    importLists
    moduleBlock<Decls, InitBlk, FinalBlk>
    identifier                { Actions.actOnProgramModule(PM, tokenAs<Identifier>(Tok), Decls, InitBlk, FinalBlk); }
    "."                       { CM = PM; }
  ;
moduleIdentifier :
   identifier ;
protection<Expression *&Expr> :
   "[" expression<Expr> "]" ;
definitionModule<CompilationModule *&CM, bool HasUnsafeGuarded> :
  "DEFINITION" "MODULE" moduleIdentifier
  ( %if {.!HasUnsafeGuarded && getLangOpts().ISOGenerics.} /* refiningDefinitionModule*/
    "=" genericSeparateModuleIdentifier (actualModuleParameters)? ";"
  |                           { DeclarationList Decls; }
    importLists definitions<Decls> /* definitionModule*/
  )
  "END" moduleIdentifier "." ;
implementationModule<CompilationModule *&CM, bool HasUnsafeGuarded>
 :                            { DeclarationList Decls; Block InitBlk, FinalBlk; }
                              { Expression *ProtectionExpr = nullptr; }
  "IMPLEMENTATION" "MODULE" moduleIdentifier
  ( %if {.!HasUnsafeGuarded && getLangOpts().ISOGenerics.} /* refiningImplementationModule */
    "=" genericSeparateModuleIdentifier (actualModuleParameters)? ";" "END"
  | (protection<ProtectionExpr>)? ";" importLists moduleBlock<Decls, InitBlk, FinalBlk> /* implementationModule */
  )
  moduleIdentifier "." ;
importLists :
   ( importList )* ;
importList :
   simpleImport | unqualifiedImport ;
simpleImport :
   "IMPORT" identifierList ";" ;
unqualifiedImport :
   "FROM" moduleIdentifier "IMPORT" identifierList ";" ;
exportList :
   "EXPORT" ("QUALIFIED")? identifierList ";" ;
qualifiedIdentifier
  : (%if{Actions.isModule(Tok.getIdentifier())} moduleIdentifier ".")*
    (%if{getLangOpts().ISOObjects && Actions.isClass(Tok.getIdentifier())} classIdentifier)?
    identifier
  ;
/* Generics start */
genericDefinitionModule<CompilationModule *&CM>
  :                           {DeclarationList Decls;}
   /*"GENERIC"*/ "DEFINITION" "MODULE" moduleIdentifier (formalModuleParameters)?
   ";" importLists definitions<Decls> "END" moduleIdentifier "." ;
genericImplementationModule<CompilationModule *&CM>
  :                           { DeclarationList Decls; Block InitBlk, FinalBlk; }
                              { Expression *ProtectionExpr = nullptr; }
   /*"GENERIC"*/ "IMPLEMENTATION" "MODULE" moduleIdentifier (protection<ProtectionExpr>)?
   (formalModuleParameters)? ";" importLists moduleBlock<Decls, InitBlk, FinalBlk>
    moduleIdentifier "." ;
genericSeparateModuleIdentifier : identifier;
formalModuleParameters :
   "(" formalModuleParameterList ")" ;
formalModuleParameterList :
   formalModuleParameter (";" formalModuleParameter)*;
formalModuleParameter :
   constantValueParameterSpecification | typeParameterSpecification ;
constantValueParameterSpecification :
   identifierList ":" formalType ;
typeParameterSpecification :
   identifierList ":" "TYPE" ;
actualModuleParameters :
   "(" actualModuleParameterList ")" ;
actualModuleParameterList :
  actualModuleParameter ("," actualModuleParameter )* ;
actualModuleParameter :
  constantExpression | typeParameter ;
/* Generics end */
definitions<DeclarationList &Decls>
  : ( "CONST" (constantDeclaration<Decls> ";")*
    | "TYPE" (typeDefinition<Decls> ";")*
    | "VAR" (variableDeclaration<Decls> ";")*
    | procedureHeading ";"
    | %if {.getLangOpts().ISOObjects.} classDefinition ";"
    )*
  ;
procedureHeading :
   "PROCEDURE" procedureIdentifier (formalParameters ( ":" functionResultType )? )? ;
typeDefinition<DeclarationList &Decls>
  : typeDeclaration<Decls> | opaqueTypeDefinition ;
opaqueTypeDefinition :
   identifier ;
formalParameters :
   "(" (formalParameterList)? ")" ;
formalParameterList :
   formalParameter (";" formalParameter)* ;
functionResultType :
   typeIdentifier ;
formalParameter :
   valueParameterSpecification | variableParameterSpecification ;
valueParameterSpecification :
   identifierList ":" formalType ;
variableParameterSpecification :
   "VAR" identifierList ":" formalType ;
declarations<DeclarationList &Decls>
  : ( "CONST" (constantDeclaration<Decls> ";")*
    | "TYPE" (typeDeclaration<Decls> ";")*
    | "VAR" (variableDeclaration<Decls> ";")*
    | procedureDeclaration ";"
    | %if {.getLangOpts().ISOObjects.} classDeclaration ";"
    | localModuleDeclaration ";"
    )*
  ;
constantDeclaration<DeclarationList &Decls>
  :                           { SMLoc Loc; StringRef Name; }
    identifier                { Loc = Tok.getLocation(); Name = Tok.getIdentifier(); }
    "="                       { Expression *E = nullptr; }
    expression<E>             { Actions.actOnConstant(Decls, Loc, Name, E); }
  ;
typeDeclaration<DeclarationList &Decls>
  :                           {. SMLoc Loc; StringRef Name; .}
    identifier                { Identifier TypeName = tokenAs<Identifier>(Tok); }
    "=" typeDenoter           { Actions.actOnType(Decls, TypeName); }
  ;
variableDeclaration<DeclarationList &Decls>
  : variableIdentifierList ":" typeDenoter ;
variableIdentifierList
  : identifier ( machineAddress)? ("," identifier (machineAddress)? )* ;
machineAddress
  : "[" valueOfAddressType "]" ;
valueOfAddressType
  : constantExpression ;
procedureDeclaration
  : "PROCEDURE" identifier    { Procedure *P = Actions.actOnProcedure(tokenAs<Identifier>(Tok)); }
                              { EnterDeclScope S(Actions, P); }
                              {. bool IsFunction = false; .}
    ( "(" (formalParameterList)? ")" (":"{.IsFunction=true;.} functionResultType )? )?
      ";"
      (properProcedureBlock<IsFunction> identifier
                              { Actions.actOnProcedure(P, tokenAs<Identifier>(Tok)); }
    | "FORWARD"               { Actions.actOnForwardProcedure(P); }
    )
  ;
procedureIdentifier :
   identifier ;
localModuleDeclaration
  : "MODULE" identifier       { LocalModule *LM = Actions.actOnLocalModule(tokenAs<Identifier>(Tok)); }
                              { EnterDeclScope S(Actions, LM); }
                              { DeclarationList Decls; Block InitBlk, FinalBlk; }
                              { Expression *ProtectionExpr = nullptr; }
    ( %if {.getLangOpts().ISOGenerics.} /* refiningLocalModuleDeclaration*/
      "=" genericSeparateModuleIdentifier (actualModuleParameters)? ";"
      (exportList)? "END"
    | ( protection<ProtectionExpr> )? ";" importLists (exportList)? moduleBlock<Decls, InitBlk, FinalBlk>
    )
    moduleIdentifier
  ;
typeDenoter :
   typeIdentifier | newType ;
ordinalTypeDenoter :
   ordinalTypeIdentifier | newOrdinalType ;
typeIdentifier :
   qualifiedIdentifier ;
ordinalTypeIdentifier :
   typeIdentifier ;
newType :
   newOrdinalType | setType | packedsetType | pointerType |
   procedureType | arrayType | recordType ;
newOrdinalType :
   enumerationType | subrangeType ;
enumerationType :
   "(" identifierList ")" ;
identifierList :
   identifier ("," identifier)* ;
subrangeType :
   (rangeType)? "[" constantExpression ".."
   constantExpression "]" ;
rangeType :
   ordinalTypeIdentifier ;
setType :
   "SET" "OF" baseType ;
baseType :
   ordinalTypeDenoter ;
packedsetType :
   "PACKEDSET" "OF" baseType ;
pointerType :
   "POINTER" "TO" boundType ;
boundType :
   typeDenoter ;
procedureType
  : "PROCEDURE" ( "(" ( formalParameterTypeList )? ")" ( ":" functionResultType )? )? ;
formalParameterTypeList :
   formalParameterType ("," formalParameterType)* ;
formalParameterType :
   variableFormalType | valueFormalType ;
variableFormalType :
   "VAR" formalType ;
valueFormalType :
   formalType ;
formalType :
   typeIdentifier | openArrayFormalType ;
openArrayFormalType :
   "ARRAY" "OF" ("ARRAY" "OF")* typeIdentifier ;
arrayType :
   "ARRAY" indexType ("," indexType)* "OF" componentType ;
indexType :
   ordinalTypeDenoter ;
componentType :
   typeDenoter ;
recordType :
   "RECORD" fieldList "END" ;
fieldList :
   fields (";" fields)* ;
fields :
   (fixedFields | variantFields)? ;
fixedFields :
   identifierList ":" fieldType ;
fieldType :
   typeDenoter ;
variantFields :
   "CASE" (tagIdentifier)? ":" tagType "OF"
   variantList "END" ;
tagIdentifier :
   identifier ;
tagType :
   ordinalTypeIdentifier ;
variantList :
   variant ("|" variant)* (variantElsePart)? ;
variantElsePart :
   "ELSE" fieldList ;
variant :
   (variantLabelList ":" fieldList)? ;
variantLabelList :
   variantLabel ("," variantLabel)* ;
variantLabel :
   constantExpression (".." constantExpression)? ;
properProcedureBlock<bool IsFunction>
  :                           { Block Body; DeclarationList Decls; }
    declarations<Decls>
    ( "BEGIN" blockBody<Body>
    | %if {.IsFunction.} /* A function must have a body! */
    )
    "END"
  ;
moduleBlock<DeclarationList &Decls, Block &InitBlk, Block &FinalBlk>
  : declarations<Decls> ( moduleBody<InitBlk, FinalBlk> )? "END" ;
moduleBody<Block &InitBlk, Block &FinalBlk> :
   initializationBody<InitBlk> ( finalizationBody<FinalBlk> )? ;
initializationBody<Block &InitBlk>
  : "BEGIN" blockBody<InitBlk> ;
finalizationBody<Block &FinalBlk>
  : "FINALLY" blockBody<FinalBlk> ;
blockBody<Block &Blk>
  :                           { StatementList Stmts, ExceptStmts; }
   normalPart<Stmts>
   ( "EXCEPT" exceptionalPart<Stmts> )?
                              { Blk = Block(Stmts, ExceptStmts); }
   ;
normalPart<StatementList &Stmts>
  : statementSequence<Stmts> ;
exceptionalPart<StatementList &Stmts>
  : statementSequence<Stmts> ;
statement<Statement *&S>
  : ( assignmentStatement<S>
    | procedureCall<S>
    | returnStatement<S>
    | retryStatement<S>
    | withStatement<S>
    | ifStatement<S>
    | caseStatement<S>
    | whileStatement<S>
    | repeatStatement<S>
    | loopStatement<S>
    | exitStatement<S>
    | forStatement<S>
    | %if {.getLangOpts().ISOObjects.} guardStatement<S>
    )?
  ;
statementSequence<StatementList &Stmts>
  :                           {. Statement *S = nullptr; .}
   statement<S>               {. if (S) Stmts.push_back(S); .}
   ( ";"                      {. S = nullptr; .}
     statement<S>             {. if (S) Stmts.push_back(S); .}
   )*
  ;
assignmentStatement<Statement *&S>
  :                           {. Expression *E = nullptr; .}
   variableDesignator ":=" expression<E> ;
procedureCall<Statement *&S> :
   procedureDesignator (actualParameters)? ;
procedureDesignator :
   valueDesignator ;
returnStatement<Statement *&S>
  :                           {. Expression *E = nullptr; .}
    "RETURN" ( expression<E> )?
                              {. S = Actions.actOnReturnStmt(E); .}
  ;
retryStatement<Statement *&S>
  : "RETRY"                   {. SMLoc Loc = Tok.getLocation();
                                 S = Actions.actOnRetryStmt(Loc); .}
  ;
withStatement<Statement *&S>
  :                           {. StatementList Stmts; .}
   "WITH" recordDesignator "DO" statementSequence<Stmts> "END" ;
recordDesignator :
   variableDesignator | valueDesignator ;
ifStatement<Statement *&S> :
   guardedStatements (ifElsePart)? "END" ;
guardedStatements
  :                           {. StatementList Stmts; /* ERROR */ .}
   "IF" booleanExpression "THEN" statementSequence<Stmts>
   ("ELSIF" booleanExpression "THEN" statementSequence<Stmts>)* ;
ifElsePart
  :                           {. StatementList Stmts; /* ERROR */ .}
   "ELSE" statementSequence<Stmts> ;
booleanExpression
  :                           {. Expression *E = nullptr; .}
   expression<E> ;
caseStatement<Statement *&S> :
   "CASE" caseSelector "OF" caseList "END" ;
caseSelector :
   ordinalExpression ;
caseList :
   caseAlternative ("|" caseAlternative)*
   (caseElsePart)? ;
caseElsePart
  :                           {. StatementList Stmts; /* ERROR */ .}
   "ELSE" statementSequence<Stmts> ;
caseAlternative
  :                           {. StatementList Stmts; /* ERROR */ .}
   (caseLabelList ":" statementSequence<Stmts>)? ;
caseLabelList :
   caseLabel ("," caseLabel)* ;
caseLabel :
   constantExpression (".." constantExpression)? ;
whileStatement<Statement *&S>
  : "WHILE"                   {. SMLoc Loc = Tok.getLocation();
                                 Expression *Cond = nullptr; .}
    expression<Cond> "DO"     {. StatementList Stmts; .}
    statementSequence<Stmts>
    "END"                     {. S = Actions.actOnWhileStmt(Cond, Stmts, Loc); .}
  ;
repeatStatement<Statement *&S>
  : "REPEAT"                  {. SMLoc Loc = Tok.getLocation();
                                 StatementList Stmts; .}
    statementSequence<Stmts>
    "UNTIL"                   {. Expression *Cond = nullptr; .}
    expression<Cond>          {. S = Actions.actOnRepeatStmt(Cond, Stmts, Loc); .}
  ;
loopStatement<Statement *&S>
  : "LOOP"                    {. SMLoc Loc = Tok.getLocation();
                                 StatementList Stmts; .}
    statementSequence<Stmts>
    "END"                     {. S = Actions.actOnLoopStmt(Stmts, Loc); .}
  ;
exitStatement<Statement *&S>
  : "EXIT"                    {. SMLoc Loc = Tok.getLocation();
                                 S = Actions.actOnExitStmt(Loc); .}
  ;
forStatement<Statement *&S>
  :                           {. StatementList Stmts; /* ERROR */ .}
   "FOR" controlVariableIdentifier ":="
   initialValue "TO" finalValue ("BY" stepSize)? "DO"
   statementSequence<Stmts> "END" ;
controlVariableIdentifier :
   identifier ;
initialValue :
   ordinalExpression ;
finalValue :
   ordinalExpression ;
stepSize :
   constantExpression ;
variableDesignator :
   entireDesignator | indexedDesignator |
   selectedDesignator | dereferencedDesignator |
   %if {.getLangOpts().ISOObjects.} objectSelectedDesignator  ;
entireDesignator :
   qualifiedIdentifier ;
indexedDesignator :
   arrayVariableDesignator "[" indexExpression
   ("," indexExpression)* "]" ;
arrayVariableDesignator :
   variableDesignator ;
indexExpression :
   ordinalExpression ;
selectedDesignator :
   recordVariableDesignator "." fieldIdentifier ;
recordVariableDesignator :
   variableDesignator ;
fieldIdentifier :
   identifier ;
dereferencedDesignator :
   pointerVariableDesignator "^" ;
pointerVariableDesignator :
   variableDesignator ;
expression<Expression *&E>
  :
    simpleExpression<E>
    (                         {. OperatorInfo Op; .}
      relationalOperator<Op>
                              {. Expression *Right = nullptr; .}
      simpleExpression<Right> {. E = Actions.actOnExpression(E, Right, Op); .}
    )?
  ;
/* simpleExpression is changed according to B. Kowarsch.
 * Then negation is mathematically correct.
 */
simpleExpression<Expression *&E>
  :
    ( (                       {. OperatorInfo Op; .}
        ("+"                  {. Op = tokenAs<OperatorInfo>(Tok); .}
        )?
        term<E>               {. if (Op.getKind() != tok::unknown)
                                   E = Actions.actOnFactor(E, Op); .}
      )
      (                       {. OperatorInfo Op; .}
        termOperator<Op>
                              {. Expression *Right = nullptr; .}
        term<Right>           {. E = Actions.actOnSimpleExpression(E, Right, Op); .}
      )*
    )
  | "-"                       {. OperatorInfo Op(tokenAs<OperatorInfo>(Tok)); .}
    factor<E>                 {. E = Actions.actOnFactor(E, Op); .}
  ;
term<Expression *&E>
  : factor<E>
    (                         {. OperatorInfo Op; .}
      factorOperator<Op>
                              {. Expression *Right = nullptr; .}
      factor<Right>           {. E = Actions.actOnTerm(E, Right, Op); .}
    )*
  ;
factor<Expression *&E>
  : "(" expression<E> ")"
  | "NOT"                     {. OperatorInfo Op(tokenAs<OperatorInfo>(Tok)); .}
    factor<E>                 {. E = Actions.actOnFactor(E, Op); .}
  | valueDesignator | functionCall
  | valueConstructor | constantLiteral
  ;
ordinalExpression
  :                           {. Expression *E = nullptr; .}
    expression<E> ;
relationalOperator<OperatorInfo &Op>
  : "="                       { Op = tokenAs<OperatorInfo>(Tok); }
  | "#"                       { Op = tokenAs<OperatorInfo>(Tok); }
  | "<"                       { Op = tokenAs<OperatorInfo>(Tok); }
  | ">"                       { Op = tokenAs<OperatorInfo>(Tok); }
  | "<="                      { Op = tokenAs<OperatorInfo>(Tok); }
  | ">="                      { Op = tokenAs<OperatorInfo>(Tok); }
  | "IN"                      { Op = tokenAs<OperatorInfo>(Tok); }
  ;
termOperator<OperatorInfo &Op>
  : "+"                       { Op = tokenAs<OperatorInfo>(Tok); }
  | "-"                       { Op = tokenAs<OperatorInfo>(Tok); }
  | "OR"                      { Op = tokenAs<OperatorInfo>(Tok); }
  ;
factorOperator<OperatorInfo &Op>
  : "*"                       { Op = tokenAs<OperatorInfo>(Tok); }
  | "/"                       { Op = tokenAs<OperatorInfo>(Tok); }
  | "REM"                     { Op = tokenAs<OperatorInfo>(Tok); }
  | "DIV"                     { Op = tokenAs<OperatorInfo>(Tok); }
  | "MOD"                     { Op = tokenAs<OperatorInfo>(Tok); }
  | "AND"                     { Op = tokenAs<OperatorInfo>(Tok); }
  ;
valueDesignator :
  entireValue | indexedValue | selectedValue | dereferencedValue |
  %if {.getLangOpts().ISOObjects.} objectSelectedValue ;
entireValue :
   qualifiedIdentifier ;
indexedValue :
   arrayValue "[" indexExpression
   ("," indexExpression)* "]" ;
arrayValue :
   valueDesignator ;
selectedValue :
   recordValue "." fieldIdentifier ;
recordValue :
   valueDesignator ;
dereferencedValue :
   pointerValue "^" ;
pointerValue :
   valueDesignator ;
functionCall :
   functionDesignator actualParameters ;
functionDesignator :
   valueDesignator ;
valueConstructor :
   arrayConstructor | recordConstructor | setConstructor ;
arrayConstructor :
   arrayTypeIdentifier arrayConstructedValue ;
arrayTypeIdentifier :
   typeIdentifier ;
arrayConstructedValue :
   "{" repeatedStructureComponent
   ("," repeatedStructureComponent)* "}" ;
repeatedStructureComponent :
   structureComponent ("BY" repetitionFactor)? ;
repetitionFactor :
   constantExpression ;
structureComponent
  :                           {. Expression *E = nullptr; .}
   expression<E> | arrayConstructedValue |
   recordConstructedValue | setConstructedValue ;
recordConstructor :
   recordTypeIdentifier recordConstructedValue ;
recordTypeIdentifier :
   typeIdentifier ;
recordConstructedValue :
   "{" (structureComponent ("," structureComponent)* )?
   "}" ;
setConstructor :
   setTypeIdentifier setConstructedValue ;
setTypeIdentifier :
   typeIdentifier ;
setConstructedValue :
   "{" (member ("," member)* )? "}" ;
member :
   interval | singleton ;
interval :
   ordinalExpression ".." ordinalExpression ;
singleton :
   ordinalExpression ;
constantLiteral :
   integer_literal | real_literal | stringLiteral;
stringLiteral :
   string_literal | char_literal;
constantExpression
  :                           {. Expression *E = nullptr; .}
    expression<E> ;
actualParameters :
   "(" (actualParameterList)? ")" ;
actualParameterList :
   actualParameter ("," actualParameter)* ;
actualParameter
  :                           {. Expression *E = nullptr; .}
    (variableDesignator | expression<E> | typeParameter) ;
typeParameter :
   typeIdentifier ;

/* Begin OO */
classDefinition :
   ( tracedClassDefinition | untracedClassDefinition );
untracedClassDefinition :
   ( normalClassDefinition | abstractClassDefinition ) ;
tracedClassDefinition :
   "TRACED" ( normalClassDefinition | abstractClassDefinition ) ;
normalClassDefinition :
   normalClassHeader ( normalClassDefinitionBody | "FORWARD" ) ;
normalClassHeader :
   "CLASS" classIdentifier ";" ;
normalClassDefinitionBody :
   ( inheritClause )? ( revealList )? normalClassComponentDefinitions
   "END" classIdentifier ;
abstractClassDefinition :
   abstractClassHeader ( abstractClassDefinitionBody | "FORWARD" ) ;
abstractClassHeader :
   "ABSTRACT" "CLASS" classIdentifier ";" ;
abstractClassDefinitionBody :
   ( inheritClause )? ( revealList )? abstractClassComponentDefinitions
   "END" classIdentifier ;
classIdentifier :
   identifier ;
normalClassComponentDefinitions :
  ( normalComponentDefinition )* ;
normalComponentDefinition
  :                           {. DeclarationList Decls; .}
    (
   "CONST" ( constantDeclaration<Decls> ";" )* |
   "TYPE" ( typeDefinition<Decls> ";" )* |
   "VAR" ( classVariableDeclaration ";" )? |
   (normalMethodDefinition | overridingMethodDefinition) ";"
    );
abstractClassComponentDefinitions :
   ( abstractComponentDefinition )* ;
abstractComponentDefinition
  :                           {. DeclarationList Decls; .}
    (
   "CONST" ( constantDeclaration<Decls> ";" )* |
   "TYPE" ( typeDefinition<Decls> ";" )* |
   "VAR" ( classVariableDeclaration ";" )* |
  (normalMethodDefinition | abstractMethodDefinition |
   overridingMethodDefinition) ";"
   );
classVariableDeclaration :
   identifierList ":" typeDenoter ;
normalMethodDefinition :
   procedureHeading;
overridingMethodDefinition :
   "OVERRIDE" procedureHeading;
abstractMethodDefinition :
   "ABSTRACT" procedureHeading;
classDeclaration :
   ( tracedClassDeclaration | untracedClassDeclaration ) ;
untracedClassDeclaration :
   ( normalClassDeclaration | abstractClassDeclaration ) ;
normalClassDeclaration :
   normalClassHeader ( normalClassDeclarationBody | "FORWARD" ) ;
normalClassDeclarationBody :
   ( inheritClause )? ( revealList )? normalClassComponentDeclarations
   ( classBody )? "END" classIdentifier ;
abstractClassDeclaration :
   abstractClassHeader ( abstractClassDeclarationBody | "FORWARD" ) ;
abstractClassDeclarationBody :
   ( inheritClause )? ( revealList )? abstractClassComponentDeclarations
   ( classBody )? "END" classIdentifier ;
classBody
  :                                     { Block InitBlk, FinalBlk; }
   moduleBody<InitBlk, FinalBlk>;
normalClassComponentDeclarations :
   ( normalComponentDeclaration )* ;
normalComponentDeclaration
  :                           {. DeclarationList Decls; .}
    ( "CONST" ( constantDeclaration<Decls> ";" )*
    | "TYPE" ( typeDeclaration<Decls> ";" )*
    | "VAR" ( classVariableDeclaration ";" )*
    | normalMethodDeclarations ";"
    )
  ;
abstractClassComponentDeclarations :
   ( abstractComponentDeclaration )* ;
abstractComponentDeclaration
  :                           {. DeclarationList Decls; .}
   ( "CONST" ( constantDeclaration<Decls> ";" )* |
   "TYPE" ( typeDeclaration<Decls> ";" )* |
   "VAR" ( classVariableDeclaration ";" )* |
   abstractMethodDeclarations ";"
   );
normalMethodDeclarations :
   normalMethodDeclaration | overridingMethodDeclaration;
normalMethodDeclaration :
   procedureDeclaration;
overridingMethodDeclaration :
   "OVERRIDE" procedureDeclaration;
abstractMethodDeclarations :
   normalMethodDeclaration | abstractMethodDefinition |
   overridingMethodDeclaration;
tracedClassDeclaration :
   "TRACED" ( normalTracedClassDeclaration | abstractTracedClassDeclaration ) ;
normalTracedClassDeclaration :
   normalTracedClassHeader ( normalTracedClassDeclarationBody | "FORWARD" ) ;
normalTracedClassHeader :
   "CLASS" classIdentifier ";" ;
normalTracedClassDeclarationBody :
   ( inheritClause )? ( revealList )? normalClassComponentDeclarations
   ( tracedClassBody )? "END" classIdentifier ;
abstractTracedClassDeclaration :
   abstractTracedClassHeader ( abstractTracedClassDeclarationBody | "FORWARD" ) ;
abstractTracedClassHeader :
   "ABSTRACT" "CLASS" classIdentifier ";" ;
abstractTracedClassDeclarationBody :
   ( inheritClause )? ( revealList )? abstractClassComponentDeclarations
   ( tracedClassBody )? "END" classIdentifier ;
tracedClassBody
  :                           { Block Body; }
   "BEGIN" blockBody<Body>;

revealList :
   "REVEAL" revealedComponentList ";" ;
revealedComponentList :
   revealedComponent ("," revealedComponent )* ;
revealedComponent :
   identifier | "READONLY" classVariableIdentifier ;
classVariableIdentifier :
   identifier ;

inheritClause :
   "INHERIT" classTypeIdentifier ";" ;
classTypeIdentifier :
   typeIdentifier ;

objectSelectedDesignator :
   objectVariableDesignator "." (classIdentifier "." )? classVariableIdentifier ;
objectVariableDesignator :
   variableDesignator ;
objectSelectedValue :
   objectValueDesignator "." ( classIdentifier "." )? entityIdentifier ;
objectValueDesignator :
   valueDesignator ;
entityIdentifier :
   identifier ;

guardStatement<Statement *&S>
  :                           {. StatementList Stmts; /* ERROR */ .}
   "GUARD" guardSelector "AS" guardedList ("ELSE" statementSequence<Stmts>)? "END" ;
guardSelector
  :                           {. Expression *E = nullptr; .}
    expression<E> ;
guardedList :
   guardedStatementSequence ("|" guardedStatementSequence )? ;
guardedStatementSequence
  :                           {. StatementList Stmts; /* ERROR */ .}
   ((objectDenoter)? ":" guardedClassType "DO" statementSequence<Stmts>)? ;
guardedClassType :
   classTypeIdentifier ;
objectDenoter :
   identifier ;
/* End OO */