module Ast

type Program = Stmt list

and Stmt =
    | Assign  of string * Expr
    | FunStmt of Function
    | ValStmt of string * KType * Expr

and Expr =
    | IntLit  of int64
    | FltLit  of float
    | StrLit  of string
    | FunExpr of Function
    | FunCall of string * (Expr list)
    | Case    of Expr * (Guard list)

and Function = Function of string * Expr

and Guard = Expr * Expr

and KType =
    | KInt
    | KReal
    | KBool
    | KUnit
    | KString
    | KNone
    | KCustom of string
