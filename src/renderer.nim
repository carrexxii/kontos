import sdl, sdl/gpu, ngm, common, resmgr, tilemap, svg
from std/options import some
from input import map
from ui    import update, draw

const DepthTextureFormat = texFmtD16Unorm

var
    model_pipeln  : GraphicsPipeline
    tilemap_pipeln: GraphicsPipeline
    sampler       : Sampler
    depth_tex     : Texture

    models: seq[ref VectorModel]
    map   : ptr Tilemap

    fill_mode = fmFill

proc toggle_fill*(was_down: bool)

proc create_pipelines() =
    var ct_descr = ColourTargetDescription(
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

    block: # VectorModel Pipeline
        let vtx_shader  = load_shader "vectormodel.vert"
        let frag_shader = load_shader "vectormodel.frag"
        model_pipeln = device.create_graphics_pipeline(vtx_shader, frag_shader,
            vertex_input_state(
                [vtx_descr(0, sizeof svg.Vertex, inputVertex)],
                [vtx_attr(0, 0, vtxElemFloat2, svg.Vertex.offsetof pos)],
            ),
            target_info = GraphicsPipelineTargetInfo(
                colour_target_descrs    : ct_descr.addr,
                colour_target_cnt       : 1,
                depth_stencil_fmt       : DepthTextureFormat,
                has_depth_stencil_target: true,
            ),
            depth_stencil_state = DepthStencilState(
                compare_op        : cmpGreater,
                enable_depth_test : true,
                enable_depth_write: true,
            ),
            raster_state = RasterizerState(fill_mode: fill_mode),
        )

    block: # Tilemap Pipeline
        let vtx_shader  = load_shader("tilemap.vert", ubo_cnt = 1, sbo_cnt = 1)
        let frag_shader = load_shader("tilemap.frag", sampler_cnt = 1)
        tilemap_pipeln = device.create_graphics_pipeline(vtx_shader, frag_shader,
            vertex_input_state([], []),
            target_info = GraphicsPipelineTargetInfo(
                colour_target_descrs    : ct_descr.addr,
                colour_target_cnt       : 1,
                depth_stencil_fmt       : DepthTextureFormat,
                has_depth_stencil_target: true,
            ),
            depth_stencil_state = DepthStencilState(
                compare_op        : cmpGreater,
                enable_depth_test : true,
                enable_depth_write: true,
            ),
            raster_state = RasterizerState(fill_mode: fill_mode),
        )

proc init*() =
    device = create_device(ShaderFormat, not defined Release)
    window = create_window(WindowTitle, window_size.x, window_size.y, winNone)
    device.claim window

    sampler = device.create_sampler()

    depth_tex = device.create_texture(window_size.x, window_size.y, fmt = DepthTextureFormat, usage = texUsageDepthStencilTarget)
    device.set_tex_name depth_tex, "Depth Texture"

    when not defined Release:
        kcTab.map toggle_fill

    create_pipelines()

    info "Initialized renderer"

proc cleanup*(only_pipelns = false) =
    if not only_pipelns:
        info "Cleaning up renderer..."
    with device:
        destroy model_pipeln
        destroy tilemap_pipeln
    if only_pipelns:
        return

    with device:
        destroy depth_tex
        destroy sampler
        destroy

proc toggle_fill*(was_down: bool) =
    if was_down:
        fill_mode = (if fill_mode == fmFill: fmLine else: fmFill)
        cleanup only_pipelns = true
        create_pipelines()

proc set_map*(m: ptr Tilemap) =
    map = m

proc add*(mdl: ref VectorModel) =
    models.add mdl

proc clear*() =
    models.set_len 0

proc draw_models(ren_pass: RenderPass) =
    ren_pass.`bind` model_pipeln
    for mdl in models:
        with ren_pass:
            `bind` 0, [BufferBinding(buf: mdl.vbo)]
            `bind` BufferBinding(buf: mdl.ibo), elemSz16
            draw_indexed mdl.idx_cnt

proc draw_tilemap(ren_pass: RenderPass; cmd_buf: CommandBuffer) =
    if map == nil:
        return

    let vtx_cnt = 6*map.w*map.h
    with ren_pass:
        `bind` 0, [map.buf]
        `bind` tilemap_pipeln
        draw vtx_cnt

proc draw*(cam: Camera3D) =
    let
        cmd_buf = acquire_cmd_buf device
        screen  = cmd_buf.swapchain_tex window
        target_info = ColourTargetInfo(
            tex         : screen.tex,
            clear_colour: fcolour(0.12, 0.28, 0.36),
            load_op     : loadClear,
            store_op    : storeStore,
        )
        depth_info = DepthStencilTargetInfo(
            tex             : depth_tex,
            clear_depth     : 0.0,
            load_op         : loadClear,
            store_op        : storeStore,
            stencil_load_op : loadClear,
            stencil_store_op: storeDontCare,
            cycle           : true,
            clear_stencil   : 0,
        )

    ui.update cmd_buf

    let ren_pass = begin_render_pass(cmd_buf, [target_info], some depth_info)
    cmd_buf.push_vtx_uniform 0, [cam.proj, cam.view]
    with ren_pass:
        draw_models
        # draw_tilemap cmd_buf
        # ui.draw cmd_buf
        `end`
    submit cmd_buf
