import
    std/[os, osproc, streams, tables],
    sdl, sdl/gpu, nai, ngm,
    common
from std/strutils import strip

const
    NaiPath = "lib/nai/nai"

    MaxMeshCount     = 8
    MaxMaterialCount = 8

type
    ResourceKind = enum
        rkModel
    Resource = object
        case kind: ResourceKind
        of rkModel: mdl: ref Model

    ModelVertex* = object
        pos*   : Vec3
        normal*: Vec3
        uv*    : Vec2

    Model* = object
        vbo*   : Buffer
        ibo*   : Buffer
        meshes*: array[MaxMeshCount    , Mesh]
        mtls*  : array[MaxMaterialCount, Material]

    Mesh* = object
        vtx_cnt*: uint32
        fst_idx*: uint32
        mtl_idx*: uint32

    Material* = object
        diffuse*    : Texture
        base_colour*: Vec4

var models = init_table[string, ref Model]()

var model_pipeln: GraphicsPipeline

proc convert*(dst, src: string) =
    let dst = dst.add_file_ext ".nai"

    let cmd = &"{NaiPath} c {src} -f -o:{dst}"
    var (res, code) = exec_cmd_ex cmd
    if code != 0:
        # TODO
        error &"Failed to convert file '{src}': ({strip cmd})\n{res}"
    else:
        info &"Converted file '{src}' to Nai file ({dst})"

proc load_model*(path: string): ref Model =
    result = new Model
    let file  = open_file_stream path
    let fname = (split_file path)[1]

    var header: Header
    file.read header
    let header_errs = header.validate [mvBaseColour]
    if header_errs.len > 0:
        for err in header_errs:
            error err

    var vtxs: seq[ModelVertex]
    var idxs: seq[uint32]
    var mesh_header: MeshHeader
    for i in 0'u16..<header.mesh_cnt:
        file.read mesh_header
        result.meshes[i].vtx_cnt = mesh_header.idx_cnt
        result.meshes[i].fst_idx = uint32 idxs.len
        result.meshes[i].mtl_idx = mesh_header.mtl_idx

        let vtx_sz = (int mesh_header.vtx_cnt) * sizeof ModelVertex
        vtxs.set_len_uninit (vtxs.len + int mesh_header.vtx_cnt)
        if file.read_data(vtxs[vtxs.len - int mesh_header.vtx_cnt].addr, vtx_sz) != vtx_sz:
            error &"Failed reading vertex data from model file '{path}'"

        let idx_sz = (int mesh_header.idx_cnt) * mesh_header.idx_sz
        idxs.set_len_uninit (idxs.len + int mesh_header.idx_cnt)
        if file.read_data(idxs[idxs.len - int mesh_header.idx_cnt].addr, idx_sz) != idx_sz:
            error &"Failed reading index data from model file '{path}'"

    let vtxs_sz = vtxs.len * sizeof ModelVertex
    let idxs_sz = idxs.len * is32Bit
    let trans_buf = device.create_transfer_buffer (vtxs_sz + idxs_sz)
    result.vbo = device.create_buffer(bufUsageVertex, vtxs_sz, &"{fname} Vertices ({path})")
    result.ibo = device.create_buffer(bufUsageIndex , idxs_sz, &"{fname} Indices ({path})")

    # Copy mesh data to buffers
    let vtxs_dst = device.map trans_buf
    copy_mem vtxs_dst, vtxs[0].addr, vtxs_sz
    let idxs_dst = cast[pointer](cast[int](vtxs_dst) + vtxs_sz)
    copy_mem idxs_dst, idxs[0].addr, idxs_sz
    device.unmap trans_buf

    # Copy textures
    var mtl_header: MaterialHeader
    var tex_header: TextureHeader
    for i in 0'u16..<header.mtl_cnt:
        file.read mtl_header
        file.read result.mtls[i].base_colour
        for j in 0'u16..<mtl_header.tex_cnt:
            file.read tex_header
            let tex_sz = tex_header.size
            let pxs = alloc tex_sz
            if file.read_data(pxs, tex_sz) != tex_sz:
                error &"Failed to read all data for texture from '{path}'"

            let tex = device.upload(pxs, tex_header.w, tex_header.h, fmt = texFmtR8G8B8A8Unorm)
            case tex_header.kind
            of tkDiffuse: result.mtls[i].diffuse = tex
            else:
                error &"Unsupported texture kind '{tex_header.kind}'"

            device.set_tex_name tex, &"{fname} {($tex_header.kind)[2..^1]}"
            dealloc pxs

    let cmd_buf   = acquire_cmd_buf device
    let copy_pass = begin_copy_pass cmd_buf
    with copy_pass:
        upload trans_buf, result.vbo, vtxs_sz
        upload trans_buf, result.ibo, idxs_sz, trans_buf_offset = vtxs_sz
        `end`
    submit cmd_buf

    device.destroy trans_buf
    close file
    models[path] = result

    debug &"Loaded model '{path}' with {vtxs.len} vertices/{idxs.len} indices"

proc cleanup*() =
    info "Cleaning up resources..."
    for mdl in models.values:
        device.destroy mdl.vbo
        device.destroy mdl.ibo
        for mtl in mdl.mtls:
            if mtl.diffuse:
                device.destroy mtl.diffuse
