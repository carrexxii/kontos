import std/[with, logging], compat, config
from std/os        import `/`
from std/strformat import `&`
from sdl     import Window
from sdl/gpu import Device
export compat, config, with, `/`, `&`

const BuildKind* = if defined Release: "Release" elif defined Debug: "Debug" else: "Testing"

const
    FontDir*   = "res/fonts"
    ShaderDir* = "res/shaders"
    ModelDir*  = "res/models"

#[ -------------------------------------------------------------------- ]#

var window*: Window
var device*: Device

#[ -------------------------------------------------------------------- ]#

const LoggerFormatString = "$time "
const LoggerThreshhold   = lvlAll
let console_logger = new_console_logger(fmt_str = LoggerFormatString, level_threshold = LoggerThreshhold)
let file_logger    = new_file_logger("log.txt", fmt_str = LoggerFormatString, level_threshold = LoggerThreshhold, mode = fmWrite)

add_handler console_logger
add_handler file_logger

proc log(lvl: Level; prefix, msg: string) =
    try:
        console_logger.log lvl, prefix, msg
    except:
        when not defined Release:
            assert false, "Logging failed for: " & msg
        else:
            discard

proc debug* (msg: string) = log lvlDebug , "\e[34m[Debug]\e[0m ", msg
proc info*  (msg: string) = log lvlInfo  , "\e[32m[Info ]\e[0m ", msg
proc notice*(msg: string) = log lvlNotice, "\e[36m[Note ]\e[0m ", msg
proc warn*  (msg: string) = log lvlWarn  , "\e[33m[Warn ]\e[0m ", msg
proc error* (msg: string) = log lvlError , "\e[35m[Error]\e[0m ", msg
proc fatal* (msg: string) = log lvlFatal , "\e[31m[Fatal]\e[0m ", msg
