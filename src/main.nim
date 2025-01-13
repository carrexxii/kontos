import
    sdl, ngm,
    common, ui, project, resmgr, input, tilemap, renderer, svg
import nuklear except Vec2

var camera = Camera2D()
var map: Tilemap

proc shutdown*(_: KeyCode; _: bool) {.noReturn.} =
    info "Shutting down..."
    `=destroy` map
    resmgr.cleanup()
    ui.cleanup()
    renderer.cleanup()
    sdl.quit()
    info "Shutdown Complete"
    quit 0

proc move_cam(key: KeyCode; was_down: bool) =
    case key
    of kcW: camera.dir[1] = if was_down: -1 elif camera.dir.y !=  1: 0 else: camera.dir[1]
    of kcA: camera.dir[0] = if was_down:  1 elif camera.dir.x != -1: 0 else: camera.dir[0]
    of kcS: camera.dir[1] = if was_down:  1 elif camera.dir.y != -1: 0 else: camera.dir[1]
    of kcD: camera.dir[0] = if was_down: -1 elif camera.dir.x !=  1: 0 else: camera.dir[0]
    else:
        assert false, $key

var start_time: Nanoseconds
proc init*() =
    info &"Starting initialization... ({BuildKind} Build)"
    init SdlInitFlags
    start_time = get_ticks()
    renderer.init()
    ui.init()

    project.set_path "tests/Test Project.ktsproj"

    camera = create_camera2d(
        view_w = float32 window_size.w,
        view_h = float32 window_size.h,
    )

    kcEscape.map shutdown
    kcQ.map proc(_: KeyCode; was_down: bool) = camera.zoom_state = if was_down and camera.zoom_state != zsOut: zsIn  else: zsNone
    kcE.map proc(_: KeyCode; was_down: bool) = camera.zoom_state = if was_down and camera.zoom_state != zsIn : zsOut else: zsNone

    move_cam.map [kcW, kcA, kcS, kcD]

    let (elems, cw, ch) = svg.load "tests/test.svg"
    let g = triangulate(elems, cw, ch)
    renderer.add g

    info "Initialization complete"

proc loop*() {.raises: [].} =
    info &" === Starting Main Loop === {ns_to_ms (get_ticks() - start_time)})"
    var ot, nt, dt, acc: Nanoseconds
    ot = get_ticks()
    while true:
        nt = get_ticks()
        dt = nt - ot
        ot = nt
        acc += dt

        let dt_s = (float32 dt) / 1000_000_000
        while acc >= target_dt:
            acc -= target_dt

            input.update()
            camera.update dt_s

        renderer.draw camera

init()
loop()
