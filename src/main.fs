module Main

open System
open FSharp.Text
open FSharp.Text.Lexing
open Lexer
open Parser

[<EntryPoint>]
let main argv =
    let testFile = IO.File.ReadAllText "tests/test.kon"
    let lexbuf = LexBuffer<char>.FromString testFile
    while not lexbuf.IsPastEndOfStream do
        printfn $"({tokenize lexbuf}) "

    0
