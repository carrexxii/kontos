import sdl/gpu, nuklear as nk

converter `nk.Handle -> gpu.Texture`*(h: Handle): Texture = cast[Texture](h.p)
