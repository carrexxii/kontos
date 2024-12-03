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
    (dvlaPosition, dvlfFloat   , Vertex.offsetof pos),
    (dvlaTexCoord, dvlfFloat   , Vertex.offsetof uv),
    (dvlaColour  , dvlfR8G8B8A8, Vertex.offsetof colour),
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
    nk_context*: Context

    atlas      : FontAtlas
    font_tex   : Texture
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
    var font_cfg = nk_font_config FontSizeMedium
    with font_cfg:
        ttf_blob = font_file[0].addr
        ttf_sz   = uint font_file.len
        # oversample_h = 1
        # oversample_v = 1
        range = char_ranges[0].addr

    atlas = create_atlas()
    begin atlas
    let font = atlas.add font_cfg
    let (atlas_pxs, atlas_w, atlas_h) = bake atlas
    font_tex = dev.upload(atlas_pxs, atlas_w, atlas_h, fmt = texFmtR8Unorm)
    `end` atlas, pointer font_tex
    cleanup atlas

    init nk_context, font

    # Cleanup
    dev.destroy vtx_shader
    dev.destroy frag_shader

var test_op: int32
var test_slider: float32
proc update*(dev: Device; cmd_buf: gpu.CommandBuffer) =
    begin nk_context, nk.Rect(x: 40, y: 40, w: 320, h: 320), winBorder or winMovable or winClosable, name = "Testing"
    nk_context.row 1, 30, 80
    if nk_context.addr.nk_button_label "button":
        echo &"~~~Event (slider = {test_slider})"

    nk_context.row 2, 30
    if nk_context.option("easy", test_op == 1): test_op = 1
    if nk_context.option("hard", test_op == 2): test_op = 2

    nk_context.row_custom 2, 30:
        push 50
        label "Volume: "
        push 110
        slider test_slider.addr, 0.0, 1.0, 0.1

    nk_context.convert VertexConfig, nk_cmds, nk_vtxs, nk_idxs

    var buf_dst = dev.map trans_buf
    copy_mem buf_dst, nk_vtxs.mem.mem, nk_vtxs.sz
    buf_dst = cast[pointer](cast[uint](buf_dst) + nk_vtxs.sz)
    copy_mem buf_dst, nk_idxs.mem.mem, nk_idxs.sz
    dev.unmap trans_buf

    `end` nk_context
    clear nk_context

    let copy_pass = begin_copy_pass cmd_buf
    with copy_pass:
        upload trans_buf, vtx_buf, nk_vtxs.sz, cycle = true
        upload trans_buf, idx_buf, nk_idxs.sz, cycle = true, trans_buf_offset = nk_vtxs.sz
        `end`

from std/sequtils import apply
proc draw*(ren_pass: RenderPass; cmd_buf: gpu.CommandBuffer) =
    cmd_buf.push_vtx_uniform 0, proj
    with ren_pass:
        `bind` pipeln
        `bind` 0, [TextureSamplerBinding(tex: font_tex, sampler: sampler)]
        `bind` 0, [BufferBinding(buf: vtx_buf)]
        `bind` BufferBinding(buf: idx_buf), elemSz16

    var offset = 0'u32
    for cmd in nk_context.commands nk_cmds:
        if cmd.tex:
            ren_pass.`bind` 0, [TextureSamplerBinding(tex: cmd.tex, sampler: sampler)]
        let r = cmd.clip_rect
        ren_pass.scissor = some sdl.Rect(x: max(cint r.x, 0), y: max(cint r.y, 0),
                                         w: max(cint r.w, 0), h: max(cint r.h, 0))
        ren_pass.draw_indexed cmd.elem_count, fst_idx = offset
        offset += cmd.elem_count
    clear nk_cmds, nk_vtxs, nk_idxs

proc free*(dev: Device) =
    clear atlas
    destroy nk_cmds, nk_vtxs, nk_idxs
    with dev:
        destroy font_tex
        destroy sampler
        destroy pipeln
