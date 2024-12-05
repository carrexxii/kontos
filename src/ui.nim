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
    ui_ctx*: Context

    atlas    : FontAtlas
    font_tex : Texture
    pipeln   : GraphicsPipeline
    sampler  : Sampler
    sdl_trans: TransferBuffer
    sdl_vtxs : gpu.Buffer
    sdl_idxs : gpu.Buffer
    nk_cmds  : nk.Buffer
    nk_vtxs  : nk.Buffer
    nk_idxs  : nk.Buffer
    proj     : Mat4x4

proc init*(dev: Device; win: sdl.Window) =
    proj = orthogonal(0, 1280, 800, 0, 0.1, 1.0)

    let vtx_shader  = dev.create_shader_from_file(shaderVertex, ShaderDir / "ui.vert.spv", uniform_buf_count = 1)
    let frag_shader = dev.create_shader_from_file(shaderVertex, ShaderDir / "ui.frag.spv", sampler_count = 1)
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
    sdl_trans = dev.create_transfer_buffer (VertexBufferSize + IndexBufferSize)
    sdl_vtxs  = dev.create_buffer(bufUsageVertex, VertexBufferSize, "UI Vertices")
    sdl_idxs  = dev.create_buffer(bufUsageIndex , IndexBufferSize , "UI Indices")

    dev.set_tex_name font_tex, "UI Font Atlas"

    # Nuklear
    nk_cmds = create_buffer CommandBufferSize
    nk_vtxs = create_buffer VertexBufferSize
    nk_idxs = create_buffer IndexBufferSize

    const char_ranges = [
        Rune 0x0020, Rune 0x007E,
        Rune 0
    ]
    let font_file = read_file(FontDir / "IBMPlexMono.ttf")
    var font_cfg = nk_font_config FontSizeMedium
    with font_cfg:
        ttf_blob = font_file[0].addr
        ttf_sz   = uint font_file.len
        # oversample_h = 1
        # oversample_v = 1
        range = char_ranges[0].addr

    init atlas
    begin atlas
    let font = atlas.add font_cfg
    let (atlas_pxs, atlas_w, atlas_h) = bake atlas
    font_tex = dev.upload(atlas_pxs, atlas_w, atlas_h, fmt = texFmtR8Unorm)
    `end` atlas, pointer font_tex
    `=destroy` atlas

    init ui_ctx, font

    # Cleanup
    dev.destroy vtx_shader
    dev.destroy frag_shader

    debug "Initialized UI"

var test_op: int32
var test_slider: float32
proc update*(dev: Device; cmd_buf: gpu.CommandBuffer) =
    begin ui_ctx, nk.Rect(x: 40, y: 40, w: 320, h: 320), winBorder or winMovable or winClosable, name = "Testing"
    ui_ctx.row 1, 30, 80
    if ui_ctx.addr.nk_button_label "button":
        echo &"~~~Event (slider = {test_slider})"

    ui_ctx.row 2, 30
    if ui_ctx.option("easy", test_op == 1): test_op = 1
    if ui_ctx.option("hard", test_op == 2): test_op = 2

    ui_ctx.row_custom 2, 30:
        push 50
        label "Volume: "
        push 110
        slider test_slider.addr, 0.0, 1.0, 0.1

    ui_ctx.convert VertexConfig, nk_cmds, nk_vtxs, nk_idxs

    var buf_dst = dev.map sdl_trans
    copy_mem buf_dst, nk_vtxs.mem.mem, nk_vtxs.sz
    buf_dst = cast[pointer](cast[uint](buf_dst) + nk_vtxs.sz)
    copy_mem buf_dst, nk_idxs.mem.mem, nk_idxs.sz
    dev.unmap sdl_trans

    `end` ui_ctx
    clear ui_ctx

    let copy_pass = begin_copy_pass cmd_buf
    with copy_pass:
        upload sdl_trans, sdl_vtxs, nk_vtxs.sz, cycle = true
        upload sdl_trans, sdl_idxs, nk_idxs.sz, cycle = true, trans_buf_offset = nk_vtxs.sz
        `end`

proc draw*(ren_pass: RenderPass; cmd_buf: gpu.CommandBuffer) =
    cmd_buf.push_vtx_uniform 0, proj
    with ren_pass:
        `bind` pipeln
        `bind` 0, [TextureSamplerBinding(tex: font_tex, sampler: sampler)]
        `bind` 0, [BufferBinding(buf: sdl_vtxs)]
        `bind` BufferBinding(buf: sdl_idxs), elemSz16

    var offset = 0'u32
    for cmd in ui_ctx.commands nk_cmds:
        if cmd.tex:
            ren_pass.`bind` 0, [TextureSamplerBinding(tex: cmd.tex, sampler: sampler)]
        let r = cmd.clip_rect
        ren_pass.scissor = some sdl.Rect(x: max(cint r.x, 0), y: max(cint r.y, 0),
                                         w: max(cint r.w, 0), h: max(cint r.h, 0))
        ren_pass.draw_indexed cmd.elem_count, fst_idx = offset
        offset += cmd.elem_count
    clear nk_cmds, nk_vtxs, nk_idxs

proc free*(dev: Device) =
    debug "Freeing UI resources"
    with dev:
        destroy sdl_trans
        destroy sdl_vtxs
        destroy sdl_idxs
        destroy font_tex
        destroy sampler
        destroy pipeln
