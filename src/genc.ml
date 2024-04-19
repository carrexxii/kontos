open Core
open Printf
open Ast

let header ="
#include <stdint.h>
#include <stdbool.h>
typedef int64_t kint;
typedef double  kreal;
typedef bool    kbool;

"

let gen output ast =
	let buf = Buffer.create 4096 in
	let write_char = Buffer.add_char   buf in
	let write_str  = Buffer.add_string buf in

	let string_of_ident { name; type' } =
		sprintf "%s %s" (string_of_type type') name
	in
	let rec write_expr = function
		| FunExpr { params; decls; body; } ->
			write_param_list params;
			List.iter decls ~f:write_decl;
			()
		| Ident ident -> write_str ident.name
		| FunCall    (ident, expr)         -> write_str "!!"
		| Literal    lit                   -> write_str (string_of_literal lit)
		| UnaryCall  (ident, expr)         -> write_str "!!"
		| BinaryCall (lexpr, ident, rexpr) -> write_str "!!"
	and write_kvar (kval: var_decl) =
		let { ident; expr }: var_decl = kval in
		match expr with
		| FunExpr { params; decls; body; } ->
			write_char '\n';
			write_str (string_of_ident ident);
			write_param_list params;
			write_str "{\n";
			List.iter decls ~f:write_decl;
			write_str "return (";
			write_expr body;
			write_str ");\n}\n";
		| _ ->
			write_str (string_of_ident ident);
			write_str " = ";
			write_expr expr;
			write_str ";\n"
	and write_decl = function
		| VarDecl kvar -> write_kvar kvar
	and write_param_list params =
		write_char '(';
		List.iteri params ~f:(fun i param ->
			write_str (string_of_ident param);
			if i <> List.length params - 1 then
				write_char ',');
		write_str ")\n"
	in

	write_str header;
	List.iter ~f:write_decl ast;
	Out_channel.write_all output ~data:(Buffer.contents buf)
