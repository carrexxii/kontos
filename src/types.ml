open Core
open Ast

let check ast =
	let idents = Hashtbl.create (module String) in

	let type_of_literal = function
		| UnitLit  -> KUnit
		| IntLit _ -> KInt
		| FltLit _ -> KReal
		| StrLit _ -> KString
		| BlnLit _ -> KBool
		| LstLit _ -> KList
		| ArrLit _ -> KArray
	and type_of_ident { name; kind } =
		match kind with
		| KInfer ->
			begin match Hashtbl.find idents name with
			| Some kind -> kind
			| None -> Printf.printf "Error: could not infer type of \"%s\"\n" name; KInfer
			end
		| kind  -> kind
	in

	let rec type_of_function { params; decls; body } =
		let params = List.map params ~f:(fun param ->
			{ name    = param.name;
			  kind   = type_of_ident param; })
		and decls = List.map decls ~f:type_of_decl
		and body = type_of_expr body in
		{ params; decls; body = fst body; }, snd body
	and type_of_expr = function
		| Ident ident ->
			let ident = { ident with kind = type_of_ident ident } in
			Hashtbl.set idents ~key:ident.name ~data:ident.kind;
			Ident ident, ident.kind
		| Literal lit -> Literal lit, type_of_literal lit
		| FunExpr fexpr ->
			let fexpr, kind = type_of_function fexpr in
			FunExpr fexpr, kind
		| FunCall (ident, exprs) ->
			let exprs    = List.map exprs ~f:type_of_expr in
			let lhs_type = snd (Option.value_exn (List.hd exprs)) in
			let ident    = { ident with kind = lhs_type } in
			FunCall (ident, List.map exprs ~f:(fun expr -> fst expr)), ident.kind
		| x -> Printf.printf "Error: need to fetch type from identifier for expression\n"; x, KInfer
	and type_of_decl = function
		| VarDecl { ident; expr } ->
			let expr, kind = type_of_expr expr in
			Hashtbl.set idents ~key:ident.name ~data:kind;
			VarDecl (kvar { ident with kind = kind } expr)
		| TypeDecl { name; params; manifest; attr; } ->
			TypeDecl (ktype name params manifest attr)
	in

	List.map ast ~f:type_of_decl
