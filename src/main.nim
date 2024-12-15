import
    std/options,
    sdl, sdl/gpu, nuklear as nk, ngm,
    common, ui, project, resmgr, models

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

var camera = Camera3D(
    proj_kind: cpPerspective,
    pan_speed: 0.1,
    rot_speed: 0.1,
    pos      : vec3(1, 1, 1),
    target   : vec3(0, 0, 0),
    up       : vec3(0, 1, 0),
    proj     : perspective_default (window_w / window_h),
)

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

            of kcW: camera.move cdUp   
            of kcA: camera.move cdLeft 
            of kcS: camera.move cdDown 
            of kcD: camera.move cdRight
            of kcQ: camera.move cdForwards
            of kcE: camera.move cdBackwards
            else:
                discard
        of eventMouseButtonDown, eventMouseButtonUp:
            case event.btn.btn
            of mbLeft  : ui_ctx.input_button bLeft  , event.btn.x, event.btn.y, event.btn.down
            of mbMiddle: ui_ctx.input_button bMiddle, event.btn.x, event.btn.y, event.btn.down
            of mbRight : ui_ctx.input_button bRight , event.btn.x, event.btn.y, event.btn.down
            else:
                discard
        of eventMouseMotion:
            ui_ctx.input_motion event.motion.x, event.motion.y
        of eventTextInput:
            for c in event.text.text:
                ui_ctx.input_char c
        else:
            discard
    end_input ui_ctx

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

    ren_pass.draw mdl
    ui.draw ren_pass, cmd_buf
    `end` ren_pass
    submit cmd_buf

resmgr.cleanup device
models.cleanup device
ui.free device
device.destroy depth_tex
destroy device
sdl.quit()
info " === Shutdown Complete === "
