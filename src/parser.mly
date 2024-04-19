%{
    open Ast
%}

%token INT STRING REAL BOOL UNIT
%token <int64>  INTLIT
%token <float>  FLTLIT
%token <string> STRLIT
%token <string> IDENT

%token VAL VAR FUN
%token LPAREN RPAREN
%token RARROW COLON
%token EQUALS

%token EOF

%start ast
%type <ast> ast
%%

ast: decl* EOF { $1 }

decl:
	| VAL ident EQUALS expr              { VarDecl (kvar $2 $4) }
	| VAR ident EQUALS expr              { VarDecl (kvar $2 $4) }
	| FUN ident ident* RARROW decl* expr { VarDecl (kvar $2 (FunExpr (kfun $3 $5 $6))) }

expr:
	| LPAREN expr RPAREN           { $2 }
	| ident                        { Ident   $1 }
	| literal                      { Literal $1 }
	| FUN ident* RARROW decl* expr { FunExpr (kfun $2 $4 $5) }

ident:
	| IDENT                           { kident $1 KInfer }
	| IDENT COLON ktype               { kident $1 $3     }
	| LPAREN IDENT COLON ktype RPAREN { kident $2 $4     }

literal:
	| UNIT   { UnitLit   }
	| INTLIT { IntLit $1 }
	| FLTLIT { FltLit $1 }
	| STRLIT { StrLit $1 }

ktype:
	| INT    { KInt       }
	| STRING { KString    }
	| REAL   { KReal      }
	| BOOL   { KBool      }
	| UNIT   { KUnit      }
	| IDENT  { KCustom $1 }
