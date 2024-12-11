import std/[os, streams, marshal, json], common

const ProjectFileExtension = "ktsproj"

type Project* = object
    path: string = current_source_path()
    name: string

var proj: Project

proc get_path*(): string = proj.path

proc set_path*(path: string) =
    let path = absolute_path path
    proj.path = path.add_file_ext ProjectFileExtension
    proj.name = (split_file proj.path).name

proc load*(path: string) =
    let path = expand_tilde path
    if not file_exists path:
        error &"Project file '{path}' does not exist"

    try:
        proj = (read_file path).to[:Project]
        info &"Loaded project file '{proj.name}' ({proj.path})"
        debug $proj
    except:
        error &"Failed to load project file '{path}'"

proc save*(): bool =
    result = true
    let (dir, name, ext) = split_file proj.path
    if proj.path.len == 0:
        debug "Project path is not set"
        return false
    elif not dir_exists dir:
        debug &"Project directory '{dir}' does not exist"
        return false

    let file = open_file_stream(proj.path, fmWrite)
    file.write pretty parse_json $$proj
    close file
    info &"Saved project '{proj.name}' to '{proj.path}'"

proc save_as*(path: string) =
    ## Discards boolean for use with `save_file_dialog`
    set_path path
    discard save()
