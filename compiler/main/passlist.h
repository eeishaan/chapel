#ifndef _PASSLIST_H_
#define _PASSLIST_H_

/* This is the default list of passes that will be run by the
   compiler.  The passes shown will be run in the order shown,
   and their arguments will be set to the quoted string that
   follows.

   This file may be saved and fed to the compiler using the
   --passlist argument to specify a different set of passes
   dynamically.
*/

PassInfo passlist[] = {
  FIRST,

  // passes to create the basic AST
  RUN(FilesToAST, ""),
  RUN(CreateEntryPoint, ""),
  RUN(Fixup, ""),

  // passes to normalize the basic AST
  RUN(Cleanup, ""),

  RUN(InsertAnonymousTypes, ""),

  // passes to run analysis
  RUN(Fixup, "verify"),  // this is a sanity check
  RUN(RunAnalysis, ""),
  RUN(Fixup, "verify"),  // this is a sanity check

  // passes to capture analysis information in the AST
  RUN(ResolveSymbols, ""),
  RUN(FindUnknownTypes, ""),
  RUN(RemoveTypeVariableActuals, ""),
  RUN(RemoveTypeVariableFormals, ""),

  // check the program's semantics
  RUN(CheckSemantics, ""),

  //  RUN(Fixup, "hyper verify"),  // hyper verification!

  // eventually, optimizations will go here


  // passes to prepare for C code generation
  RUN(DestructureTupleAssignments, ""),
  RUN(MethodsToFunctions, ""),
  RUN(ProcessParameters, ""),
  RUN(InsertUnionChecks, ""),
  RUN(LegalizeCNames, ""), 

  // passes to generate code and compile
  RUN(Fixup, "verify"),
  RUN(Codegen, ""),
  RUN(BuildBinary, ""),

  LAST
};

#endif
