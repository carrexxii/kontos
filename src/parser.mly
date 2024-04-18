%{
    open Ast
%}

%token <int64>  INTLIT
%token <float>  FLTLIT
%token <string> STRLIT
%token <string> IDENT

%token VAL VAR
%token EQUALS

%token EOL EOF

%start ast
%type <ast> ast
%%

ast: stmt* EOF { $1 }

stmt:
	| EOL      { NOPStmt    }
	| val_stmt { ValStmt $1 }
	| var_stmt { VarStmt $1 }

expr:
	| ident   { Ident $1 }
	| literal { Literal $1 }

val_stmt: VAL ident EQUALS expr EOL { kval $2 $4 }
var_stmt: VAR ident EQUALS expr EOL { kvar $2 $4 }

ident: IDENT { kident $1 }

literal:
	| INTLIT { IntLit $1 }
	| FLTLIT { FltLit $1 }
	| STRLIT { StrLit $1 }
