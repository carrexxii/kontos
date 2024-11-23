import
    std/options,
    sdl, sdl/gpu, nuklear as nk, ngm,
    common

const
    CommandBufferSize = 128*1024
    VertexBufferSize  = 1536*1024
    IndexBufferSize   = 512*1024
    FontSizeSmall  = 12
    FontSizeMedium = 16
    FontSizeLarge  = 24

type Vertex = object
    pos   : array[2, float32]
    uv    : array[2, float32]
    colour: array[4, uint8]

const VertexLayout = create_vertex_layout(
    (vtxPosition, fmtFloat   , Vertex.offsetof pos),
    (vtxTexCoord, fmtFloat   , Vertex.offsetof uv),
    (vtxColour  , fmtR8G8B8A8, Vertex.offsetof colour),
)
let VertexConfig = ConvertConfig(
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
    nk_ctx  : Context
    atlas   : FontAtlas
    font_tex: Texture

    pipeln     : GraphicsPipeline
    vtx_shader : Shader
    frag_shader: Shader
    sampler    : Sampler
    vtx_buf    : gpu.Buffer
    idx_buf    : gpu.Buffer
    trans_buf  : TransferBuffer
    nk_cmds    : nk.Buffer
    nk_vtxs    : nk.Buffer
    nk_idxs    : nk.Buffer
    proj       : Mat4

proc init*(dev: Device; win: sdl.Window) =
    proj = orthogonal(0, 1280, 800, 0, 0.1, 1.0)

    vtx_shader  = dev.create_shader_from_file(shaderVertex, ShaderDir / "ui.vert.spv", uniform_buf_count = 1)
    frag_shader = dev.create_shader_from_file(shaderVertex, ShaderDir / "ui.frag.spv", sampler_count = 1)
    let ct_descr = ColourTargetDescription(
        fmt        : swapchain_tex_fmt(dev, win),
        blend_state: ColourTargetBlendState(
            src_colour_blend_factor : blendFacSrcAlpha,
            src_alpha_blend_factor  : blendFacSrcAlpha,
            dst_colour_blend_factor : blendFacOneMinusAlpha,
            dst_alpha_blend_factor  : blendFacOneMinusAlpha,
            colour_blend_op         : blendAdd,
            alpha_blend_op          : blendAdd,
            colour_write_mask       : colourCompNone,
            enable_blend            : true,
            enable_colour_write_mask: false,
        ),
    )
    pipeln = dev.create_graphics_pipeline(vtx_shader, frag_shader,
        vertex_input_state(
            [vtx_descr(0, sizeof Vertex, inputVertex)],
            [vtx_attr(0, 0, vtxElemFloat2, Vertex.offsetof pos),
             vtx_attr(1, 0, vtxElemFloat2, Vertex.offsetof uv),
             vtx_attr(2, 0, vtxElemUByte4, Vertex.offsetof colour)],
        ),
        target_info = GraphicsPipelineTargetInfo(
            colour_target_descrs: ct_descr.addr,
            colour_target_count : 1,
        ),
    )

    sampler   = dev.create_sampler()
    vtx_buf   = dev.create_buffer(bufUsageVertex, VertexBufferSize)
    idx_buf   = dev.create_buffer(bufUsageIndex , IndexBufferSize)
    trans_buf = dev.create_transfer_buffer (VertexBufferSize + IndexBufferSize)

    dev.set_buf_name vtx_buf , "UI Vertices"
    dev.set_tex_name font_tex, "Font Atlas"

    # Nuklear
    nk_cmds = create_buffer CommandBufferSize
    nk_vtxs = create_buffer VertexBufferSize
    nk_idxs = create_buffer IndexBufferSize

    const char_ranges = [
        Rune 0x0020, Rune 0x007E,
        Rune 0
    ]
    let font_file = read_file(FontDir / "IBMPlexMono.ttf")
    var font_cfg = nk_font_config FontSizeSmall
    with font_cfg:
        ttf_blob = font_file[0].addr
        ttf_sz   = uint font_file.len
        # oversample_h = 1
        # oversample_v = 1
        range = char_ranges[0].addr

    nk_font_atlas_init atlas.addr, NimAllocator.addr
    nk_font_atlas_begin atlas.addr
    let font = nk_font_atlas_add(atlas.addr, font_cfg.addr)
    font_cfg.sz = FontSizeMedium
    discard nk_font_atlas_add(atlas.addr, font_cfg.addr)
    font_cfg.sz = FontSizeLarge
    discard nk_font_atlas_add(atlas.addr, font_cfg.addr)

    var atlas_w, atlas_h: int32
    let atlas_pxs = nk_font_atlas_bake(atlas.addr, atlas_w.addr, atlas_h.addr, fontAtlasAlpha8)
    font_tex = dev.upload(atlas_pxs, atlas_w, atlas_h, fmt = texFmtR8Unorm)

    nk_font_atlas_end atlas.addr, pointer font_tex, nil
    nk_font_atlas_cleanup atlas.addr

    assert nk_init(nk_ctx.addr, NimAllocator.addr, font.handle.addr), "Failed to initialize Nuklear"

    # Cleanup
    dev.destroy vtx_shader
    dev.destroy frag_shader

var test_op: int32
proc update*(dev: Device; cmd_buf: gpu.CommandBuffer) =
    assert nk_ctx.addr.nk_begin("Testing", nk.Rect(x: 50, y: 50, w: 220, h: 220), (winBorder or winMovable or winClosable))
    nk_ctx.addr.nk_layout_row_static 30, 80, 1
    if nk_ctx.addr.nk_button_label "button":
        echo "~~~Event"

    nk_ctx.addr.nk_layout_row_dynamic 30, 2
    if nk_ctx.addr.nk_option_label("easy", test_op == 1): test_op = 1
    if nk_ctx.addr.nk_option_label("hard", test_op == 2): test_op = 2

    with nk_ctx.addr:
        nk_layout_row_begin layoutStatic, 30, 2
        nk_layout_row_push 50
        nk_label "Volume: ", cast[TextAlignment](0x11)
        nk_layout_row_push 110
    let f = nk_ctx.slider(0.0, 1.0, 0.1)
    nk_layout_row_end nk_ctx.addr

    nk_ctx.convert VertexConfig, nk_cmds, nk_vtxs, nk_idxs

    var buf_dst = dev.map trans_buf
    copy_mem buf_dst, nk_vtxs.mem.mem, nk_vtxs.sz
    buf_dst = cast[pointer](cast[uint](buf_dst) + nk_vtxs.sz)
    copy_mem buf_dst, nk_idxs.mem.mem, nk_idxs.sz
    dev.unmap trans_buf

    nk_end nk_ctx.addr
    nk_clear nk_ctx.addr

    let copy_pass = begin_copy_pass cmd_buf
    copy_pass.upload trans_buf, vtx_buf, nk_vtxs.sz, cycle = true
    copy_pass.upload trans_buf, idx_buf, nk_idxs.sz, cycle = true, trans_buf_offset = nk_vtxs.sz
    `end`copy_pass

proc draw*(ren_pass: RenderPass; cmd_buf: gpu.CommandBuffer) =
    cmd_buf.push_vtx_uniform 0, proj
    with ren_pass:
        `bind` pipeln
        `bind` 0, [TextureSamplerBinding(tex: font_tex, sampler: sampler)]
        `bind` 0, [BufferBinding(buf: vtx_buf)]
        `bind` BufferBinding(buf: idx_buf), elemSz16

    var offset = 0'u32
    for cmd in nk_ctx.commands nk_cmds:
        if cmd.tex:
            ren_pass.`bind` 0, [TextureSamplerBinding(tex: cmd.tex, sampler: sampler)]
        let r = cmd.clip_rect
        ren_pass.scissor = some sdl.Rect(x: max(cint r.x, 0), y: max(cint r.y, 0),
                                         w: max(cint r.w, 0), h: max(cint r.h, 0))
        ren_pass.draw_indexed cmd.elem_count, fst_idx = offset
        offset += cmd.elem_count
    nk_buffer_clear nk_cmds.addr
    nk_buffer_clear nk_vtxs.addr
    nk_buffer_clear nk_idxs.addr

proc free*(dev: Device) =
    nk_font_atlas_clear atlas.addr
    destroy nk_cmds
    destroy nk_vtxs
    destroy nk_idxs

    dev.destroy font_tex
    dev.destroy sampler
    dev.destroy pipeln
