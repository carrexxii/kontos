open Core
open Printf
open Ast

let compile fname =
	let file   = In_channel.create fname in
	let lexbuf = Lexing.from_channel file in
	let parser = Parser.ast in
	Lexer.set_filename fname lexbuf;
	let ast =
		try parser Lexer.read lexbuf
		with Parser.Error ->
			raise (Failure ("Parse error at " ^ (Lexer.position lexbuf)))
	in

	Types.check ast
	|> string_of_ast
	|> print_endline

	;print_endline ("\n- - - - - - - - " ^ fname);
	let ast = Types.check ast in
	Codegen.gen (fname ^ "b") ast
	(* Genc.gen (fname ^ ".c") ast *)

let () =
	let command =
		Command.basic
			~summary:"Kontos compiler"
			~readme:(fun () -> "")
			(let%map_open.Command
				fname = anon ("filename" %: string)
			in fun () -> compile fname)
	in Command_unix.run ~version:"0.0" ~build_info:"" command
