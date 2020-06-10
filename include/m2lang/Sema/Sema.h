//===--- Sema.h - M2 Language Family Semantic Analyzer ----------*- C++ -*-===//
//
// Part of the M2Lang Project, under the Apache License v2.0 with
// LLVM Exceptions. See LICENSE file for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
///
/// \file
/// Defines the semantic analyzer classes for Modula-2.
///
//===----------------------------------------------------------------------===//

#ifndef M2LANG_SEMA_SEMA_H
#define M2LANG_SEMA_SEMA_H

#include "m2lang/AST/AST.h"
#include "m2lang/Basic/Diagnostic.h"
#include "m2lang/Sema/Scope.h"

namespace m2lang {

class Identifier {
  SMLoc Loc;
  StringRef Name;

public:
  Identifier() = default;
  Identifier(SMLoc Loc, StringRef Name) : Loc(Loc), Name(Name) {}

  SMLoc getLoc() const { return Loc; }
  StringRef getName() const { return Name; }
};

using IdentifierList = llvm::SmallVector<Identifier, 8>;
using VariableIdentifierList =
    llvm::SmallVector<std::pair<Identifier, Expression *>, 8>;

class Sema final {
  DiagnosticsEngine &Diags;

  Scope *CurrentScope;
  Declaration *CurrentDecl;

  // Declarations in the global scope. Possible move to Context class.
  Type *IntegerType;
  Type *CardinalType;
  Type *BooleanType;
  BooleanLiteral *TrueLiteral;
  BooleanLiteral *FalseLiteral;
  Constant *TrueConst;
  Constant *FalseConst;

  friend class EnterDeclScope;
  void enterScope(Declaration *Decl);
  void leaveScope();

public:
  Sema(DiagnosticsEngine &Diags)
      : Diags(Diags), CurrentScope(nullptr), CurrentDecl(nullptr) {
    initialize();
  }

  void initialize();

  bool isModule(StringRef Name);
  bool isClass(StringRef Name);

  // Declarations
  ProgramModule *actOnProgramModule(Identifier ModuleName);
  void actOnProgramModule(ProgramModule *Mod, Identifier ModuleName,
                          DeclarationList Decls, Block InitBlk, Block FinalBlk);
  LocalModule *actOnLocalModule(Identifier ModuleName);
  Procedure *actOnProcedure(Identifier ProcName);
  void actOnProcedure(Procedure *Proc, Identifier ProcName,
                      FormalParameterList Params, Declaration *ResultType,
                      DeclarationList Decls, Block Body, bool IsFunction);
  void actOnForwardProcedure(Procedure *Proc);
  void actOnConstant(DeclarationList &Decls, Identifier Name, Expression *Expr);
  void actOnType(DeclarationList &Decls, Identifier TypeName,
                 TypeDenoter *TyDen);
  void actOnVariable(DeclarationList &Decls, VariableIdentifierList &VarIdList,
                     TypeDenoter *TyDen);
  void actOnFormalParameter(FormalParameterList Params, IdentifierList IdList,
                            bool IsVar, Type *Ty);

  // Qualified identifier
  Declaration *actOnModuleIdentifier(Declaration *ModDecl, Identifier Name);
  Declaration *actOnClassIdentifier(Declaration *ModDecl, Identifier Name);
  Declaration *actOnQualifiedIdentifier(Declaration *Decl, Identifier Name);

  // Types
  NamedType *actOnNamedType(SMLoc Loc, Declaration *Decl);

  // Statements
  Statement *actOnIfStmt(Expression *Cond);
  Statement *actOnCaseStmt();
  void actOnWhileStmt(StatementList &Stmts, SMLoc Loc, Expression *Cond,
                      StatementList &WhileStmts);
  void actOnRepeatStmt(StatementList &Stmts, SMLoc Loc, Expression *Cond,
                       StatementList &RepeatStmts);
  void actOnLoopStmt(StatementList &Stmts, SMLoc Loc, StatementList &LoopStmts);
  Statement *actOnForStmt();
  Statement *actOnWithStmt();
  void actOnExitStmt(StatementList &Stmts, SMLoc Loc);
  void actOnReturnStmt(StatementList &Stmts, Expression *E);
  Statement *actOnRetryStmt(SMLoc Loc);

  // Expressions
  void actOnConstantExpression();
  Expression *actOnExpression(Expression *Left, Expression *Right,
                              const OperatorInfo &Op);
  Expression *actOnSimpleExpression(Expression *Left, Expression *Right,
                                    const OperatorInfo &Op);
  Expression *actOnTerm(Expression *Left, Expression *Right,
                        const OperatorInfo &Op);
  Expression *actOnFactor(Expression *E, const OperatorInfo &Op);
  Expression *actOnIntegerLiteral(SMLoc Loc, StringRef LiteralData);
  Expression *actOnRealLiteral(SMLoc Loc, StringRef LiteralData);
  Expression *actOnStringLiteral(SMLoc Loc, StringRef LiteralData);
  Expression *actOnCharLiteral(SMLoc Loc, StringRef LiteralData);
};

class EnterDeclScope {
  Sema &Semantics;

public:
  EnterDeclScope(Sema &Semantics, Declaration *Decl) : Semantics(Semantics) {
    Semantics.enterScope(Decl);
  }
  ~EnterDeclScope() { Semantics.leaveScope(); }
};

} // namespace m2lang

#endif