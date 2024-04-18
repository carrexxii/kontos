open Core
open Ast

let parse' parser s =
	let lexbuf = Lexing.from_channel s in
	try parser Lexer.read lexbuf
	with Parser.Error ->
		raise (Failure ("Parse error at " ^ (Lexer.position lexbuf)))

let parse_ast s =
	parse' Parser.ast s

let () =
	let ast =
		In_channel.create "tests/syntax-test.kon"
		|> parse_ast
	in
	ast
	|> string_of_ast
	|> print_endline

	;print_endline "\n- - - - - - - - ";
	Genc.gen "tests/test.c" ast
