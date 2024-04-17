%{
    open Ast
%}

%token <int64>  INTLIT
%token <float>  FLTLIT
%token <string> STRLIT
%token <string> IDENT

%token VAL EQUALS

%token EOF EOL

%start ast
%type <ast> ast
%%

ast: stmt* EOF { $1 }

stmt:
	| val_stmt { ValStmt $1 }

expr:
	| ident   { Ident $1 }
	| literal { Literal $1 }

val_stmt: VAL ident EQUALS expr EOL { kval $2 $4 }

ident: IDENT { kident $1 }

literal:
	| INTLIT { IntLit $1 }
