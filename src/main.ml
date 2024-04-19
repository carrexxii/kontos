open Core
open Printf
open Ast

let compile backend fname =
	let _ = match String.lowercase backend with
			| "c" -> ()
			| _ ->
				eprintf "Unknown backend \"%s\" (Should be one of: c)\n" backend;
				exit 1
	in

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

	;print_endline "\n- - - - - - - - ";
	let ast = Types.check ast in
	Genc.gen (fname ^ ".c") ast

let () =
	let command =
		Command.basic
			~summary:"Kontos compiler"
			~readme:(fun () -> "")
			(let%map_open.Command
				fname   = anon ("filename" %: string)
			and backend = flag "-b" (optional_with_default "c" string) ~doc:""
			in fun () -> compile backend fname)
	in Command_unix.run ~version:"0.0" ~build_info:"" command
