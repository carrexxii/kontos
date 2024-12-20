import sdl, sdl/gpu
from ngm import IVec2, `.`
export ngm.`.`

const
    ShaderFormat* = shaderFmtSpirV
    SdlInitFlags* = initVideo or initEvents

    WindowTitle* {.strdefine.} = "Kontos"

var window_size*: IVec2 = [1280, 800]
