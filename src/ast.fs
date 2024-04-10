module Ast

type Program = Stmt list

and Stmt =
    | Assign  of string * Expr
    | FunStmt of Function

and Expr =
    | IntLit  of int64
    | FltLit  of float
    | StrLit  of string
    | FunExpr of Function
    | FunCall of string * (Expr list)

and Function = Function of string * Expr
