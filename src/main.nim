import sdl, sdl/gpu, nuklear as nk, ui

sdl.init (initVideo or initEvents)
let device = create_device(shaderFmtSpirV, true)
let window = create_window("GPU Test", 1280, 800, winNone)
device.claim window

ui.init device, window

echo " === Starting Main Loop === "
var running = true
while running:
    nk_input_begin nk_context.addr
    for event in events():
        case event.kind
        of eventQuit:
            running = false
        of eventKeyDown, eventKeyUp:
            case event.kb.key
            of kcEscape: running = false
            of kcDelete   : nk_context.addr.nk_input_key keyDel      , event.kb.down
            of kcReturn   : nk_context.addr.nk_input_key keyEnter    , event.kb.down
            of kcTab      : nk_context.addr.nk_input_key keyTab      , event.kb.down
            of kcBackspace: nk_context.addr.nk_input_key keyBackspace, event.kb.down
            of kcLeft     : nk_context.addr.nk_input_key keyLeft     , event.kb.down
            of kcRight    : nk_context.addr.nk_input_key keyRight    , event.kb.down
            of kcUp       : nk_context.addr.nk_input_key keyUp       , event.kb.down
            of kcDown     : nk_context.addr.nk_input_key keyDown     , event.kb.down
            else: discard
        of eventMouseButtonDown, eventMouseButtonUp:
            case event.btn.btn
            of mbLeft  : nk_context.addr.nk_input_button btnLeft  , cint event.btn.x, cint event.btn.y, event.btn.down
            of mbMiddle: nk_context.addr.nk_input_button btnMiddle, cint event.btn.x, cint event.btn.y, event.btn.down
            of mbRight : nk_context.addr.nk_input_button btnRight , cint event.btn.x, cint event.btn.y, event.btn.down
            else:
                discard
        of eventMouseMotion:
            nk_context.addr.nk_input_motion cint event.motion.x, cint event.motion.y
        else: discard
    nk_input_end nk_context.addr

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
