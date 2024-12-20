import common, sdl, sdl/gpu
from std/sequtils import new_seq_with

type
    Tilemap* = object
        w*, h*: uint32
        tiles*: seq[seq[Tile]]

    Tile* = uint8

proc create*(w: Natural; h: Natural): Tilemap =
    result = Tilemap(
        w: uint32 w,
        h: uint32 h,
        tiles: new_seq_with(h, new_seq[Tile] w),
    )
    info &"Created new tilemap ({w}x{h} = {result.w*result.h} tiles)"
