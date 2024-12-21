import
    std/[options, os],
    sdl, sdl/gpu, nuklear as nk, ngm,
    common, project, resmgr

const
    CommandBufferSize = 128*1024
    VertexBufferSize  = 1536*1024
    IndexBufferSize   = 512*1024
    FontSizeSmall  = 16
    FontSizeMedium = 24
    FontSizeLarge  = 32

type Vertex = object
    pos   : array[2, float32]
    uv    : array[2, float32]
    colour: array[4, uint8]

let 
    VertexLayout = create_vertex_layout(
        (dvlaPosition, dvlfFloat   , Vertex.offsetof pos),
        (dvlaTexCoord, dvlfFloat   , Vertex.offsetof uv),
        (dvlaColour  , dvlfR8G8B8A8, Vertex.offsetof colour),
    )
    VertexConfig = ConvertConfig(
        shape_aa        : aaOn,
        line_aa         : aaOn,
        vtx_layout      : VertexLayout[0].addr,
        vtx_sz          : uint sizeof Vertex,
        vtx_align       : uint alignof Vertex,
        circle_seg_count: 22,
        curve_seg_count : 22,
        arc_seg_count   : 22,
        global_alpha    : 1.0,
        # tex_null        : null_tex,
    )

var
    context*: Context

    atlas     : FontAtlas
    font_tex  : Texture
    small_font: ptr Font
    pipeln    : GraphicsPipeline
    sampler   : Sampler
    sdl_trans : TransferBuffer
    sdl_vtxs  : gpu.Buffer
    sdl_idxs  : gpu.Buffer
    nk_cmds   : nk.Buffer
    nk_vtxs   : nk.Buffer
    nk_idxs   : nk.Buffer

proc init*() =
    let vtx_shader  = load_shader("ui.vert", ubo_cnt = 1)
    let frag_shader = load_shader("ui.frag", sampler_cnt = 1)
    let ct_descr = ColourTargetDescription(
        fmt: device.swapchain_tex_fmt window,
        blend_state: ColourTargetBlendState(
            src_colour_blend_factor : blendFacSrcAlpha,
            dst_colour_blend_factor : blendFacOneMinusAlpha,
            colour_blend_op         : blendAdd,
            src_alpha_blend_factor  : blendFacSrcAlpha,
            dst_alpha_blend_factor  : blendFacOneMinusAlpha,
            alpha_blend_op          : blendAdd,
            colour_write_mask       : colourCompNone,
            enable_blend            : true,
            enable_colour_write_mask: false,
        ),
    )
    pipeln = device.create_graphics_pipeline(vtx_shader, frag_shader,
        vertex_input_state(
            [vtx_descr(0, sizeof Vertex, inputVertex)],
            [vtx_attr(0, 0, vtxElemFloat2, Vertex.offsetof pos),
             vtx_attr(1, 0, vtxElemFloat2, Vertex.offsetof uv),
             vtx_attr(2, 0, vtxElemUByte4, Vertex.offsetof colour)],
        ),
        target_info = GraphicsPipelineTargetInfo(
            colour_target_descrs    : ct_descr.addr,
            colour_target_cnt       : 1,
            depth_stencil_fmt       : texFmtD16Unorm,
            has_depth_stencil_target: true,
        ),
        depth_stencil_state = DepthStencilState(
            compare_op         : cmpGreaterOrEqual,
            back_stencil_state : StencilOpState(),
            front_stencil_state: StencilOpState(),
            compare_mask       : 0x00,
            write_mask         : 0xFF,
            enable_depth_test  : true,
            enable_depth_write : true,
            enable_stencil_test: false,
        ),
    )

    sampler   = device.create_sampler()
    sdl_trans = device.create_transfer_buffer (VertexBufferSize + IndexBufferSize)
    sdl_vtxs  = device.create_buffer(bufUsageVertex, VertexBufferSize, "UI Vertices")
    sdl_idxs  = device.create_buffer(bufUsageIndex , IndexBufferSize , "UI Indices")

    device.set_tex_name font_tex, "UI Font Atlas"

    # Nuklear
    nk_cmds = create_buffer CommandBufferSize
    nk_vtxs = create_buffer VertexBufferSize
    nk_idxs = create_buffer IndexBufferSize

    const char_ranges = [
        Rune 0x0020, Rune 0x007E,
        Rune 0
    ]
    let font_file = read_file(FontDir / "PixeloidSans-Bold.ttf")
    var font_cfg = nk_font_config FontSizeSmall
    with font_cfg:
        ttf_blob     = font_file[0].addr
        ttf_sz       = uint font_file.len
        oversample_h = 1
        oversample_v = 1
        range        = char_ranges[0].addr

    init atlas
    begin atlas
    small_font = atlas.add font_cfg
    let (atlas_pxs, atlas_w, atlas_h) = bake atlas
    font_tex = device.upload(atlas_pxs, atlas_w, atlas_h, fmt = texFmtA8Unorm)
    `end` atlas, pointer font_tex
    `=destroy` atlas

    init context, small_font
    info "Initialized UI"

proc cleanup*() =
    debug "Cleaning up UI..."
    with device:
        destroy sdl_trans
        destroy sdl_vtxs
        destroy sdl_idxs
        destroy font_tex
        destroy sampler
        destroy pipeln

proc add_objects(paths: seq[string]) =
    let ppath = project.get_path()
    let root  = (split_file ppath)[0]
    for path in paths:
        let (dir, name, ext) = split_file path
        case ext
        of ".nai":
            discard
            # load_model path
        else:
            if file_exists ppath:
                let output = root / "res/models" / &"{name}.nai"
                convert output, path
            else:
                let src = path
                save_file_dialog (proc(dst: string) = convert dst, src), default_loc = ppath

proc update*(cmd_buf: gpu.CommandBuffer) =
    let w = window_size.x
    let h = window_size.y
    let sb_w = 0.3 * cfloat w
    context.begin nk.Rect(x: (cfloat w) - sb_w, y: 0, w: sb_w, h: cfloat h), winBorder
    context.min_row_height = 100

    context.menubar 35, (40, 30):
        "File":
            "Add":
                open_file_dialog add_objects, default_loc = project.get_path()
            "Quit":
                quit 0
        "Project":
            "Load":
                open_file_dialog project.load, default_loc = project.get_path()
            "Save":
                if not project.save():
                    error "Error saving" # TODO
            "Save As":
                save_file_dialog project.save_as, default_loc = project.get_path()
    
    context.convert VertexConfig, nk_cmds, nk_vtxs, nk_idxs

    var buf_dst = device.map sdl_trans
    copy_mem buf_dst, nk_vtxs.mem.mem, nk_vtxs.sz
    buf_dst = cast[pointer](cast[uint](buf_dst) + nk_vtxs.sz)
    copy_mem buf_dst, nk_idxs.mem.mem, nk_idxs.sz
    device.unmap sdl_trans

    `end` context
    clear context

    let copy_pass = begin_copy_pass cmd_buf
    with copy_pass:
        upload sdl_trans, sdl_vtxs, nk_vtxs.sz, cycle = true
        upload sdl_trans, sdl_idxs, nk_idxs.sz, cycle = true, trans_buf_offset = nk_vtxs.sz
        `end`

let ui_projection = orthogonal(0, 1280, 800, 0, 0.1, 1.0)
proc draw*(ren_pass: RenderPass; cmd_buf: gpu.CommandBuffer) =
    cmd_buf.push_vtx_uniform 0, ui_projection
    with ren_pass:
        `bind` pipeln
        `bind` 0, [TextureSamplerBinding(tex: font_tex, sampler: sampler)]
        `bind` 0, [BufferBinding(buf: sdl_vtxs)]
        `bind` BufferBinding(buf: sdl_idxs), elemSz16

    var offset = 0'u32
    for cmd in context.commands nk_cmds:
        if cmd.tex:
            ren_pass.`bind` 0, [TextureSamplerBinding(tex: cmd.tex, sampler: sampler)]
        let r = cmd.clip_rect
        ren_pass.scissor = some sdl.Rect(x: max(cint r.x, 0), y: max(cint r.y, 0),
                                         w: max(cint r.w, 0), h: max(cint r.h, 0))
        ren_pass.draw_indexed cmd.elem_count, fst_idx = offset
        offset += cmd.elem_count
    ren_pass.scissor = none sdl.Rect
    clear nk_cmds, nk_vtxs, nk_idxs
