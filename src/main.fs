module Main

open System.IO
open FSharp.Text
open FSharp.Text.Lexing

let lex =
    LexBuffer<_>.FromTextReader

let parse lexbuf =
    try Parser.start Lexer.tokenize lexbuf
    with exn ->
        let pos = lexbuf.EndPos
        let tk  = System.String lexbuf.Lexeme
        printfn $"Parse failed at line {pos.Line + 1}, column {pos.Column}:"
        printfn $"Last token: \"{tk}\""
        printfn $"\t{exn.Message}"
        exit 1

let testLexer () =
    use reader = new StreamReader "tests/test.kon"
    let lexbuf = lex reader
    while not lexbuf.IsPastEndOfStream do
        printfn $"({Lexer.tokenize lexbuf})"

let testParser () =
    new StreamReader "tests/test.kon"
    |> lex
    |> parse
    |> List.rev
    |> List.iter (fun x -> printfn $"{x}")

[<EntryPoint>]
let main argv =
    testLexer ()
    printfn " - - - - - - - - - - - - -"
    testParser ()
    printfn " - - - - - - - - - - - - -"

    // new StreamReader "tests/test.kon"
    // |> lex
    // |> parse
    // |> Bytecode.ofAst

    0
