module Ast

type KType =
    | KInt
    | KReal
    | KBool
    | KUnit
    | KString
    | KInferred
    | KCustom of string
and Ident =
    { name : string
      type': KType }

type Expr =
    | NOPExpr
    | Literal   of Literal
    | Ident     of Ident
    | IdentList of Ident list
    | FunExpr   of Fun
and Literal =
    | IntLit of int64
    | FltLit of float
    | StrLit of string
and Stmt =
    | NOPStmt
    | FunStmt of Fun
    | ValStmt of Val
    | VarStmt of Var
and Fun =
    { name  : Ident
      params: Ident list
      body  : Expr list }
and Val =
    { name: Ident
      expr: Expr }
and Var =
    { name: Ident
      expr: Expr }

type Program = Stmt list

///////////////////////////////////////////////////////////////////////

let ident name type' =
    { name  = name
      type' = type' }

let fun' name params body rtype =
    { name   = ident name rtype
      params = params
      body   = body }

let val' name type' expr =
    { name = ident name type'
      expr = expr }: Val

let var name type' expr =
    { name = ident name type'
      expr = expr }: Var
