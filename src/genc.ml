open Core
open Printf
open Ast

let header = {|
#include "kontos.h"

|}

let gen output ast =
	let buf = Buffer.create 4096 in
	let write_char = Buffer.add_char   buf in
	let write_str  = Buffer.add_string buf in

	let string_of_ident { name; kind } =
		sprintf "%s %s" (string_of_type kind) name
	in
	let rec write_expr = function
		| FunExpr { params; decls; body; } ->
			write_param_list params;
			List.iter decls ~f:write_decl;
			()
		| Ident ident -> write_str ident.name
		| FunCall    (ident, exprs)        -> write_fun_call ident exprs
		| Literal    lit                   -> write_str (string_of_literal lit)
		| CaseExpr    cespr                -> write_str "!!"
		| RecordExpr  rexpr                -> write_str "!!"
	and write_fun_call { name; kind } exprs =
		match name with
		| "+" | "-" | "*" | "/" ->
			begin match exprs with
			| lhs::rhs::[] ->
				write_expr lhs;
				write_str name;
				write_expr rhs
			| _ -> failwith ""
			end
		| name ->
			write_str name;
			write_char '(';
			List.iteri exprs ~f:(fun i expr ->
				write_expr expr;
				if i <> List.length exprs - 1 then
					write_char ',');
			write_char ')'
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
		| TypeDecl _ -> ()
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
