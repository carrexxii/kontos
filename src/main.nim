import sdl, sdl/gpu, ui

sdl.init (initVideo or initEvents)
let device = create_device(shaderFmtSpirV, true)
let window = create_window("GPU Test", 1280, 800, winNone)
device.claim window

ui.init device, window

echo " === Starting Main Loop === "
var running = true
while running:
    for event in events():
        case event.kind
        of eventQuit:
            running = false
        of eventKeyDown:
            case event.kb.key
            of kcEscape: running = false
            else: discard
        else: discard

    let
        cmd_buf = acquire_cmd_buf device
        screen  = cmd_buf.swapchain_tex window
        target_info = ColourTargetInfo(
            tex         : screen.tex,
            clear_colour: fcolour(0.12, 0.28, 0.36),
            load_op     : loadClear,
            store_op    : storeStore,
        )

    ui.update device, cmd_buf

    let ren_pass = begin_render_pass(cmd_buf, [target_info])
    ui.draw ren_pass, cmd_buf
    `end` ren_pass
    submit cmd_buf

ui.free device
destroy device
sdl.quit()
