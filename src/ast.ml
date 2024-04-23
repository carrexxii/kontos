open Core

type ast = decl list

and ident =
	{ name: string;
	  kind: ktype; }

and fun_expr =
	{ params: ident list;
	  decls : decl list;
	  body  : expr; }

and case_expr =
	{ expr  : expr option;
	  guards: guard list; }
and guard =
	{ lhs: expr;
	  rhs: expr; }

and var_decl =
	{ ident: ident;
	  expr : expr; }

and type_kind =
	| Record
	| Union
and type_decl =
	{ name    : string;
	  params  : string list option;
	  manifest: type_manifest;
	  attr    : type_attr list }
and type_manifest =
	{ kind: type_kind;
	  vals: ident list; }
and type_attr =
	{ kind: ktype;
	  expr: expr; }

and decl =
	| VarDecl  of var_decl
	| TypeDecl of type_decl

and expr =
	| FunExpr    of fun_expr
	| CaseExpr   of case_expr
	| FunCall    of ident * expr list
	| RecordExpr of (string * expr option) list
	| Ident      of ident
	| Literal    of literal

and ktype =
	| KInt
	| KReal
	| KBool
	| KString
	| KList
	| KArray
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
	| LstLit of expr list
	| ArrLit of expr list

(* -------------------------------------------------------------------- *)

let kident    name kind                 = { name; kind; }
let kvar      ident expr                = { ident; expr; }
let ktype     name params manifest attr = { name; params; manifest; attr; }
let kmanifest kind vals                 = { kind; vals }
let kattr     kind expr                 = { kind; expr; }
let kfun      params decls body         = { params; decls; body; }
let kcase     expr guards               = { expr; guards; }
let kguard    lhs rhs                   = { lhs; rhs }
let kinfix lhs op rhs =
	let ident = kident op KInfer in
	FunCall (ident, [lhs; rhs])

(* -------------------------------------------------------------------- *)

let rec string_of_type = function
	| KInt       -> "kint"
	| KReal      -> "kreal"
	| KBool      -> "kbool"
	| KString    -> "kstring"
	| KList      -> "klist"
	| KArray     -> "karray"
	| KUnit      -> "kunit"
	| KFun rtype -> "kfun " ^ (string_of_type rtype)
	| KInfer     -> "auto"
	| KCustom id -> id

and string_of_type_kind = function
	| Record -> "Record"
	| Union  -> "Union"

and string_of_literal = function
	| UnitLit  -> "NULL"
	| IntLit x -> Int64.to_string x
	| FltLit x -> string_of_float x
	| BlnLit x -> if x then "true" else "false"
	| StrLit x -> "\"" ^ x ^ "\""
	| LstLit lst
	| ArrLit lst -> String.concat ~sep:"; " @@ List.map lst ~f:(fun x -> string_of_expr x)

and string_of_ident_list ?(sep="") =
	List.fold ~init:"" ~f:(fun acc id -> id.name ^ sep ^ acc)

and string_of_manifest { kind; vals } =
	match kind with
	| Union  -> sprintf "%s\n\t| %s" (string_of_type_kind kind) (string_of_ident_list vals ~sep:"\n\t| ")
	| Record -> sprintf "%s\n\t{ %s }" (string_of_type_kind kind) (string_of_ident_list vals ~sep:";\n\t  ")

and string_of_guard_list =
	List.fold ~init:"" ~f:(fun acc { lhs; rhs } -> string_of_expr lhs ^ string_of_expr rhs ^ acc)

and string_of_expr = function
	| Literal lit -> string_of_literal lit
	| Ident {name; kind} -> sprintf "(%s: %s)" name (string_of_type kind)
	| FunExpr f ->
		sprintf "(fun (%s) -> %s (%s))"
		        (string_of_ident_list f.params)
		        (string_of_decl_list f.decls)
		        (string_of_expr f.body)
	| CaseExpr { expr; guards } ->
		sprintf "(case %s of %s"
		        (match expr with
		         | Some expr -> string_of_expr expr
		         | None      -> "")
		        (string_of_guard_list guards)
	| FunCall (ident, exprs) ->
		sprintf "(call \"%s\" %s)"
		        ident.name
				(String.concat ~sep:" " @@ List.map exprs ~f:string_of_expr)
	| _ -> "<Unknown expr>"
and string_of_decl = function
	| VarDecl  decl -> sprintf "(var \"%s\" of %s = %s)" decl.ident.name (string_of_type decl.ident.kind) (string_of_expr decl.expr)
	| TypeDecl decl -> sprintf "(type %s \"%s\" = %s)" (string_of_type_kind decl.manifest.kind) decl.name (string_of_manifest decl.manifest)
and string_of_decl_list decls =
	List.map decls ~f:string_of_decl
	|> List.rev
	|> List.fold ~init:"" ~f:(fun acc str -> str ^ "\n" ^ acc)

let string_of_ast ast =
	string_of_decl_list ast
