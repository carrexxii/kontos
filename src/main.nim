import sdl, sdl/gpu, nuklear

sdl.init (initVideo or initEvents)
let device = create_device(shaderFmtSpirV, true)
let window = create_window("GPU Test", 1280, 800, winNone)
device.claim window

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

destroy device
sdl.quit()

