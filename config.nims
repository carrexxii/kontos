import std/[os, strformat, strutils]

const
    src_dir    = "./src"
    lib_dir    = "./lib"
    res_dir    = "./res"
    shader_src = src_dir / "shaders"
    shader_out = res_dir / "shaders"
    entry = src_dir / "main.nim"
    deps: seq[tuple[src, dst, tag: string; cmds: seq[string]]] = @[
        (src  : "https://github.com/carrexxii/sdl-nim",
         dst  : lib_dir / "sdl-nim",
         tag  : "",
         cmds : @[&"nim restore --skipParentCfg"]),
        (src  : "https://github.com/carrexxii/nuklear-nim",
         dst  : lib_dir / "nuklear-nim",
         tag  : "",
         cmds : @[&"nim restore --skipParentCfg"]),
    ]

var cmd_count = 0
proc run(cmd: string) =
    if defined `dry-run`:
        echo &"[{cmd_count}] {cmd}"
        inc cmd_count
    else:
        exec cmd

task restore, "Restore and build":
    run "git submodule update --init --remote --merge -j 8"
    for dep in deps:
        with_dir dep.dst:
            run &"git checkout {dep.tag}"
            for cmd in dep.cmds:
                run cmd

task build_shaders, "Build shaders":
    let shaders = list_files shader_src
    for shader in shaders:
        let fname = shader.split_path.tail
        run &"""glslangValidator {shader} -V -S vert -o {shader_out / fname.replace(".glsl", ".vert.spv")} --quiet -DVERTEX"""
        run &"""glslangValidator {shader} -V -S frag -o {shader_out / fname.replace(".glsl", ".frag.spv")} --quiet -DFRAGMENT"""

task run, "Run":
    build_shaders_task()
    run &"nim c -r {entry}"
