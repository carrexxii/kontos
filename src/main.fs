module Main

open System
open FSharp.Text.Lexing
open Lexer
open Parser

let evaluate input =
    let lexBuf = LexBuffer<char>.FromString input
    let output = Parser.parse Lexer.tokenize lexBuf
    string output

[<EntryPoint>]
let main argv =
    while true do
        printf "Evaluate > "
        let input = Console.ReadLine ()
        try
            printfn $"{evaluate input}"
        with err -> printfn $"{err}"

    0
