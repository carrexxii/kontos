{
    open Lexing
    open Parser
	open Printf

    exception SyntaxError of string

	let set_filename fname lexbuf =
		lexbuf.Lexing.lex_curr_p <-
			{ lexbuf.Lexing.lex_curr_p with
		    	Lexing.pos_fname = fname }

	let position lexbuf =
		let p = lexbuf.Lexing.lex_curr_p in
		sprintf "%s:%d:%d" p.pos_fname p.pos_lnum (p.pos_cnum - p.pos_bol)

	let error lexbuf msg =
		let msg = sprintf "%s %s" (position lexbuf) msg in
		raise (SyntaxError msg)

	let advance_line lexbuf =
		let pos = lexbuf.lex_curr_p in
		let pos' =
			{ pos with
				pos_bol  = lexbuf.lex_curr_pos;
				pos_lnum = pos.pos_lnum + 1 }
		in lexbuf.lex_curr_p <- pos'

	let string_buf = Buffer.create 256
}

let digit = ['0'-'9']
let alpha = ['a'-'z' 'A'-'Z']
let alnum = alpha | digit

let integer     = '-'? digit+
let float       = '-'? digit+ '.' digit+
let binary      = '0' 'b' digit+
let hexadecimal = '0' 'x' digit+

let identifier = alpha (alnum | ['_' '''])*
let whitespace = [' ' '\t']
let newline    = '\n' | '\r' '\n'
let escapes    = ['n']

let infix = ['+' '-' '*' '/']
let operator = infix

rule read = parse
    | whitespace+     { read lexbuf }
    | newline         { new_line lexbuf;
	                    read lexbuf }
    | '-' '-'         { read_line_comment  lexbuf }
    | '(' '*'         { read_block_comment lexbuf }

    | float           { FLTLIT (float_of_string (lexeme lexbuf)) }
    | integer         { INTLIT (Int64.of_string (lexeme lexbuf)) }
	| '"'             { Buffer.clear string_buf;
	                    STRLIT (read_string lexbuf) }

	| '(' ')' { UNIT   }
	| '('     { LPAREN }
	| ')'     { RPAREN }
	| '='     { EQUALS }
	| '>'     { GT     }
	| '<'     { LT     }
	| '>' '=' { GTE    }
	| '<' '=' { LTE    }

	| '['     { LBRACKET }
	| ']'     { RBRACKET }
	| '{'     { LBRACE   }
	| '}'     { RBRACE   }
	| '|'     { PIPE     }
	| '-' '>' { RARROW   }
	| '=' '>' { DRARROW  }
	| ','     { COMMA    }
	| ';'     { SEMI     }
	| ':'     { COLON    }
	| infix   { INFIX (lexeme lexbuf) }

	| "int"    { INT    }
	| "real"   { REAL   }
	| "bool"   { BOOL   }
	| "string" { STRING }
	| "list"   { LIST   }
	| "array"  { ARRAY  }
	| "unit"   { UNIT   }

	| "val"   { VAL   }
	| "var"   { VAR   }
	| "fun"   { FUN   }
	| "type"  { TYPE  }
	| "as"    { AS    }
	| "case"  { CASE  }
	| "of"    { OF    }
	| "is"    { IS    }
	| "true"  { TRUE  }
	| "false" { FALSE }

    | identifier { IDENT  (lexeme lexbuf) }
    | eof        { EOF }
	| _  { error lexbuf (sprintf "Illegal character: `%s`" (lexeme lexbuf)) }
and read_string = parse
	| '"'                   { Buffer.contents string_buf }
	| '\\' (escapes as esc) { Buffer.add_char string_buf esc;
	                          read_string lexbuf }
	| _ as c                { Buffer.add_char string_buf c;
	                          read_string lexbuf }
and read_line_comment = parse
    | newline { new_line lexbuf;
	            read lexbuf              }
    | eof     { EOF                      }
    | _       { read_line_comment lexbuf }
and read_block_comment = parse
	| newline { new_line lexbuf;
	            read_block_comment lexbuf }
    | '*' ')' { read lexbuf               }
    | eof     { EOF                       }
    | _       { read_block_comment lexbuf }
