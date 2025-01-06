import std/[xmltree, xmlparser, strutils], ngm, common

type
    VectorModel* = object
        vtxs*: seq[Vertex]
        idxs*: seq[uint16]

    Vertex = object
        pos   : Vec2
        colour: uint32

    ElementKind = enum
        ekRect
    Element = object
        id   : string
        style: Style
        case kind: ElementKind
        of ekRect: rect: Rect

    Style = object
        colour: uint32

var xml_errs: seq[string]

func vtx_cnt*(ek: ElementKind): int =
    case ek
    of ekRect: 4

func idx_cnt*(ek: ElementKind): int =
    case ek
    of ekRect: 6

proc parse_measurement(n: string): float =
    let num_end = n.rfind {'0'..'9'}
    let suffix  = n[(num_end + 1)..^1]
    let num     = parse_float n[0..num_end]
    case suffix
    of "mm": num / 1000
    else:
        error &"Failed to convert units {suffix} for '{n}'"
        num

proc triangulate*(elems: seq[Element]): VectorModel =
    var vtx_cnt, idx_cnt: int
    for elem in elems:
        vtx_cnt += elem.kind.vtx_cnt
        idx_cnt += elem.kind.idx_cnt
    result.vtxs = new_seq_of_cap[Vertex] vtx_cnt
    result.idxs = new_seq_of_cap[uint16] idx_cnt

    for elem in elems:
        case elem.kind
        of ekRect:
            let w = elem.rect.w / max(elem.rect.w, elem.rect.h)
            let h = elem.rect.h / max(elem.rect.w, elem.rect.h)
            result.vtxs.add Vertex(pos: vec(0.0, 0.0))
            result.vtxs.add Vertex(pos: vec(0.0, h  ))
            result.vtxs.add Vertex(pos: vec(w  , h  ))
            result.vtxs.add Vertex(pos: vec(w  , 0.0))

            for i in [0'u16, 1, 2, 0, 2, 3]:
                result.idxs.add i

proc parse_style*(style: string): Style =
    discard

proc parse_element*(node: XmlNode): Element =
    result.id    = node.attr "id"
    result.style = parse_style node.attr "style"
    case node.tag
    of "rect":
        result.rect = rect(
            parse_float node.attr "x",
            parse_float node.attr "y",
            parse_float node.attr "width",
            parse_float node.attr "height"
        )

proc load*(path: string): VectorModel =
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
            discard
        of "g":
            for child in node:
                elems.add parse_element child

    result = triangulate elems

    info &"Loaded SVG file with canvas size {canvas_w:.3f}x{canvas_h:.3f} containing {elems.len} elements\n\t" &
         &"Triangulated with {result.vtxs.len} vertices and {result.idxs.len} indices"
    echo elems
    echo result
    quit 0
