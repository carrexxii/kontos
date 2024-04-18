open Core

type ast = decl list

and fun_expr =
	{ params: ident list;
	  decls : decl list;
	  body  : expr; }

and val_expr =
	{ ident: ident;
	  expr : expr; }

and var_expr =
	{ ident: ident;
	  expr : expr; }

and decl =
	| ValDecl of val_expr
	| VarDecl of var_expr

and expr =
	| FunExpr    of fun_expr
	| FunCall    of ident * expr list
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
	| UnitLit
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
	   expr  = expr; }: val_expr)

let kvar ident expr =
	({ ident = ident;
	   expr  = expr; }: var_expr)

let kfun params decls body =
	{ params = params;
	  decls  = decls;
	  body   = body; }

(* -------------------------------------------------------------------- *)

let string_of_ast ast =
	let string_of_ident_list =
		List.fold ~init:"" ~f:(fun acc id -> id.name ^ acc)
	in
	let rec string_of_expr = function
		| Literal lit -> begin
			match lit with
			| UnitLit  -> "()"
			| IntLit x -> Int64.to_string x
			| FltLit x -> string_of_float x
			| StrLit x -> "\"" ^ x ^ "\""
			| _ -> "<Unknown literal>"
			end
		| Ident {name} -> sprintf "$%s" name
		| FunExpr f -> sprintf "(fun (%s) -> %s (%s))"
		                       (string_of_ident_list f.params)
		                       (string_of_decl_list f.decls)
		                       (string_of_expr f.body)
		| _ -> "<Unknown literal>"
	and string_of_decl = function
		| ValDecl kval -> sprintf "(val \"%s\" = %s)" kval.ident.name (string_of_expr kval.expr)
		| VarDecl kvar -> sprintf "(var \"%s\" = %s)" kvar.ident.name (string_of_expr kvar.expr)
		(* | _ -> "<Unknown statement>" *)
	and string_of_decl_list decls =
		List.map decls ~f:string_of_decl
		|> List.rev
		|> List.fold ~init:"" ~f:(fun acc str -> str ^ "\n" ^ acc)
	in
	string_of_decl_list ast
