# zlib License
#
# (C) 2024 carrexxii
#
# This software is provided 'as-is', without any express or implied
# warranty. In no event will the authors be held liable for any damages
# arising from the use of this software.
#
# Permission is granted to anyone to use this software for any purpose,
# including commercial applications, and to alter it and redistribute it
# freely, subject to the following restrictions:
#
# 1. The origin of this software must not be misrepresented; you must not
#    claim that you wrote the original software. If you use this software
#    in a product, an acknowledgment in the product documentation would be
#    appreciated but is not required.
# 2. Altered source versions must be plainly marked as such, and must not be
#    misrepresented as being the original software.
# 3. This notice may not be removed or altered from any source distribution.

const Magic*  : array[4, byte] = [78, 65, 73, 126] # "NAI~"
const Version*: array[2, byte] = [0, 0]

type
    LayoutFlag* = enum
        lfVerticesInterleaved
        lfVerticesSeparated
        lfTexturesInternal
        lfTexturesExternal
    LayoutMask* {.size: sizeof(uint16).} = set[LayoutFlag]

    CompressionKind* {.size: sizeof(uint16).} = enum
        ckNone
        ckZLib

    ContainerKind* = enum
        ckNone
        ckDds
        ckPng

    VertexKind* {.size: sizeof(uint8).} = enum
        vkNone
        vkPosition
        vkNormal
        vkTangent
        vkBitangent
        vkColourRgba
        vkColourRgb
        vkUv
        vkUv3

    MaterialValue* {.size: sizeof(uint8).} = enum
        mvNone
        mvName
        mvTwoSided
        mvBaseColour
        mvMetallicFactor
        mvRoughnessFactor
        mvSpecularFactor
        mvGlossinessFactor
        mvAnisotropyFactor
        mvSheenColourFactor
        mvSheenRoughnessFactor
        mvClearcoatFactor
        mvClearcoatRoughnessFactor
        mvOpacity
        mvBumpScaling
        mvShininess
        mvReflectivity
        mvRefractiveIndex
        mvColourDiffuse
        mvColourAmbient
        mvColourSpecular
        mvColourEmissive
        mvColourTransparent
        mvColourReflective
        mvTransmissionFactor
        mvVolumeThicknessFactor
        mvVolumeAttenuationDistance
        mvVolumeAttenuationColour
        mvEmissiveIntensity

    TextureKind* {.size: sizeof(uint16).} = enum
        tkNone
        tkDiffuse
        tkSpecular
        tkAmbient
        tkEmissive
        tkHeight
        tkNormals
        tkShininess
        tkOpacity
        tkDisplacement
        tkLightmap
        tkReflection
        tkBaseColour
        tkNormalCamera
        tkEmissionColour
        tkMetalness
        tkDiffuseRoughness
        tkAmbientOcclusion
        tkUnknown
        tkSheen
        tkClearcoat
        tkTransmission

    TextureFormat* {.size: sizeof(uint16).} = enum
        tfNone

        tfR
        tfRg
        tfRgb
        tfRgba

        tfBc1 = 100
        tfBc3
        tfBc4
        tfBc5
        tfBc6H
        tfBc7

        tfEtc1 = 200

        tfAstc4x4 = 300

    IndexSize* {.size: sizeof(uint16).} = enum
        isNone
        is8Bit
        is16Bit
        is32Bit
        is64Bit

type
    Header* = object
        magic*       : array[4, byte]
        version*     : array[2, byte]
        layout_mask* : LayoutMask
        vtx_kinds*   : array[8, VertexKind]
        mtl_vals*    : array[8, MaterialValue]
        cmp_kind*    : CompressionKind
        mesh_cnt*    : uint16
        mtl_cnt*     : uint16
        tex_cnt*     : uint16
        anim_cnt*    : uint16
        skeleton_cnt*: uint16

    MeshHeader* = object
        mtl_idx*: uint16
        idx_sz* : IndexSize
        vtx_cnt*: uint32
        idx_cnt*: uint32
        # verts: array[vert_cnt, float32]

    MaterialHeader* = object
        tex_cnt*: uint16
        _       : uint16
        # mtl_data: struct
        # tex_data: array[tex_cnt, TextureHeader]

    TextureHeader* = object
        kind* : TextureKind
        fmt*  : TextureFormat
        w*, h*: uint16
        # data: array[<format_size> * w * h, byte]

converter `IndexSize -> int`*(kind: IndexSize): int =
    case kind
    of isNone : 0
    of is8Bit : 1
    of is16Bit: 2
    of is32Bit: 4
    of is64Bit: 8

converter `VertexKind -> int`*(kind: VertexKind): int =
    case kind
    of vkNone: 0
    of vkPosition, vkNormal,
       vkTangent , vkBitangent,
       vkUV3       : 3 * sizeof float32
    of vkColourRgba: 4 * sizeof uint8
    of vkColourRgb : 3 * sizeof uint8
    of vkUv        : 2 * sizeof float32

converter `MaterialValue -> int`*(kind: MaterialValue): int =
    case kind
    of mvBaseColour       , mvColourDiffuse , mvVolumeAttenuationColour,
       mvColourAmbient    , mvColourSpecular, mvColourEmissive,
       mvColourTransparent, mvColourReflective: 16
    of mvTwoSided: 1
    else: 4

func bpp*(kind: TextureFormat): int =
    case kind
    of tfNone: 0
    of tfRg  : 16
    of tfRgb : 24
    of tfRgba: 32
    of tfBc1, tfBc4: 4
    of tfR, tfBc3, tfBc5, tfBc6H, tfBc7: 8
    of tfEtc1   : 0 # TODO
    of tfAstc4x4: 0 # TODO

func size*(kind: TextureFormat; w: SomeInteger; h: SomeInteger): int =
    (kind.bpp div 4) * int w * int h
