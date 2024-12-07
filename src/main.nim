import
    sdl, sdl/gpu, nuklear as nk,
    common, ui, project

var window_w = 1280
var window_h = 800

sdl.init (initVideo or initEvents)
let device = create_device(shaderFmtSpirV, true)
let window = create_window("GPU Test", window_w, window_h, winNone)
device.claim window

ui.init device, window

info " === Starting Main Loop === "
var running = true
while running:
    begin_input ui_ctx
    for event in events():
        case event.kind
        of eventQuit:
            info "Quitting..."
            running = false
        of eventKeyDown, eventKeyUp:
            case event.kb.key
            of kcEscape: running = false
            of kcDelete   : ui_ctx.input_key kkDel      , event.kb.down
            of kcReturn   : ui_ctx.input_key kkEnter    , event.kb.down
            of kcTab      : ui_ctx.input_key kkTab      , event.kb.down
            of kcBackspace: ui_ctx.input_key kkBackspace, event.kb.down
            of kcLeft     : ui_ctx.input_key kkLeft     , event.kb.down
            of kcRight    : ui_ctx.input_key kkRight    , event.kb.down
            of kcUp       : ui_ctx.input_key kkUp       , event.kb.down
            of kcDown     : ui_ctx.input_key kkDown     , event.kb.down
            else: discard
        of eventMouseButtonDown, eventMouseButtonUp:
            case event.btn.btn
            of mbLeft  : ui_ctx.input_button bLeft  , event.btn.x, event.btn.y, event.btn.down
            of mbMiddle: ui_ctx.input_button bMiddle, event.btn.x, event.btn.y, event.btn.down
            of mbRight : ui_ctx.input_button bRight , event.btn.x, event.btn.y, event.btn.down
            else:
                discard
        of eventMouseMotion:
            ui_ctx.input_motion event.motion.x, event.motion.y
        else:
            discard
    end_input ui_ctx

    let
        cmd_buf = acquire_cmd_buf device
        screen  = cmd_buf.swapchain_tex window
        target_info = ColourTargetInfo(
            tex         : screen.tex,
            clear_colour: fcolour(0.12, 0.28, 0.36),
            load_op     : loadClear,
            store_op    : storeStore,
        )

    ui.update device, cmd_buf, window_w, window_h

    let ren_pass = begin_render_pass(cmd_buf, [target_info])
    ui.draw ren_pass, cmd_buf
    `end` ren_pass
    submit cmd_buf

ui.free device
destroy device
sdl.quit()
debug " === Shutdown Complete === "
