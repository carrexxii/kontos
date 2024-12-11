import std/[os, osproc], common
from std/strutils import strip

const NaiPath = "lib/nai/nai"

proc convert*(dst, src: string) =
    let dst = dst.add_file_ext ".nai"

    let cmd = &"{NaiPath} c {src} -f -o:{dst}"
    var (res, code) = exec_cmd_ex cmd
    if code != 0:
        # TODO
        error &"Failed to convert file '{src}': ({strip cmd})\n{res}"
    else:
        info &"Converted file '{src}' to Nai file ({dst})"

proc load_model*(path: string) =
    discard
