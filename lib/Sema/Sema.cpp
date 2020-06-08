//===--- Sema.h - M2 Language Family Semantic Analyzer ----------*- C++ -*-===//
//
// Part of the M2Lang Project, under the Apache License v2.0 with
// LLVM Exceptions. See LICENSE file for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
///
/// \file
/// Defines the semantic analyzer implementation.
///
//===----------------------------------------------------------------------===//

#include "m2lang/Sema/Sema.h"
#include "llvm/Support/raw_ostream.h"

using namespace m2lang;

void Sema::initialize() { CurrentScope = new Scope(); }

void Sema::enterScope(Declaration *Decl) {
  CurrentScope = new Scope(CurrentScope);
  CurrentDecl = Decl;
}

void Sema::leaveScope() {
  assert(CurrentScope && "Can't leave non-existing scope");
  Scope *Parent = CurrentScope->getParent();
  delete CurrentScope;
  CurrentScope = Parent;
  CurrentDecl = CurrentDecl->getEnclosingDecl();
}

bool Sema::isModule(StringRef Name) {
  llvm::outs() << "Sema::isModule: " << Name << "\n";
  Declaration *Decl = CurrentScope->lookup(Name);
  return llvm::isa_and_nonnull<CompilationModule>(Decl) ||
         llvm::isa_and_nonnull<LocalModule>(Decl);
}

bool Sema::isClass(StringRef Name) {
  llvm::outs() << "Sema::isClass: " << Name << "\n";
  Declaration *Decl = CurrentScope->lookup(Name);
  return llvm::isa_and_nonnull<Class>(Decl);
}

ProgramModule *Sema::actOnProgramModule(Identifier ModuleName) {
  //
  return ProgramModule::create(CurrentDecl, ModuleName.getLoc(),
                               ModuleName.getName());
}

void Sema::actOnProgramModule(ProgramModule *Mod, Identifier ModuleName,
                              DeclarationList Decls, Block InitBlk,
                              Block FinalBlk) {
  if (Mod->getName() != ModuleName.getName()) {
    Diags.report(ModuleName.getLoc(), diag::err_module_identifier_not_equal)
        << Mod->getName() << ModuleName.getName();
  }
  Mod->update(Decls, InitBlk, FinalBlk);
}

LocalModule *Sema::actOnLocalModule(Identifier ModuleName) {
  llvm::outs() << "actOnLocalModule\n";
  return LocalModule::create(CurrentDecl, ModuleName.getLoc(),
                             ModuleName.getName());
}

Procedure *Sema::actOnProcedure(Identifier ProcName) {
  llvm::outs() << "actOnProcedure\n";
  return Procedure::create(CurrentDecl, ProcName.getLoc(), ProcName.getName());
}

void Sema::actOnProcedure(Procedure *Proc, Identifier ProcName) {
  if (Proc->getName() != ProcName.getName()) {
    Diags.report(ProcName.getLoc(), diag::err_proc_identifier_not_equal)
        << Proc->getName() << ProcName.getName();
  }
  // Mod->update(Decls, InitBlk, FinalBlk);
}

void Sema::actOnForwardProcedure(Procedure *Proc) { Proc->setForward(); }

void Sema::actOnConstant(DeclarationList &Decls, SMLoc Loc, StringRef Name,
                         Expression *Expr) {
  llvm::outs() << "Sema::actOnConstant: Name = " << Name << "\n";
  Constant *Const = Constant::create(CurrentDecl, Loc, Name, nullptr, Expr);
  if (!CurrentScope->insert(Const))
    Diags.report(Loc, diag::err_symbol_already_declared) << Name;
  Decls.push_back(Const);
}

void Sema::actOnType(DeclarationList &Decls, Identifier TypeName) {
  llvm::outs() << "Sema::actOnType: Name = " << TypeName.getName() << "\n";
  Type *Ty = Type::create(CurrentDecl, TypeName.getLoc(), TypeName.getName());
  if (!CurrentScope->insert(Ty))
    Diags.report(TypeName.getLoc(), diag::err_symbol_already_declared)
        << TypeName.getName();
  Decls.push_back(Ty);
}

void Sema::actOnVariable(DeclarationList &Decls, SMLoc Loc, StringRef Name,
                         Type *TypeDecl) {
  llvm::outs() << "Sema::actOnVariable: Name = " << Name << "\n";
  Variable *Var = Variable::create(CurrentDecl, Loc, Name, TypeDecl);
  Decls.push_back(Var);
}

Statement *Sema::actOnIfStmt(Expression *Cond) {
  llvm::outs() << "actOnIfStmt\n";
  return IfStatement::create(Cond);
}

Statement *Sema::actOnCaseStmt() {
  llvm::outs() << "actOnCaseStmt\n";
  return nullptr;
}

Statement *Sema::actOnWhileStmt(Expression *Cond, StatementList &Stmts,
                                SMLoc Loc) {
  llvm::outs() << "actOnWhileStmt\n";
  return WhileStatement::create(Cond, Stmts, Loc);
}

Statement *Sema::actOnRepeatStmt(Expression *Cond, StatementList &Stmts,
                                 SMLoc Loc) {
  llvm::outs() << "actOnRepeatStmt\n";
  return RepeatStatement::create(Cond, Stmts, Loc);
}

Statement *Sema::actOnLoopStmt(StatementList &Stmts, SMLoc Loc) {
  llvm::outs() << "actOnLoopStmt\n";
  return LoopStatement::create(Stmts, Loc);
}

Statement *Sema::actOnForStmt() {
  llvm::outs() << "actOnForStmt\n";
  return nullptr;
}

Statement *Sema::actOnWithStmt() {
  llvm::outs() << "actOnWithStmt\n";
  return nullptr;
}

Statement *Sema::actOnExitStmt(SMLoc Loc) {
  llvm::outs() << "actOnExitStmt\n";
  return ExitStatement::create(Loc);
}

Statement *Sema::actOnReturnStmt(Expression *E) {
  llvm::outs() << "actOnReturnStmt\n";
  return ReturnStatement::create(E);
}

Statement *Sema::actOnRetryStmt(SMLoc Loc) {
  llvm::outs() << "actOnRetryStmt\n";
  return RetryStatement::create(Loc);
}

void Sema::actOnConstantExpression() {
  llvm::outs() << "actOnConstantExpression\n";
}

Expression *Sema::actOnExpression(Expression *Left, Expression *Right,
                                  const OperatorInfo &Op) {
  llvm::outs() << "actOnExpression\n";
  // Op is a relational operation.
  return InfixExpression::create(Left, Right, Op);
}

Expression *Sema::actOnSimpleExpression(Expression *Left, Expression *Right,
                                        const OperatorInfo &Op) {
  llvm::outs() << "actOnSimpleExpression\n";
  // Op is a term operation.
  return InfixExpression::create(Left, Right, Op);
}

Expression *Sema::actOnTerm(Expression *Left, Expression *Right,
                            const OperatorInfo &Op) {
  llvm::outs() << "actOnTerm\n";
  // Op is a factor operation.
  return InfixExpression::create(Left, Right, Op);
}

Expression *Sema::actOnFactor(Expression *E, const OperatorInfo &Op) {
  llvm::outs() << "actOnFactor\n";
  return PrefixExpression::create(E, Op);
}
