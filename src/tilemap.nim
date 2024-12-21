import common, sdl/gpu
from std/sequtils import new_seq_with

type
    Tilemap* = object
        w*, h*   : uint32
        buf*     : Buffer
        trans_buf: TransferBuffer
        tiles*   : seq[seq[Tile]]

    Tile* = uint32

proc `=destroy`*(map: Tilemap) =
    device.destroy map.trans_buf
    device.destroy map.buf

func buf_sz*(map: Tilemap): int =
    8 + (int map.w)*(int map.h)*sizeof Tile

func `+`(p: pointer; bytes: int): pointer {.inline.} =
    cast[pointer](cast[int](p) + bytes)
func `+=`(p: var pointer; bytes: int) {.inline.} =
    p = p + bytes
proc upload*(map: Tilemap) =
    var dst = cast[pointer](device.map map.trans_buf)
    copy_mem dst, map.addr, 8
    dst += 8
    for row in map.tiles:
        let sz = row.len*sizeof Tile
        copy_mem dst, row[0].addr, sz
        dst += row.len*sizeof Tile
    device.unmap map.trans_buf

    let cmd_buf   = acquire_cmd_buf device
    let copy_pass = begin_copy_pass cmd_buf
    copy_pass.upload map.trans_buf, map.buf, map.buf_sz
    `end` copy_pass
    submit cmd_buf

proc create*(w, h: uint32): Tilemap =
    let sz = buf_sz Tilemap(w: w, h: h)
    result = Tilemap(
        w        : w,
        h        : h,
        buf      : device.create_buffer(bufUsageGraphicsStorage, sz, &"Tilemap Data {w}x{h}"),
        trans_buf: device.create_transfer_buffer sz,
        tiles    : new_seq_with(int h, new_seq[Tile] w),
    )
    for y in 0..<h:
        for x in 0..<w:
            result.tiles[y][x] = Tile ((x*y) mod Tile.high)
    upload result
    info &"Created new tilemap ({w}x{h} = {w*h} tiles)"
