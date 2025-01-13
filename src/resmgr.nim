{.warning[ImplicitDefaultValue]:off.}
{.push raises: [].}

import
    std/[os, osproc, streams, tables],
    sdl, sdl/gpu, nai, ngm,
    common

const
    NaiPath = "lib/nai/nai"

    MaxMeshCount     = 8
    MaxMaterialCount = 8

type
    ResourceKind = enum
        rkShader
        rkModel
    Resource = object
        case kind: ResourceKind
        of rkShader: shader: Shader
        of rkModel : mdl   : ref Model

    TileData* = uint32

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

var resources = init_table[string, Resource]()

template try_read(file: FileStream; dst: untyped) =
    try:
        file.read dst
    except OsError, IoError:
        const dst_sz {.inject.} = sizeof dst
        error &"Error reading ({dst_sz}B) from file '{path}' ({get_current_exception().msg})"
        return

template try_read_data(file: FileStream; dst: pointer; sz: int) =
    try:
        let req_sz {.inject.} = sz
        let read_sz {.inject.} = file.read_data(dst, sz)
        if read_sz != sz:
            raise new_exception(IoError, &"{read_sz} != {req_sz}")
    except OsError, IoError:
        let req_sz {.inject.} = sz
        error &"Error reading {req_sz}B from file '{path}' ({get_current_exception().msg})"
        return

template try_close(file: FileStream) =
    try:
        close file
    except OsError, IoError:
        error &"Failed to close file '{path}' ({get_current_exception().msg})"

proc convert*(dst, src: string) =
    let dst = dst.add_file_ext ".nai"

    let cmd = &"{NaiPath} c {src} -f -o:{dst}"
    var (res, code) = try:
        exec_cmd_ex cmd
    except OsError, IoError:
        error &"Failed to excute conversion command '{cmd}' ({src} -> {dst}) ({get_current_exception().msg})"
        return

    info &"Converted file '{src}' to Nai file ({dst})"

proc load_shader*(name: string; sampler_cnt, storage_tex_cnt, sbo_cnt, ubo_cnt = 0): Shader =
    let path = ShaderDir / (name & ".spv")
    if name in resources:
        {.cast(raises: []).}:
            let res = resources[name]
        if res.kind != rkShader:
            error &"Resource '{name}' ({path}) already exists but has kind `{res.kind}` (expected `{rkShader}`)"
        return res.shader

    let (_, fname, ext) = split_file name
    let stage = case ext
    of ".vertex"  , ".vert", ".vtx", ".vs": shaderVertex
    of ".fragment", ".frag", ".frg", ".fs": shaderFragment
    else:
        error &"Could not determine shader kind from extension '{ext}' for '{name}' ({path})"
        return

    result = try:
        device.create_shader_from_file(stage, path,
            sampler_cnt     = sampler_cnt,
            storage_tex_cnt = storage_tex_cnt,
            storage_buf_cnt = sbo_cnt,
            uniform_buf_cnt = ubo_cnt,
        )
    except IoError:
        error &"Failed to load shader '{name}'"
        cast[Shader](nil)
    resources[name] = Resource(kind: rkShader, shader: result)
    debug &"Loaded shader '{name}' ({path})"

proc load_model*(path: string): ref Model =
    if path in resources:
        {.cast(raises: []).}:
            let res = resources[path]
        if res.kind != rkModel:
            error &"Resource for path '{path}' already exists but has kind `{res.kind}` (expected `{rkModel}`)"
        return res.mdl

    result = new Model
    var header: Header
    let file = try:
        open_file_stream path
    except IoError as exn:
        error &"Failed to open file stream for '{path}' ({exn.msg})"
        return
    let fname = (split_file path)[1]

    file.try_read header
    let header_errs = header.validate [mvBaseColour]
    if header_errs.len > 0:
        for err in header_errs:
            error err

    var vtxs: seq[ModelVertex] = @[]
    var idxs: seq[uint32]      = @[]
    var mesh_header: MeshHeader
    for i in 0'u16..<header.mesh_cnt:
        file.try_read mesh_header
        result.meshes[i].vtx_cnt = mesh_header.idx_cnt
        result.meshes[i].fst_idx = uint32 idxs.len
        result.meshes[i].mtl_idx = mesh_header.mtl_idx

        let vtx_sz = (int mesh_header.vtx_cnt) * sizeof ModelVertex
        vtxs.set_len_uninit (vtxs.len + int mesh_header.vtx_cnt)
        file.try_read_data vtxs[vtxs.len - int mesh_header.vtx_cnt].addr, vtx_sz

        let idx_sz = (int mesh_header.idx_cnt) * mesh_header.idx_sz
        idxs.set_len_uninit (idxs.len + int mesh_header.idx_cnt)
        file.try_read_data idxs[idxs.len - int mesh_header.idx_cnt].addr, idx_sz

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
        file.try_read mtl_header
        file.try_read result.mtls[i].base_colour
        for j in 0'u16..<mtl_header.tex_cnt:
            file.try_read tex_header
            let tex_sz = tex_header.size
            let pxs = alloc tex_sz
            file.try_read_data pxs, tex_sz

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
    try_close file

    resources[path] = Resource(kind: rkModel, mdl: result)
    debug &"Loaded model '{path}' with {vtxs.len} vertices/{idxs.len} indices"

proc cleanup*() =
    info "Cleaning up resources..."
    for res in resources.values:
        case res.kind
        of rkShader:
            device.destroy res.shader
        of rkModel:
            device.destroy res.mdl.vbo
            device.destroy res.mdl.ibo
            for mtl in res.mdl.mtls:
                if mtl.diffuse:
                    device.destroy mtl.diffuse

    clear resources

{.pop.} # raises: []
