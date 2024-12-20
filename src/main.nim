import
    std/options,
    sdl, sdl/gpu, ngm,
    common, ui, project, resmgr, input, tilemap, renderer
import nuklear except Vec2

var camera: Camera3D
var map: Tilemap

proc shutdown(_: bool) {.noReturn.} =
    info "Shutting down..."
    resmgr.cleanup()
    ui.cleanup()
    renderer.cleanup()
    sdl.quit()
    info "Shutdown Complete"
    quit 0

proc init*() =
    info "Starting initialization..."
    init SdlInitFlags
    renderer.init()
    ui.init()

    project.set_path "tests/Test Project.ktsproj"

    camera = Camera3D(proj: perspective_default (window_size.x / window_size.y))

    kcEscape.map shutdown
    kcQ.map proc(_: bool) = camera.move cdUp
    kcE.map proc(_: bool) = camera.move cdDown
    kcW.map proc(_: bool) = camera.move cdForwards
    kcA.map proc(_: bool) = camera.move cdLeft
    kcS.map proc(_: bool) = camera.move cdBackwards
    kcD.map proc(_: bool) = camera.move cdRight

    renderer.add load_model "tests/res/models/fish.nai"

    map = tilemap.create(64, 32)
    # set_map map.addr

    kcBackspace.map proc(was_down: bool) =
        camera.pos = vec3( 1,  1,  0)
        camera.dir = vec3(-1, -1,  0)
        camera.up  = vec3( 0,  0, -1)
    map_motion proc(pos, delta: Vec2) =
        if modifiers[imRmb]:
            camera.roll -delta.x*0.005'rad
            if delta.y > 0:
                camera.move cdForwards
            elif delta.y < 0:
                camera.move cdBackwards
        else:
            camera.yaw   -delta.x*0.005'rad
            camera.pitch -delta.y*0.005'rad

    info "Initialization complete"

proc loop*() =
    info " === Starting Main Loop === "
    var running = true
    while running:
        input.update()
        update camera
        draw camera.view, camera.proj

init()
loop()
shutdown true
