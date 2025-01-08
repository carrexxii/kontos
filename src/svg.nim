import
    std/[xmltree, xmlparser, strutils],
    sdl, sdl/gpu, ngm,
    common

const MaxLod = 3

type
    VectorModel* = object
        vbo*: Buffer
        ibo*: Buffer
        vtx_cnt*: uint16
        idx_cnt*: uint16

    Vertex* = object
        pos*: Vec2

    ElementKind = enum
        ekRect
        ekCircle
    Element = object
        id   : string
        style: Style
        case kind: ElementKind
        of ekRect  : rect     : ngm.Rect
        of ekCircle: cx, cy, r: float32

    Style = object
        colour: uint32

var xml_errs: seq[string]

func vtx_cnt*(ek: ElementKind): int =
    case ek
    of ekRect  : result = 4
    of ekCircle: result = 3*2^MaxLod

func idx_cnt*(ek: ElementKind): int =
    case ek
    of ekRect:
        result = 6
    of ekCircle:
        result = 1
        for i in 1..MaxLod:
            result += 3*2^(i - 1)
        result *= 3

proc parse_measurement(n: string): float =
    let num_end = n.rfind {'0'..'9'}
    let suffix  = n[(num_end + 1)..^1]
    let num     = parse_float n[0..num_end]
    case suffix
    of "mm": num / 1000
    else:
        error &"Failed to convert units {suffix} for '{n}'"
        num

proc triangulate*(elems: seq[Element]): tuple[vtxs: seq[Vertex]; idxs: seq[uint16]] =
    var vtx_cnt, idx_cnt: int
    for elem in elems:
        vtx_cnt += elem.kind.vtx_cnt
        idx_cnt += elem.kind.idx_cnt
    result.vtxs = new_seq_of_cap[Vertex] vtx_cnt
    result.idxs = new_seq_of_cap[uint16] idx_cnt

    for elem in elems:
        let fst_idx = result.vtxs.len
        case elem.kind
        of ekRect:
            let m = max(elem.rect.w, elem.rect.h)
            let w = elem.rect.w / m
            let h = elem.rect.h / m
            result.vtxs.add Vertex(pos: vec(0.0, 0.0))
            result.vtxs.add Vertex(pos: vec(w  , 0.0))
            result.vtxs.add Vertex(pos: vec(w  , h  ))
            result.vtxs.add Vertex(pos: vec(0.0, h  ))

            for i in [0, 1, 2, 0, 2, 3]:
                result.idxs.add uint16 (fst_idx + i)
        of ekCircle:
            # Based on https://www.humus.name/index.php?page=News&ID=228
            let pt_cnt = 3*2^MaxLod
            var α  = 3*π / 4
            var dα = 2*π / float32 pt_cnt
            for j in 0..pt_cnt - 1:
                result.vtxs.add Vertex(pos: 0.5*vec(cos α, sin α))
                α -= dα

            var v = 1 # Vertex of current triangle 1/2/3
            var s = 0 # Index of current vertex
            for i in 0..MaxLoD:
                let ds = 2^(MaxLod - i)
                while true:
                    result.idxs.add uint16 (fst_idx + s mod pt_cnt)
                    if s + ds >= pt_cnt and v == 3:
                        break
                    elif v == 3:
                        result.idxs.add uint16 (fst_idx + s mod pt_cnt)
                        v = 1

                    s += ds
                    inc v
                v = 1
                s = 0

    assert result.vtxs.len == result.vtxs.capacity, &"{result.vtxs.len} != {result.vtxs.capacity}"
    assert result.idxs.len == result.idxs.capacity, &"{result.idxs.len} != {result.idxs.capacity}"

proc parse_style*(style: string): Style =
    discard

proc parse_element*(node: XmlNode): Element =
    result.id    = node.attr "id"
    result.style = parse_style node.attr "style"
    case node.tag
    of "rect":
        result = Element(kind: ekRect)
        result.rect = ngm.rect(
            parse_float node.attr "x",
            parse_float node.attr "y",
            parse_float node.attr "width",
            parse_float node.attr "height"
        )
    of "circle":
        result = Element(kind: ekCircle)
        result.cx   = parse_float node.attr "cx"
        result.cy   = parse_float node.attr "cy"
        result.r    = parse_float node.attr "r"
    else:
        error "Failed to parse element: " & node.tag

proc load*(path: string): ref VectorModel =
    var elems = new_seq_of_cap[Element] 8

    let xml = load_xml(path, xml_errs, options = {})
    if xml_errs.len > 0:
        error &"XML parsing error in svg file '{path}'"
        for err in xml_errs:
            warn err

        xml_errs.set_len 0

    let canvas_w = parse_measurement xml.attr "width"
    let canvas_h = parse_measurement xml.attr "height"
    for node in xml:
        case node.tag
        of "defs":
            if node.len > 0:
                assert false
        of "g":
            for child in node:
                elems.add parse_element child
        else:
            elems.add parse_element node

    let mesh = triangulate elems
    result = new VectorModel
    result.vbo = device.upload(bufUsageVertex, mesh.vtxs, "SVG VBO")
    result.ibo = device.upload(bufUsageIndex , mesh.idxs, "SVG IBO")
    result.vtx_cnt = uint16 mesh.vtxs.len
    result.idx_cnt = uint16 mesh.idxs.len

    info &"Loaded SVG file with canvas size {canvas_w:.3f}x{canvas_h:.3f} containing {elems.len} elements " &
         &"triangulated with {mesh.vtxs.len} vertices and {mesh.idxs.len} indices"
