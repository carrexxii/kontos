import common, sdl, sdl/gpu
from std/sequtils import new_seq_with

type
    Tilemap* = object
        w, h : uint32
        tiles: seq[seq[Tile]]

    Tile* = uint8

var pipeln : GraphicsPipeline
var sampler: Sampler

proc init*(dev: Device; win: Window) =
    let vtx_shader  = dev.create_shader_from_file(shaderVertex  , ShaderDir / "tilemap.vert.spv", uniform_buf_cnt = 1)
    let frag_shader = dev.create_shader_from_file(shaderFragment, ShaderDir / "tilemap.frag.spv", sampler_cnt = 1)
    let ct_descr = ColourTargetDescription(
        fmt: dev.swapchain_tex_fmt win,
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
    pipeln = dev.create_graphics_pipeline(vtx_shader, frag_shader,
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

    sampler = dev.create_sampler()

    dev.destroy vtx_shader
    dev.destroy frag_shader

proc create*(w: Natural; h: Natural): Tilemap =
    result = Tilemap(
        w: uint32 w,
        h: uint32 h,
        tiles: new_seq_with(h, new_seq[Tile] w),
    )
    info &"Created new tilemap ({w}x{h} = {result.w*result.h} tiles)"

proc draw*(ren_pass: RenderPass; map: Tilemap) =
    with ren_pass:
        `bind` pipeln
        draw map.w*map.h
