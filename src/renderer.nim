import sdl, sdl/gpu, common, resmgr
from std/options import some
from ngm     import Mat4x4
from input   import map
from ui      import update, draw
from tilemap import Tilemap

type
    RenderObject* = object
        mdl*: ref Model

var
    sampler       : Sampler
    model_pipeln  : GraphicsPipeline
    tilemap_pipeln: GraphicsPipeline

var depth_tex: Texture
var map      : ptr Tilemap
var models   : seq[ref Model]

device.set_tex_name depth_tex, "Depth Texture"

proc toggle_fill*(was_down: bool) =
    if was_down:
        return

proc init*() =
    device = create_device(ShaderFormat, true)
    window = create_window(WindowTitle, window_size.x, window_size.y, winNone)
    device.claim window

    depth_tex = device.create_texture(window_size.x, window_size.y, fmt = texFmtD16Unorm, usage = texUsageDepthStencilTarget)

    kcTab.map toggle_fill

    # Pipelines
    sampler = device.create_sampler()
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

    block: # Model Pipeline
        let vtx_shader  = device.create_shader_from_file(shaderVertex  , ShaderDir / "model.vert.spv", uniform_buf_cnt = 1)
        let frag_shader = device.create_shader_from_file(shaderFragment, ShaderDir / "model.frag.spv", sampler_cnt = 1)
        model_pipeln = device.create_graphics_pipeline(vtx_shader, frag_shader,
            vertex_input_state(
                [vtx_descr(0, sizeof ModelVertex, inputVertex)],
                [vtx_attr(0, 0, vtxElemFloat3, ModelVertex.offsetof pos),
                 vtx_attr(1, 0, vtxElemFloat2, ModelVertex.offsetof uv),
                 vtx_attr(2, 0, vtxElemFloat3, ModelVertex.offsetof normal)],
            ),
            target_info = GraphicsPipelineTargetInfo(
                colour_target_descrs    : ct_descr.addr,
                colour_target_cnt       : 1,
                depth_stencil_fmt       : texFmtD16Unorm,
                has_depth_stencil_target: true,
            ),
            depth_stencil_state = DepthStencilState(
                compare_op         : cmpGreater,
                back_stencil_state : StencilOpState(),
                front_stencil_state: StencilOpState(),
                compare_mask       : 0xFF,
                write_mask         : 0xFF,
                enable_depth_test  : true,
                enable_depth_write : true,
                enable_stencil_test: false,
            ),
        )

        device.destroy vtx_shader
        device.destroy frag_shader

    block: # Tilemap Pipeline
        let vtx_shader  = device.create_shader_from_file(shaderVertex  , ShaderDir / "tilemap.vert.spv", uniform_buf_cnt = 1)
        let frag_shader = device.create_shader_from_file(shaderFragment, ShaderDir / "tilemap.frag.spv", sampler_cnt = 1)
        tilemap_pipeln = device.create_graphics_pipeline(vtx_shader, frag_shader,
            vertex_input_state([], []),
            target_info = GraphicsPipelineTargetInfo(
                colour_target_descrs    : ct_descr.addr,
                colour_target_cnt       : 1,
                depth_stencil_fmt       : texFmtD16Unorm,
                has_depth_stencil_target: true,
            ),
            depth_stencil_state = DepthStencilState(
                compare_op         : cmpGreater,
                back_stencil_state : StencilOpState(),
                front_stencil_state: StencilOpState(),
                compare_mask       : 0xFF,
                write_mask         : 0xFF,
                enable_depth_test  : true,
                enable_depth_write : true,
                enable_stencil_test: false,
            ),
        )

        device.destroy vtx_shader
        device.destroy frag_shader

    info "Initialized renderer"

proc cleanup*() =
    info "Cleaning up renderer..."
    with device:
        destroy depth_tex
        destroy sampler

        destroy model_pipeln
        destroy tilemap_pipeln
        destroy

proc set_map*(m: ptr Tilemap) =
    map = m

proc add*(mdl: ref Model) =
    models.add mdl

proc clear*() =
    models.set_len 0

proc draw_models(ren_pass: RenderPass) =
    for mdl in models:
        with ren_pass:
            `bind` model_pipeln
            `bind` 0, [BufferBinding(buf: mdl.vbo)]
            `bind` BufferBinding(buf: mdl.ibo), elemSz32
        for mesh in mdl.meshes:
            if mesh.vtx_cnt == 0:
                break

            let diffuse = mdl.mtls[mesh.mtl_idx].diffuse
            ren_pass.`bind` 0, [TextureSamplerBinding(tex: diffuse, sampler: sampler)]
            ren_pass.draw_indexed mesh.vtx_cnt, fst_idx = mesh.fst_idx

proc draw_tilemap(ren_pass: RenderPass) =
    if map == nil:
        return

    let map = map[]
    with ren_pass:
        `bind` tilemap_pipeln
        draw 6*map.w*map.h

proc draw*(view, proj: Mat4x4) =
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
    cmd_buf.push_vtx_uniform 0, [proj, view]
    with ren_pass:
        draw_tilemap
        draw_models
        ui.draw cmd_buf
        `end`
    submit cmd_buf
