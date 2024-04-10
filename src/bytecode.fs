module Bytecode

open Ast

type BytecodeOp =
    | Push
    | Call
let stringOfOp = function
    | Push -> "push"
    | Call -> "call"

let rec outputExpr = function
    | IntLit x -> printfn $"push {x}"
    | FltLit x -> printfn $"push {x}"
    | StrLit x -> printfn $"push \"{x}\""
    | FunCall (ident, exprs) ->
        List.iter (fun expr -> outputExpr expr) exprs
        printfn $"call {ident}"
    | x -> failwith $"ouputExpr not implemented for \"{x}\""

let outputAssign ident expr =
    printfn $"[ASSI] {ident} = {expr}"

let outputFun ident expr =
    // printfn $"[FUNC] {ident}"
    outputExpr expr

let outputStmt = function
    | Assign (ident, expr) -> outputAssign ident expr
    | FunStmt (Function (ident, expr)) -> outputFun ident expr

let ofAst (ast: Stmt list) =
    List.iter outputStmt ast
