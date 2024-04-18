open Core

type ast = decl list

and ident =
	{ name : string;
	  type': ktype; }

and fun_expr =
	{ params: ident list;
	  decls : decl list;
	  body  : expr; }

and val_decl =
	{ ident: ident;
	  expr : expr; }

and var_decl =
	{ ident: ident;
	  expr : expr; }

and decl =
	| ValDecl of val_decl
	| VarDecl of var_decl

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
	| KFun of ktype
	| KInfer
	| KCustom of string

and literal =
	| UnitLit
	| IntLit of int64
	| FltLit of float
	| BlnLit of bool
	| StrLit of string

(* -------------------------------------------------------------------- *)

let kident name type' =
	{ name  = name;
	  type' = type'; }

let kval ident expr =
	({ ident = ident;
	   expr  = expr; }: val_decl)

let kvar ident expr =
	({ ident = ident;
	   expr  = expr; }: var_decl)

let kfun params decls body =
	{ params = params;
	  decls  = decls;
	  body   = body; }

(* -------------------------------------------------------------------- *)

let rec string_of_type = function
	| KInt       -> "kint"
	| KReal      -> "kreal"
	| KString    -> "kstring"
	| KBool      -> "kbool"
	| KUnit      -> "kunit"
	| KFun rtype -> "kfun" ^ (string_of_type rtype)
	| KInfer     -> "auto"
	| KCustom id -> id

let string_of_literal = function
	| UnitLit  -> "NULL"
	| IntLit x -> Int64.to_string x
	| FltLit x -> string_of_float x
	| StrLit x -> "\"" ^ x ^ "\""
	| _ -> "<Unknown literal>"

let string_of_ast ast =
	let string_of_ident_list =
		List.fold ~init:"" ~f:(fun acc id -> id.name ^ acc)
	in
	let rec string_of_expr = function
		| Literal lit -> string_of_literal lit
		| Ident {name; type'} -> sprintf "(%s: %s)" name (string_of_type type')
		| FunExpr f -> sprintf "(fun (%s) -> %s (%s))"
		                       (string_of_ident_list f.params)
		                       (string_of_decl_list f.decls)
		                       (string_of_expr f.body)
		| _ -> "<Unknown literal>"
	and string_of_decl = function
		| ValDecl kval -> sprintf "(val \"%s\": %s = %s)" kval.ident.name (string_of_type kval.ident.type') (string_of_expr kval.expr)
		| VarDecl kvar -> sprintf "(var \"%s\": %s = %s)" kvar.ident.name (string_of_type kvar.ident.type') (string_of_expr kvar.expr)
		(* | _ -> "<Unknown statement>" *)
	and string_of_decl_list decls =
		List.map decls ~f:string_of_decl
		|> List.rev
		|> List.fold ~init:"" ~f:(fun acc str -> str ^ "\n" ^ acc)
	in
	string_of_decl_list ast
