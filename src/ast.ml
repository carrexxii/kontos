open Core

type ast = stmt list

and func =
	{ ident : string;
	  params: ident list;
	  body  : expr; }

and val_stmt =
	{ ident: ident;
	  expr : expr; }

and var_stmt =
	{ ident: ident;
	  expr : expr; }

and stmt =
	| NOPStmt
	| FuncStmt of func
	| ValStmt  of val_stmt
	| VarStmt  of var_stmt

and expr =
	| NOPExpr
	| FuncExpr   of func
	| FuncCall   of ident * expr list
	| Ident      of ident
	| Literal    of literal
	| UnaryCall  of ident * expr
	| BinaryCall of expr * ident * expr

and ktype =
	| KInt
	| KReal
	| KString
	| KBool
	| KUnit
	| KInfer
	| KCustom of ident
	| KUnknown

and literal =
	| IntLit of int64
	| FltLit of float
	| BlnLit of bool
	| StrLit of string

and ident =
	{ name : string }

(* -------------------------------------------------------------------- *)

let kident name =
	{ name = name; }

let kval ident expr =
	({ ident = ident;
	   expr  = expr; }: val_stmt)

let kvar ident expr =
	({ ident = ident;
	   expr  = expr; }: var_stmt)

let kfun ident params body =
	{ ident  = ident;
	  params = params;
	  body   = body; }

(* -------------------------------------------------------------------- *)

let string_of_ast ast =
	let string_of_expr = function
		| Literal lit -> begin
			match lit with
			| IntLit x -> Int64.to_string x
			| _ -> "<Unknown literal>"
			end
		| _ -> "<Unknown literal>"
	in
	let string_of_stmt = function
		| ValStmt kval -> sprintf "(val \"%s\" = %s)\n" kval.ident.name (string_of_expr kval.expr)
		| _ -> "<Unknown statement>"
	in
	ast
	|> List.map ~f:string_of_stmt
	|> List.fold ~init:"" ~f:(fun acc str -> str ^ acc)
