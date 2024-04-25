open Core
open Printf
open List
open Ast

type op =
	| NOP
	| PUSH
	| LOAD
	| ADDRR | SUBRR | MULRR | DIVRR | POWRR
	| ADDRL | SUBRL | MULRL | DIVRL | POWRL
	| ADDLL | SUBLL | MULLL | DIVLL | POWLL
	| HALT
	[@@deriving enum, show]

type constant =
	| Int


type literal =
	| LiteralVal of int
	| StackRef   of int
	let int_from_lit = function
		| LiteralVal x -> x
		| StackRef   x -> x

let lit_max = (Int.pow 2 24) - 1

type type_table = ktype list

let buf = Buffer.create 4096
let write_char = Buffer.add_char buf
let write_str  = Buffer.add_string buf

let magic = 0x646F6D79l
let minor = 1
let major = 0
let write_file output constc =
	let%bitstring header =
		{| magic : 32;
		   minor : 8;
		   major : 8;
		   constc: 32 |}
	in
	printf "\n";
	Bitstring.hexdump_bitstring stdout header;
	printf "\n";
	Bitstring.bitstring_to_file header output

let tinstr op p1 p2 p3 =
	printf "%s %d %d %d\n" (show_op op) p1 p2 p3;
	let op = op_to_enum op in
	let%bitstring str =
		{| op: 8;
		   p1: 8;
		   p2: 8;
		   p3: 8 |}
	in str |> ignore

let dinstr op p1 p2 =
	printf "%s %d %d\n" (show_op op) p1 p2;
	let op = op_to_enum op in
	let%bitstring str =
		{| op: 8;
		   p1: 8;
		   p2: 16 |}
	in str |> ignore

let sinstr op p =
	printf "%s %d\n" (show_op op) p;
	let op = op_to_enum op in
	let%bitstring str =
		{| op: 8;
		   p : 24 |}
	in str |> ignore

type value =
	| LitVal of int
	| RegVal of int

let regs = Stack.create ()
let frame = ref 0

let get_literal = function
	| IntLit x -> begin
		match Int64.to_int x with
		| Some x when x <= lit_max -> LitVal x
		| Some x -> RegVal x
		| _ -> failwith "Unreachable"
		end
	| _ -> failwith "~~~"

let lit_value = function LitVal v | RegVal v -> v

let is_literal = function
	| LitVal _ -> true
	| RegVal _ -> false

let rec write_expr (ident: ident) = function
	| Literal lit ->
		let lit = get_literal lit in
		let _ = match lit with
			| LitVal lit -> dinstr LOAD (Stack.length regs) lit;
			| _ -> failwith "1"
		in
		Stack.push regs (Stack.length regs, ident.name);
		Stack.length regs - 1
	| Ident { name; kind } ->
		let reg = match Stack.find regs ~f:(fun (_, n) -> String.compare n name = 0) with
			| Some reg -> reg
			| None -> failwith (sprintf "Couldn't find %s" name)
		in fst reg
	| FunExpr { params; decls; body } ->
		write_fun_expr params decls body;
		Stack.length regs
	| FunCall (ident, args) when length args = 2 ->
		let args =
			map args ~f:(function
				| Literal lit when is_literal (get_literal lit) -> get_literal lit
				| arg -> RegVal (write_expr (kident "" KInfer) arg))
			|> (function (* Fix (lit, reg) to (reg, lit) *)
				| [LitVal a; RegVal b] -> [RegVal b; LitVal a]
				| other -> other)
		in
		let litc = count args ~f:(function LitVal _ -> true | _ -> false) in
		let args = map args ~f:lit_value in
		let op = match ident.name with
			| "+" -> (match litc with 0 -> ADDRR | 1 -> ADDRL | _ -> ADDLL)
			| "-" -> (match litc with 0 -> SUBRR | 1 -> SUBRL | _ -> SUBLL)
			| "*" -> (match litc with 0 -> MULRR | 1 -> MULRL | _ -> MULLL)
			| "/" -> (match litc with 0 -> DIVRR | 1 -> DIVRL | _ -> DIVLL)
			| "^" -> (match litc with 0 -> POWRR | 1 -> POWRL | _ -> POWLL)
			| _ -> failwith "fc"
		in
		begin match args with
		| [_] -> failwith "unary"
		| lhs::rhs::[] ->
			tinstr op (Stack.length regs) lhs rhs;
			Stack.push regs (Stack.length regs, ident.name);
			Stack.length regs - 1
		| _ -> failwith "CALL"
		end
	| e -> failwith (sprintf "Failed to write expr: %s" (string_of_expr e))

and write_fun_expr params decls body =
	frame := Stack.length regs;
	write_decl_list decls

and write_decl_list decls =
	iter decls ~f:(fun { ident; expr } -> write_expr ident expr |> ignore)

and write_global_val { ident; expr } =
	match expr with
	| Literal lit -> failwith (sprintf "Failed to write global literal: %s" (string_of_literal lit))
	| expr -> write_expr ident expr

and write_globals = function
	| VarDecl  kvar  -> write_global_val kvar |> ignore
	| TypeDecl ktype -> failwith "type"

let gen output ast =
	iter ast ~f:write_globals;
	write_file output 1l
