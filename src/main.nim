import
    std/options,
    sdl, sdl/gpu, ngm,
    common, ui, project, resmgr, models, input, tilemap
import nuklear except Vec2

proc shutdown(_: bool) =
    quit 0

var window_w = 1280
var window_h = 800

sdl.init (initVideo or initEvents)
let device = create_device(shaderFmtSpirV, true)
let window = create_window("GPU Test", window_w, window_h, winNone)
device.claim window

let depth_tex = device.create_texture(window_w, window_h, fmt = texFmtD16Unorm, usage = texUsageDepthStencilTarget)
device.set_tex_name depth_tex, "Depth Texture"

ui.init device, window
models.init device, window

project.set_path "tests/Test Project.ktsproj"
let mdl = device.load_model "tests/res/models/fish.nai"

tilemap.init device, window
let map = tilemap.create(64, 32)

var camera = Camera3D(proj: perspective_default (window_w / window_h))

kcEscape.map shutdown
kcQ.map proc(was_down: bool) = camera.move cdUp
kcE.map proc(was_down: bool) = camera.move cdDown
kcW.map proc(was_down: bool) = camera.move cdForwards
kcA.map proc(was_down: bool) = camera.move cdLeft
kcS.map proc(was_down: bool) = camera.move cdBackwards
kcD.map proc(was_down: bool) = camera.move cdRight

kcBackspace.map proc(was_down: bool) =
    camera.pos = vec3( 1,  1,  0)
    camera.dir = vec3(-1, -1,  0)
    camera.up  = vec3( 0,  0, -1)
map_motion proc(pos, delta: Vec2) =
    if modifiers[imRmb]:
        camera.roll -delta.x*0.005'rad
        camera.move cdForwards
    else:
        camera.yaw   -delta.x*0.005'rad
        camera.pitch -delta.y*0.005'rad

info " === Starting Main Loop === "
var running = true
while running:
    input.update()
    update camera
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

    ui.update device, cmd_buf, window, window_w, window_h

    let ren_pass = begin_render_pass(cmd_buf, [target_info], some depth_info)
    cmd_buf.push_vtx_uniform 0, [camera.proj, camera.view]
    with ren_pass:
        draw mdl
        draw map
        ui.draw cmd_buf
        `end`
    submit cmd_buf

resmgr.cleanup device
models.cleanup device
ui.free device
device.destroy depth_tex
destroy device
sdl.quit()
info " === Shutdown Complete === "
