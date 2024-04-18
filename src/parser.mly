%{
    open Ast
%}

%token <int64>  INTLIT
%token <float>  FLTLIT
%token <string> STRLIT
%token <string> IDENT
%token UNIT

%token VAL VAR FUN END
%token RARROW
%token EQUALS

%token EOF

%start ast
%type <ast> ast
%%

ast: decl* EOF { $1 }

decl:
	| VAL ident EQUALS expr              { ValDecl (kval $2 $4) }
	| VAR ident EQUALS expr              { VarDecl (kvar $2 $4) }
	| FUN ident ident* RARROW decl* expr { ValDecl (kval $2 (FunExpr (kfun $3 $5 $6))) }

expr:
	| ident                        { Ident   $1 }
	| literal                      { Literal $1 }
	| FUN ident* RARROW decl* expr { FunExpr (kfun $2 $4 $5) }

ident: IDENT { kident $1 }

literal:
	| UNIT   { UnitLit   }
	| INTLIT { IntLit $1 }
	| FLTLIT { FltLit $1 }
	| STRLIT { StrLit $1 }
