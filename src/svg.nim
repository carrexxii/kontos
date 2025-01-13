import
    std/[xmltree, xmlparser, strutils],
    sdl, sdl/gpu, ngm,
    common

const MaxLod = 4

type
    SvgGroup* = object
        vbo*      : Buffer
        ibo*      : Buffer
        tbo*      : TransferBuffer
        idx_cnt*  : uint32
        tforms*   : seq[Mat4]
        tform_buf*: Buffer

    Vertex* = object
        id*    : uint32
        pos*   : Vec2
        colour*: Colour

    ElementKind = enum
        ekRect
        ekEllipse
    Element = object
        id*   : string
        style*: Style
        rot*  : Radians
        pos*  : Vec2
        scale*: Vec2
        case kind*: ElementKind
        of ekRect, ekEllipse:
            w*, h*: float32

    Style = object
        fill: Colour

var xml_errs: seq[string]

proc `=destroy`*(g: SvgGroup) =
    with device:
        destroy g.vbo
        destroy g.ibo
        destroy g.tbo
        destroy g.tform_buf

func vtx_cnt*(ek: ElementKind): int =
    case ek
    of ekRect   : 4
    of ekEllipse: 3*2^MaxLod

func idx_cnt*(ek: ElementKind): int =
    case ek
    of ekRect: 6
    of ekEllipse:
        var cnt = 1
        for i in 1..MaxLod:
            cnt += 3*2^(i - 1)
        3*cnt

proc parse_measurement(n: string): float =
    try:
        let num_end = n.rfind {'0'..'9'}
        let suffix  = n[(num_end + 1)..^1]
        let num     = parse_float n[0..num_end]
        num # Might need to parse and track the units if units in the SVG are not consistent
        # case suffix
        # of "mm": num
        # else:
        #     error &"Failed to convert units {suffix} for '{n}'"
        #     num
    except ValueError:
        error &"Failed to parse measurement '{n}'"
        0

proc parse_colour(c: string): Colour =
    try:
        if c.starts_with "#":
            colour parse_hex_int c
        else:
            error &"Failed to parse colour '{c}'"
            colour 0, 0, 0
    except ValueError:
        error &"Failed to parse colour '{c}'"
        colour 0, 0, 0

proc upload*(g: ref SvgGroup; cmd_buf: CommandBuffer) =
    let tforms_sz = g.tforms.len * sizeof g.tforms[0]
    device.copy_mem g.tbo, g.tforms[0].addr, tforms_sz

    let copy_pass = begin_copy_pass cmd_buf
    copy_pass.upload g.tbo, g.tform_buf, tforms_sz
    `end` copy_pass

proc triangulate*(elems: seq[Element]; canvas_w, canvas_h: float32): ref SvgGroup =
    result = new SvgGroup
    result.tforms = new_seq_of_cap[Mat4] elems.len

    var vtx_cnt, idx_cnt: int = 0
    for elem in elems:
        vtx_cnt += elem.kind.vtx_cnt
        idx_cnt += elem.kind.idx_cnt
    var vtxs = new_seq_of_cap[Vertex] vtx_cnt
    var idxs = new_seq_of_cap[uint32] idx_cnt

    let ar = canvas_w / canvas_h
    let sz = max(canvas_w, canvas_h)
    for elem in elems:
        var tform = Mat4Ident

        let id      = uint16 result.tforms.len
        let colour  = elem.style.fill
        let fst_idx = vtxs.len
        case elem.kind
        of ekRect:
            let pos = vec(elem.pos.x - canvas_w/2, -(elem.pos.y - canvas_h/2)) / sz
            let w = elem.w / sz / 2
            let h = elem.h / sz / 2

            vtxs.add Vertex(id: id, pos: pos + vec(-w, -h), colour: colour)
            vtxs.add Vertex(id: id, pos: pos + vec( w, -h), colour: colour)
            vtxs.add Vertex(id: id, pos: pos + vec( w,  h), colour: colour)
            vtxs.add Vertex(id: id, pos: pos + vec(-w,  h), colour: colour)

            for i in [0, 1, 2, 0, 2, 3]:
                idxs.add uint32 (fst_idx + i)
        of ekEllipse:
            # Based on https://www.humus.name/index.php?page=News&ID=228
            let pos = vec(elem.pos.x - (elem.w + canvas_w)/2,
                        -(elem.pos.y - (elem.h + canvas_h)/2)) / sz
            let w = elem.w / sz
            let h = elem.h / sz

            let pt_cnt = 3*2^MaxLod
            var α  = 3*π / 4
            var dα = 2*π / float32 pt_cnt
            for j in 0..(pt_cnt - 1):
                vtxs.add Vertex(id: id, pos: pos + vec(w*cos α, h*sin α), colour: colour)
                α -= dα

            var v = 1 # Vertex of current triangle 1/2/3
            var s = 0 # Index of current vertex
            for i in 0..MaxLoD:
                let ds = 2^(MaxLod - i)
                while true:
                    idxs.add uint16 (fst_idx + s mod pt_cnt)
                    if s + ds >= pt_cnt and v == 3:
                        break
                    elif v == 3:
                        idxs.add uint32 (fst_idx + s mod pt_cnt)
                        v = 1

                    s += ds
                    inc v
                v = 1
                s = 0

        result.tforms.add tform

    assert vtxs.len == vtxs.capacity, &"{vtxs.len} != {vtxs.capacity}"
    assert idxs.len == idxs.capacity, &"{idxs.len} != {idxs.capacity}"

    let vtxs_sz   = vtxs.len * sizeof vtxs[0]
    let idxs_sz   = idxs.len * sizeof idxs[0]
    let tforms_sz = elems.len * sizeof Mat4
    result.idx_cnt   = uint32 idxs.len
    result.tbo       = device.create_transfer_buffer vtxs_sz + idxs_sz + tforms_sz
    result.vbo       = device.create_buffer(bufUsageVertex         , vtxs_sz  , "SVG VBO")
    result.ibo       = device.create_buffer(bufUsageIndex          , idxs_sz  , "SVG IBO")
    result.tform_buf = device.create_buffer(bufUsageGraphicsStorage, tforms_sz, "SVG Transforms")

    device.copy_mem result.tbo, [
        (pointer vtxs[0].addr         , vtxs_sz),
        (pointer idxs[0].addr         , idxs_sz),
        (pointer result.tforms[0].addr, tforms_sz),
    ]

    let cmd_buf   = acquire_cmd_buf device
    let copy_pass = begin_copy_pass cmd_buf
    with copy_pass:
        upload result.tbo, result.vbo      , vtxs_sz  , trans_buf_offset = 0
        upload result.tbo, result.ibo      , idxs_sz  , trans_buf_offset = vtxs_sz
        upload result.tbo, result.tform_buf, tforms_sz, trans_buf_offset = vtxs_sz + idxs_sz
        `end`
    submit cmd_buf

proc parse_style*(style: string): Style =
    result = Style()
    var fill_opacity = 1.0'f32
    let attrs = style.split ";"
    for attr in attrs:
        let c = attr.rfind ':'
        let name = attr[0..(c - 1)]
        let val  = attr[(c + 1)..^1]
        case name
        of "fill": result.fill = parse_colour val
        of "fill-opacity": fill_opacity = parse_float val
        else:
            warn &"Ignoring SVG style of '{name}'"

    result.fill.a = uint8 255*fill_opacity

proc parse_element*(node: XmlNode): Element =
    try:
        let id    = node.attr "id"
        let style = parse_style node.attr "style"
        case node.tag
        of "rect":
            result = Element(kind: ekRect, id: id, style: style)
            result.pos = [float32 parse_float node.attr "x",
                          float32 parse_float node.attr "y"]
            result.w = parse_float node.attr "width"
            result.h = parse_float node.attr "height"
        of "circle", "ellipse":
            result = Element(kind: ekEllipse, id: id, style: style)
            result.pos = [float32 parse_float node.attr "cx",
                          float32 parse_float node.attr "cy"]
            if node.tag == "circle":
                result.w = parse_float node.attr "r"
                result.h = result.w
            else:
                result.w = parse_float node.attr "rx"
                result.h = parse_float node.attr "ry"
        else:
            error "Failed to parse element: " & node.tag
            result = Element(id: id, style: style)

        result.pos += 0.5*vec(result.w, result.h)
    except ValueError:
        error &"Failed to parse element '{node}'"
        result = Element()

proc load*(path: string): tuple[elems: seq[Element]; w, h: float32] {.raises: [].} =
    result = (elems: @[], w: 0, h: 0)
    let xml = try: load_xml(path, xml_errs, options = {})
    except:
        error "Failed to load SVG file: " & path
        return

    if xml_errs.len > 0:
        error &"XML parsing error in svg file '{path}'"
        for err in xml_errs:
            warn err

        xml_errs.set_len 0

    result.w = float32 parse_measurement xml.attr "width"
    result.h = float32 parse_measurement xml.attr "height"
    for node in xml:
        case node.tag
        of "defs":
            if node.len > 0:
                assert false
        of "g":
            for child in node:
                result.elems.add parse_element child
        else:
            result.elems.add parse_element node

    info &"Loaded SVG file with canvas size {result.w:.3f}x{result.h:.3f} containing {result.elems.len} elements"
