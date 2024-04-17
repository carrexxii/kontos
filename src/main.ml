open Core
open Lexing
open Ast

let col_num pos =
	(pos.pos_cnum - pos.pos_bol) - 1

let pos_string pos =
	let l = string_of_int pos.pos_lnum
	and c = string_of_int (col_num pos + 1) in
	"line " ^ l ^ ", column " ^ c

let parse' parser s =
	let lexbuf = Lexing.from_channel s in
	try parser Lexer.read lexbuf
	with Parser.Error ->
		raise (Failure ("Parse error at " ^ (pos_string lexbuf.lex_curr_p)))

let parse_ast s =
	parse' Parser.ast s

let () =
	In_channel.create "tests/test.kon"
	|> parse_ast
	|> string_of_ast
	|> print_endline
