version      = "0.0.1"
author       = "carrexxii"
description  = ""
license      = ""
src_dir      = "src"
bin          = @["main"]
entry_points = @["src/main.nim"]

requires "nim >= 2.0.0"

#[ -------------------------------------------------------------------- ]#

import std/[os, strformat]

before build:
    let shaders = list_files "src/shaders"
    for shader in shaders:
        let fname = shader.split_path.tail
        if fname.ends_with ".comp":
            exec &"""glslangValidator {shader} -V -S comp -o res/shaders/{fname.replace(".comp", ".comp.spv")} --quiet"""
        else:
            exec &"""glslangValidator {shader} -V -S vert -o res/shaders/{fname.replace(".glsl", ".vert.spv")} --quiet -DVERTEX"""
            exec &"""glslangValidator {shader} -V -S frag -o res/shaders/{fname.replace(".glsl", ".frag.spv")} --quiet -DFRAGMENT"""
