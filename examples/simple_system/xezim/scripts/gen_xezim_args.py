#!/usr/bin/env python3
"""Run fusesoc for ibex_simple_system_cosim and write an xezim -f file."""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path


def ibex_root() -> Path:
    env = os.environ.get("IBEX_ROOT")
    if env:
        return Path(env)
    return Path(__file__).resolve().parents[4]


def fusesoc_opts(ibex: Path, config: str) -> list[str]:
    out = subprocess.check_output(
        [str(ibex / "util/ibex_config.py"), config, "fusesoc_opts"],
        text=True,
        cwd=ibex,
    )
    return out.split()


def fusesoc_setup(ibex: Path, config: str) -> None:
    opts = fusesoc_opts(ibex, config)
    subprocess.check_call(
        [
            "fusesoc",
            f"--cores-root={ibex}",
            "run",
            "--target=sim",
            "--setup",
            "lowrisc:ibex:ibex_simple_system_cosim",
            *opts,
        ],
        cwd=ibex,
    )


def ibex_rel(ibex: Path, p: Path) -> str:
    try:
        rel = p.resolve().relative_to(ibex.resolve())
        return "${IBEX_ROOT}/" + rel.as_posix()
    except ValueError:
        return str(p)


def main() -> None:
    if len(sys.argv) != 2:
        print(f"usage: {sys.argv[0]} <ibex_config>", file=sys.stderr)
        sys.exit(2)
    config = sys.argv[1]
    ibex = ibex_root()
    xezim_dir = ibex / "examples/simple_system/xezim"

    build = ibex / "build/lowrisc_ibex_ibex_simple_system_cosim_0/sim-verilator"
    vc = build / "lowrisc_ibex_ibex_simple_system_cosim_0.vc"
    if not vc.is_file():
        fusesoc_setup(ibex, config)

    sim_dir = vc.parent
    lines_out: list[str] = [
        "-timescale 1ns/1ps",
        "-s ibex_simple_system",
        "-s ibex_simple_system_cosim_checker_bind",
        "+define+RVFI=1",
    ]
    for tok in fusesoc_opts(ibex, config):
        if not tok.startswith("--"):
            continue
        key, val = tok[2:].split("=", 1)
        if key in ("RV32M", "RV32B", "RegFile"):
            lines_out.append(f"+define+{key}={val}")
        else:
            lines_out.append(f"-g/ibex_simple_system/{key}={val}")

    skip_suffix = {
        ".vlt",
        ".cc",
        ".cpp",
        ".c",
        ".h",
        ".mk",
        ".yml",
        ".yaml",
        ".vc",
    }
    for raw in vc.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith(("--", "-CFLAGS", "-Mdir", "-cc")):
            continue
        # The .vc is reused across configs, so its -G values belong to whichever
        # config ran the fusesoc setup; the parameters above come from this one.
        if line.startswith("-G"):
            continue
        if line.startswith("+incdir+"):
            rel = line[len("+incdir+") :]
            lines_out.append(f"+incdir+{ibex_rel(ibex, sim_dir / rel)}")
            continue
        if any(line.endswith(s) for s in skip_suffix):
            continue
        if line.startswith("src/"):
            path = sim_dir / line
            if path.name == "ibex_simple_system_cosim_checker_bind.sv":
                continue
            lines_out.append(ibex_rel(ibex, path))
        elif line.endswith((".sv", ".svh")):
            p = sim_dir / line
            if p.is_file():
                lines_out.append(ibex_rel(ibex, p))

    lines_out.append(ibex_rel(ibex, xezim_dir / "xezim_ibex_simple_system_cosim_checker_bind.sv"))
    lines_out.append(ibex_rel(ibex, xezim_dir / "xezim_ss_io_drive.sv"))

    out_dir = ibex / "build/xezim/simple_system_cosim/args"
    out_dir.mkdir(parents=True, exist_ok=True)
    out = out_dir / f"{config}.f"
    out.write_text("\n".join(lines_out) + "\n")
    print(f"wrote {out}")


if __name__ == "__main__":
    main()
