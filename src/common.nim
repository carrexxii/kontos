import std/[with, logging], compat
from std/os        import `/`
from std/strformat import `&`
export compat, with, `/`, `&`

const
    FontDir*   = "res/fonts"
    ShaderDir* = "res/shaders"

#[ -------------------------------------------------------------------- ]#

const LoggerFormatString = "$time "
const LoggerThreshhold   = lvlAll
let console_logger = new_console_logger(fmt_str = LoggerFormatString, level_threshold = LoggerThreshhold)
let file_logger    = new_file_logger("log.txt", fmt_str = LoggerFormatString, level_threshold = LoggerThreshhold, mode = fmWrite)

add_handler console_logger
add_handler file_logger

proc debug* (msg: string) = console_logger.log lvlDebug , "\e[34m[Debug]\e[0m ", msg
proc info*  (msg: string) = console_logger.log lvlInfo  , "\e[32m[Info ]\e[0m ", msg
proc notice*(msg: string) = console_logger.log lvlNotice, "\e[36m[Note ]\e[0m ", msg
proc warn*  (msg: string) = console_logger.log lvlWarn  , "\e[33m[Warn ]\e[0m ", msg
proc error* (msg: string) = console_logger.log lvlError , "\e[35m[Error]\e[0m ", msg
proc fatal* (msg: string) = console_logger.log lvlFatal , "\e[31m[Fatal]\e[0m ", msg
