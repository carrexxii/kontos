import std/tables, sdl/[events, mouse], ngm/vector, common
import nuklear except Table, Vec2, MouseButton
from ui import ui_ctx

const DefaultKeyMaps = 4

type
    KeyCallback*    = proc(down: bool) {.nimcall.}
    MouseCallback*  = proc(pos: Vec2; down: bool)
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
    
    key_map  : Table[KeyCode    , seq[KeyCallback]]
    mouse_map: Table[MouseButton, seq[MouseCallback]]
    motion_cbs = new_seq_of_cap[MotionCallback] DefaultKeyMaps

proc map*(key: KeyCode; cb: KeyCallback) =
    if key notin key_map:
        key_map[key] = new_seq_of_cap[KeyCallback] DefaultKeyMaps
    key_map[key].add cb

proc map*(btn: MouseButton; cb: MouseCallback) =
    if btn notin mouse_map:
        mouse_map[btn] = new_seq_of_cap[MouseCallback] DefaultKeyMaps
    mouse_map[btn].add cb

proc map_motion*(cb: MotionCallback) =
    motion_cbs.add cb

proc update*() =
    begin_input ui_ctx
    for event in events():
        case event.kind
        of eventQuit:
            info "Quitting..."
            quit 0
        of eventKeyDown, eventKeyUp:
            let key      = event.kb.key
            let was_down = event.kb.down
            case key
            of kcDelete   : ui_ctx.input_key kkDel      , was_down
            of kcReturn   : ui_ctx.input_key kkEnter    , was_down
            of kcTab      : ui_ctx.input_key kkTab      , was_down
            of kcBackspace: ui_ctx.input_key kkBackspace, was_down
            of kcLeft     : ui_ctx.input_key kkLeft     , was_down
            of kcRight    : ui_ctx.input_key kkRight    , was_down
            of kcUp       : ui_ctx.input_key kkUp       , was_down
            of kcDown     : ui_ctx.input_key kkDown     , was_down
            of kcLCtrl : modifiers[imLCtrl]  = was_down
            of kcRCtrl : modifiers[imRCtrl]  = was_down
            of kcLShift: modifiers[imLShift] = was_down
            of kcRShift: modifiers[imRShift] = was_down
            of kcLAlt  : modifiers[imLAlt]   = was_down
            of kcRAlt  : modifiers[imRAlt]   = was_down
            else:
                discard

            if key in key_map:
                for fn in key_map[key]:
                    fn was_down
        of eventMouseButtonDown, eventMouseButtonUp:
            let btn      = event.btn.btn
            let pos      = vec2(event.btn.x, event.btn.y)
            let was_down = event.btn.down
            case btn
            of mbLeft:
                ui_ctx.input_button bLeft, pos.x, pos.y, was_down
                modifiers[imLmb] = was_down
            of mbMiddle:
                ui_ctx.input_button bMiddle, pos.x, pos.y, was_down
                modifiers[imMmb] = was_down
            of mbRight:
                ui_ctx.input_button bRight, pos.x, pos.y, was_down
                modifiers[imRmb] = was_down
            else:
                discard
        
            if btn in mouse_map:
                for fn in mouse_map[btn]:
                    fn pos, was_down
        of eventMouseMotion:
            let pos   = vec2(event.motion.x    , event.motion.y)
            let delta = vec2(event.motion.x_rel, event.motion.y_rel)
            ui_ctx.input_motion pos.x, pos.y
            for fn in motion_cbs:
                fn pos, delta
        of eventTextInput:
            for c in event.text.text:
                ui_ctx.input_char c
        else:
            discard
    end_input ui_ctx
