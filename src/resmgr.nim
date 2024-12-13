import
    std/[os, osproc, streams, tables],
    sdl, sdl/gpu, nai,
    common, model
from std/strutils import strip

const NaiPath = "lib/nai/nai"

type
    ResourceKind = enum
        rkModel
    Resource = object
        case kind: ResourceKind
        of rkModel: mdl: ref Model

var models = init_table[string, ref Model]()

proc convert*(dst, src: string) =
    let dst = dst.add_file_ext ".nai"

    let cmd = &"{NaiPath} c {src} -f -o:{dst}"
    var (res, code) = exec_cmd_ex cmd
    if code != 0:
        # TODO
        error &"Failed to convert file '{src}': ({strip cmd})\n{res}"
    else:
        info &"Converted file '{src}' to Nai file ({dst})"

proc load_model*(dev: Device; path: string): ref Model =
    let file  = open_file_stream path
    let fname = (split_file path)[1]

    var header: Header
    file.read header
    let header_errs = header.validate [mvBaseColour]
    if header_errs.len > 0:
        for err in header_errs:
            error err

    var vtxs: seq[Vertex]
    var idxs: seq[uint32]
    var mesh_header: MeshHeader
    for i in 0'u16..<header.mesh_cnt:
        file.read mesh_header

        let vtx_sz = (int mesh_header.vtx_cnt) * sizeof Vertex
        vtxs.set_len_uninit (vtxs.len + int mesh_header.vtx_cnt)
        if file.read_data(vtxs[vtxs.len - int mesh_header.vtx_cnt].addr, vtx_sz) != vtx_sz:
            error &"Failed reading vertex data from model file '{path}'"

        let idx_sz = (int mesh_header.idx_cnt) * mesh_header.idx_sz
        idxs.set_len_uninit (idxs.len + int mesh_header.idx_cnt)
        if file.read_data(idxs[idxs.len - int mesh_header.idx_cnt].addr, idx_sz) != idx_sz:
            error &"Failed reading index data from model file '{path}'"

    result = new Model
    let vtxs_sz = vtxs.len * sizeof Vertex
    let idxs_sz = idxs.len * is32Bit # FIXME
    let trans_buf = dev.create_transfer_buffer (vtxs_sz + idxs_sz)
    result.vbo = dev.create_buffer(bufUsageVertex, vtxs_sz, &"{fname} Vertices ({path})")
    result.ibo = dev.create_buffer(bufUsageIndex , idxs_sz, &"{fname} Indices ({path})")

    let vtxs_dst = dev.map trans_buf
    copy_mem vtxs_dst, vtxs[0].addr, vtxs_sz
    let idx_dst = cast[pointer](cast[int](vtxs_dst) + vtxs_sz)
    copy_mem idx_dst, idxs[0].addr, idxs_sz
    dev.unmap trans_buf

    let cmd_buf   = acquire_cmd_buf dev
    let copy_pass = begin_copy_pass cmd_buf
    with copy_pass:
        upload trans_buf, result.vbo, vtxs_sz
        upload trans_buf, result.ibo, idxs_sz, trans_buf_offset = vtxs_sz
        `end`

    dev.destroy trans_buf
    close file
    models[path] = result

proc cleanup*(dev: Device) =
    for mdl in models.values:
        dev.destroy mdl.vbo
        dev.destroy mdl.ibo
