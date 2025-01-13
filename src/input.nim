import std/tables, sdl/[events, mouse], ngm/vector, common
import nuklear except Table, Vec2, MouseButton
from ui import context

const DefaultKeyMaps = 4

type
    KeyCallback*    = proc(key: KeyCode; was_down: bool)
    MouseCallback*  = proc(btn: MouseButton; was_down: bool; pos: Vec2)
    MotionCallback* = proc(pos, delta: Vec2)

    InputModifier* = enum
        imLCtrl
        imRCtrl
        imLShift
        imRShift
        imLAlt
        imRAlt
        imLmb
        imRmb
        imMmb

var
    modifiers*: array[InputModifier, bool]

    keys     : seq[tuple[code: KeyCode, fn: KeyCallback]]
    key_map  : Table[KeyCode    , seq[KeyCallback]]
    mouse_map: Table[MouseButton, seq[MouseCallback]]
    motion_cbs = new_seq_of_cap[MotionCallback] DefaultKeyMaps

proc map*(key: KeyCode; cb: KeyCallback) =
    if key notin key_map:
        key_map[key] = new_seq_of_cap[KeyCallback] DefaultKeyMaps
    key_map[key].add cb

proc map*(cb: KeyCallback; keys: openArray[KeyCode]) =
    for key in keys:
        key.map cb

proc map*(btn: MouseButton; cb: MouseCallback) =
    if btn notin mouse_map:
        mouse_map[btn] = new_seq_of_cap[MouseCallback] DefaultKeyMaps
    mouse_map[btn].add cb

proc map_motion*(cb: MotionCallback) =
    motion_cbs.add cb

proc update*() {.raises: [].} =
    begin_input ui.context
    for event in events():
        case event.kind
        of eventQuit:
            info "Quitting..."
            quit 0
        of eventKeyDown, eventKeyUp:
            let key      = event.kb.key
            let was_down = event.kb.down
            case key
            of kcDelete   : ui.context.input_key kkDel      , was_down
            of kcReturn   : ui.context.input_key kkEnter    , was_down
            of kcTab      : ui.context.input_key kkTab      , was_down
            of kcBackspace: ui.context.input_key kkBackspace, was_down
            of kcLeft     : ui.context.input_key kkLeft     , was_down
            of kcRight    : ui.context.input_key kkRight    , was_down
            of kcUp       : ui.context.input_key kkUp       , was_down
            of kcDown     : ui.context.input_key kkDown     , was_down
            of kcLCtrl : modifiers[imLCtrl]  = was_down
            of kcRCtrl : modifiers[imRCtrl]  = was_down
            of kcLShift: modifiers[imLShift] = was_down
            of kcRShift: modifiers[imRShift] = was_down
            of kcLAlt  : modifiers[imLAlt]   = was_down
            of kcRAlt  : modifiers[imRAlt]   = was_down
            else:
                discard

            if event.kb.repeat or key notin key_map:
                continue
            {.cast(raises: []).}:
                for fn in key_map[key]:
                    if was_down:
                        keys.add (key, fn)
                    else:
                        # Might want to improve this, but keys.len will probably always be a single digit
                        for i in 0..<keys.len:
                            if keys[i].code == key:
                                keys.del i
                                break
                        fn key, was_down
        of eventMouseButtonDown, eventMouseButtonUp:
            let btn      = event.btn.btn
            let pos      = vec2(event.btn.x, event.btn.y)
            let was_down = event.btn.down
            case btn
            of mbLeft:
                ui.context.input_button bLeft, pos.x, pos.y, was_down
                modifiers[imLmb] = was_down
            of mbMiddle:
                ui.context.input_button bMiddle, pos.x, pos.y, was_down
                modifiers[imMmb] = was_down
            of mbRight:
                ui.context.input_button bRight, pos.x, pos.y, was_down
                modifiers[imRmb] = was_down
            else:
                discard
        
            if btn in mouse_map:
                {.cast(raises: []).}:
                    for fn in mouse_map[btn]:
                        fn btn, was_down, pos
        of eventMouseMotion:
            let pos   = vec2(event.motion.x    , event.motion.y)
            let delta = vec2(event.motion.x_rel, event.motion.y_rel)
            ui.context.input_motion pos.x, pos.y
            for fn in motion_cbs:
                {.cast(raises: []).}:
                    fn pos, delta
        of eventTextInput:
            for c in event.text.text:
                ui.context.input_char c
        else:
            discard
    end_input ui.context

    for (code, fn) in keys:
        {.cast(raises: []).}:
            fn code, true
