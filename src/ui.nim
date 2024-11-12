import sdl, sdl/gpu, nuklear, common

const
    UiVertexBufferSize = 2*1024*1024
    FontSizeSmall  = 12
    FontSizeMedium = 16
    FontSizeLarge  = 24

type Vertex = object
    pos   : array[2, float32]
    colour: array[4, uint8]

var
    context : NkContext
    atlas   : NkFontAtlas
    font_tex: Texture

    pipeln     : GraphicsPipeline
    vtx_shader : Shader
    frag_shader: Shader
    sampler    : Sampler
    vtx_buf    : Buffer
    verts_buf  : Buffer

    TriVerts = [
        Vertex(pos: [-0.9,  0.9], colour: [0, 0, 100, 255]),
        Vertex(pos: [ 0.9, -0.9], colour: [0, 0, 100, 255]),
        Vertex(pos: [-0.9, -0.9], colour: [0, 0, 100, 255]),

        Vertex(pos: [ 0.9,  0.9], colour: [100, 0, 0, 255]),
        Vertex(pos: [-0.9,  0.9], colour: [100, 0, 0, 255]),
        Vertex(pos: [ 0.9, -0.9], colour: [100, 0, 0, 255]),
    ]

proc init*(dev: Device; win: Window) =
    vtx_shader  = dev.create_shader(shaderVertex, ShaderDir / "ui.vert.spv")
    frag_shader = dev.create_shader(shaderVertex, ShaderDir / "ui.frag.spv", sampler_count = 1)
    let ct_descr = ColourTargetDescription(fmt: swapchain_tex_fmt(dev, win))
    pipeln = dev.create_graphics_pipeline(vtx_shader, frag_shader,
        vertex_input_state(
            [vtx_descr(0, sizeof Vertex, inputVertex)],
            [vtx_attr(0, 0, vtxElemFloat2, 0),
             vtx_attr(1, 0, vtxElemUByte4, 8)],
        ),
        target_info = GraphicsPipelineTargetInfo(
            colour_target_descrs: ct_descr.addr,
            colour_target_count : 1,
        ),
    )

    sampler  = create_sampler dev
    vtx_buf  = create_buffer(dev, bufUsageVertex, UiVertexBufferSize)

    verts_buf = dev.upload(bufUsageVertex, TriVerts)

    dev.set_buf_name vtx_buf , "UI Vertices"
    dev.set_tex_name font_tex, "Font Atlas"

    # Nuklear
    const char_ranges = [
        NkRune 0x0020, 0x007E,
        0
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
    let atlas_pxs = nk_font_atlas_bake(atlas.addr, atlas_w.addr, atlas_h.addr, nkFontAtlasAlpha8)
    font_tex = dev.upload(atlas_pxs, atlas_w, atlas_h, fmt = texFmtR8Unorm)

    nk_font_atlas_end atlas.addr, pointer font_tex, nil
    nk_font_atlas_cleanup atlas.addr

    assert nk_init(context.addr, NimAllocator.addr, font.handle.addr), "Failed to initialize Nuklear"

    # Cleanup
    dev.destroy vtx_shader
    dev.destroy frag_shader

proc draw*(ren_pass: RenderPass) =
    with ren_pass:
        `bind` pipeln
        `bind` 0, [TextureSamplerBinding(tex: font_tex, sampler: sampler)]
        `bind` 0, [BufferBinding(buf: verts_buf)]
        draw 6

proc free*(dev: Device) =
    nk_font_atlas_clear atlas.addr
    dev.destroy font_tex
    dev.destroy sampler
    dev.destroy pipeln
