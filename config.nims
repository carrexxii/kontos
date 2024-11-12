import std/[os, strformat]

const
    src_dir = "./src"
    lib_dir = "./lib"
    entry   = src_dir / "main.nim"
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

task run, "Run":
    exec &"nim c -r {entry}"

