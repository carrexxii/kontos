import sdl/gpu, ngm, common

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
        vtx_cnt*  : uint32
        idx_cnt*  : uint32
        idx_start*: uint32
        mtl_idx*  : uint32

    Material* = object
        diffuse*    : Texture
        base_colour*: Vec4

proc draw*(mdl: ref Model) =
    discard
