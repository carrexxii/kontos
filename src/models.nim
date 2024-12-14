import sdl, sdl/gpu, ngm, common

const
    MaxMeshCount     = 8
    MaxMaterialCount = 8

type
    Vertex* = object
        pos*   : Vec3
        uv*    : Vec2
        normal*: Vec3

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

var pipeln: GraphicsPipeline

proc init*(dev: Device; win: Window) =
    let vtx_shader  = dev.create_shader_from_file(shaderVertex  , ShaderDir / "model.vert.spv")
    let frag_shader = dev.create_shader_from_file(shaderFragment, ShaderDir / "model.frag.spv")
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
        vertex_input_state(
            [vtx_descr(0, sizeof Vertex, inputVertex)],
            [vtx_attr(0, 0, vtxElemFloat3, Vertex.offsetof pos),
             vtx_attr(1, 0, vtxElemFloat2, Vertex.offsetof uv),
             vtx_attr(2, 0, vtxElemFloat3, Vertex.offsetof normal)],
        ),
        target_info = GraphicsPipelineTargetInfo(
            colour_target_descrs    : ct_descr.addr,
            colour_target_count     : 1,
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

    dev.destroy vtx_shader
    dev.destroy frag_shader

proc draw*(ren_pass: RenderPass; mdl: ref Model) =
    with ren_pass:
        `bind` pipeln
        `bind` 0, [BufferBinding(buf: mdl.vbo)]
        `bind` BufferBinding(buf: mdl.ibo), elemSz32
    for mesh in mdl.meshes:
        if mesh.vtx_cnt == 0:
            break

        ren_pass.draw_indexed mesh.vtx_cnt, fst_idx = mesh.fst_idx

proc cleanup*(dev: Device) =
    dev.destroy pipeln
