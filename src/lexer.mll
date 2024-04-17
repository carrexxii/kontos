{
    open Lexing
    open Parser

    exception SyntaxError of string

	let advance_line lexbuf =
		let pos = lexbuf.lex_curr_p in
		let pos' =
			{ pos with
				pos_bol  = lexbuf.lex_curr_pos;
				pos_lnum = pos.pos_lnum + 1 }
		in lexbuf.lex_curr_p <- pos'
}

let digit = ['0'-'9']
let alpha = ['a'-'z' 'A'-'Z']
let alnum = alpha | digit

let integer     = '-'? digit+
let float       = '-'? digit+ '.' digit+
let binary      = '0' 'b' digit+
let hexadecimal = '0' 'x' digit+

let identifier = alpha (alnum | ['_' '-' '''])*
let whitespace = [' ' '\t']
let newline    = '\n' | '\r' '\n'

rule read = parse
    | whitespace      { read lexbuf }
    | newline         { advance_line lexbuf; EOL }
    | '/' '/'         { read_comment lexbuf }
    | float           { FLTLIT (float_of_string (lexeme lexbuf)) }
    | integer         { INTLIT (Int64.of_string (lexeme lexbuf)) }

	| "val"           { VAL   }

	| '='             { EQUALS }

    | identifier      { IDENT (lexeme lexbuf) }
    | eof             { EOF }
	| _  { raise (SyntaxError ("Illegal character: " ^ lexeme lexbuf)) }
and read_string str ignore_quote = parse
    | '"'           { if ignore_quote then (read_string (str ^ "\\\"") false lexbuf) else STRLIT str }
    | '\\'          { read_string str true lexbuf                                                    }
    | [^ '"' '\\']+ { read_string (str ^ (lexeme lexbuf)) false lexbuf                               }
    | eof           { raise (SyntaxError "Error: non-terminated string literal")                     }
and read_comment = parse
    | newline { advance_line lexbuf; EOL }
    | eof     { EOF                      }
    | _       { read_comment lexbuf      }
