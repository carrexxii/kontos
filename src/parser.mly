%{
    open Ast
%}

// Keywords: val var fun andalso orelse not is and rec
//           if then else while do case of
//           type module
//           int real bool char string list array map
//           true false ()
// Operators: + - * / % // ^ & @ :: . <- # .. >> <<
//            > < = <> >= <=
//            (,) [;] [|;|] {;} '' "" <>
// Flow Control: -> => |
// Builtin? |> <|

%token INT REAL BOOL STRING LIST ARRAY UNIT
%token <int64>  INTLIT
%token <float>  FLTLIT
%token <string> STRLIT
%token <string> IDENT
%token TRUE FALSE

%token <string> INFIX
%token VAL VAR FUN TYPE AS IS CASE OF
%token LPAREN RPAREN LBRACKET RBRACKET LBRACE RBRACE LBRACKETPIPE RBRACKETPIPE
%token PIPE RARROW DRARROW COMMA SEMI COLON
%token GT LT GTE LTE
%token PLUS MINUS TIMES DIVIDE MOD POW
%token EQUALS
%token EOF

%left PLUS MINUS
%left TIMES DIVIDE MOD
%left POW

%start ast
%type <ast> ast
%%

ast: decl* EOF { $1 }

decl:
	| var_decl  { VarDecl  $1 }
	| type_decl { TypeDecl $1 }
	| fun_decl  { VarDecl  $1 }

var_decl:
	| VAL ident EQUALS expr { kvar $2 $4 }
	| VAR ident EQUALS expr { kvar $2 $4 }

type_decl: TYPE IDENT type_params IS type_manifest list(type_attr) { ktype $2 $3 $5 $6 }
type_params:
	|           { None    }
	| OF IDENT+ { Some $2 }
type_manifest:
	| PIPE? separated_list(PIPE, ident)        { kmanifest Union $2 }
	| LBRACE flexible_list(SEMI, ident) RBRACE { kmanifest Record $2 }
type_attr: AS ktype EQUALS expr { kattr $2 $4 }

fun_decl: FUN ident ident+ RARROW var_decl* expr { kvar $2 (FunExpr (kfun $3 $5 $6)) }

expr:
	| case_expr                        { $1 }
	| record_expr                      { $1 }
	| LPAREN expr RPAREN               { $2 }
	| ident                            { Ident   $1 }
	| literal                          { Literal $1 }
	| FUN ident* RARROW var_decl* expr { FunExpr (kfun $2 $4 $5) }
	| expr INFIX expr                  { kinfix $1 $2 $3         }
	| expr op expr                     { FunCall ($2, [$1; $3]) }

%inline op:
	| PLUS   { kident "+" KInfer }
	| MINUS  { kident "-" KInfer }
	| TIMES  { kident "*" KInfer }
	| DIVIDE { kident "/" KInfer }
	| POW    { kident "^" KInfer }
	| MOD    { kident "%" KInfer }

record_val:
	| IDENT             { $1, None    }
	| IDENT EQUALS expr { $1, Some $3 }
record_expr: delimited(LBRACE, flexible_list(SEMI, record_val), RBRACE) { RecordExpr $1 }

case_expr:
	| case_guard+               { FunExpr (kfun [kident "@" KInfer] [] (CaseExpr (kcase None $1))) }
	| CASE expr? OF case_guard+ { CaseExpr (kcase $2 $4) }
case_guard: PIPE expr DRARROW expr { kguard $2 $4 }

ident:
	| typed_ident { $1               }
	| IDENT       { kident $1 KInfer }
typed_ident: IDENT OF ktype { kident $1 $3 }

literal:
	| delimited(LBRACKETPIPE, flexible_list(SEMI, expr), RBRACKETPIPE) { ArrLit $1 }
	| delimited(LBRACKET    , flexible_list(SEMI, expr), RBRACKET    ) { LstLit $1 }
	| UNIT   { UnitLit      }
	| INTLIT { IntLit $1    }
	| FLTLIT { FltLit $1    }
	| STRLIT { StrLit $1    }
	| TRUE   { BlnLit true  }
	| FALSE  { BlnLit false }

ktype:
	| INT    { KInt       }
	| REAL   { KReal      }
	| BOOL   { KBool      }
	| STRING { KString    }
	| LIST   { KList      }
	| ARRAY  { KArray     }
	| UNIT   { KUnit      }
	| IDENT  { KCustom $1 }

flexible_list(delim, x):
	|                                 { []       }
	| x                               { [$1]     }
	| x delim flexible_list(delim, x) { $1 :: $3 }
