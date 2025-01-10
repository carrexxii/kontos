import sdl, sdl/gpu

const
    ShaderFormat* = shaderFmtSpirV
    SdlInitFlags* = initVideo or initEvents

    WindowTitle* {.strdefine.} = "Kontos"

var window_size* = (w: 1280, h: 800)
