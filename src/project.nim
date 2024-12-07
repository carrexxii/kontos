import std/[os, streams, paths, marshal, json], common

const ProjectFileExtension = "ktsproj"

type Project* = object
    path: string = current_source_path()

    name*: string

var proj: Project

proc set_path*(path: string) =
    let path = absolute_path path
    proj.path = path.add_file_ext ProjectFileExtension
    proj.name = (split_file proj.path).name

proc load*(path: string): bool =
    result = true
    if not file_exists path:
        error &"Project file '{path}' does not exist"
        return false
    
    proj = (read_file path).to[:Project]
    info &"Loaded project file '{proj.name}' ({proj.path})"
    debug $proj

proc save*(): bool =
    result = true
    let (dir, name, ext) = split_file proj.path
    if proj.path.len == 0:
        debug "Project path is not set"
        return false
    elif not dir_exists dir:
        debug "Project directory does not exist"
        return false

    let file = open_file_stream(proj.path, fmWrite)
    file.write pretty parse_json $$proj
    close file
    info &"Saved project '{proj.name}' to '{proj.path}'"
