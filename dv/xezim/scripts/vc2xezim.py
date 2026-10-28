#!/usr/bin/env python3
"""Convert a Verilator .vc file from fusesoc into an xezim -f argument file."""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

SKIP_PREFIXES = (
    "--Mdir",
    "--cc",
    "--exe",
    "--top-module",
    "-LDFLAGS",
    "-CFLAGS",
    "-L",
)
SKIP_EXTS = {".vlt", ".cc", ".c", ".cpp"}


def _ibex_rel(ibex_root: Path, p: Path) -> str:
    try:
        rel = p.resolve().relative_to(ibex_root.resolve())
        return "${IBEX_ROOT}/" + rel.as_posix()
    except ValueError:
        return str(p)


def convert(
    vc_path: Path,
    out_path: Path,
    build_root: Path,
    ibex_root: Path,
    top: str,
    extra_sv: list[Path],
    replace_sv: dict[Path, Path],
    param_lines: list[str],
) -> None:
    lines: list[str] = [f"-s {top}", "-timescale 1ns/1ps", "+define+INC_ASSERT"]
    seen_incdir: set[str] = set()

    for raw in vc_path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if any(line.startswith(p) for p in SKIP_PREFIXES):
            continue
        if line.startswith("+incdir+"):
            p = line[len("+incdir+") :]
            if p not in seen_incdir:
                seen_incdir.add(p)
                lines.append(f"+incdir+{_ibex_rel(ibex_root, build_root / p)}")
            continue
        if line.startswith("-D"):
            lines.append(f"+define+{line[2:]}")
            continue
        if line.startswith("-G"):
            m = re.match(r"-G([^=]+)=(.+)", line)
            if m:
                lines.append(f"-g{m.group(1)}={m.group(2)}")
            continue
        if line.startswith("-"):
            continue
        if any(line.endswith(ext) for ext in SKIP_EXTS):
            continue
        if not line.endswith((".sv", ".svh", ".v")):
            continue
        src = build_root / line
        for old, new in replace_sv.items():
            if src == old:
                src = new
                break
        lines.append(_ibex_rel(ibex_root, src))

    for p in extra_sv:
        lines.append(_ibex_rel(ibex_root, p))

    for pl in param_lines:
        lines.append(pl)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text("\n".join(lines) + "\n")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("vc")
    ap.add_argument("out")
    ap.add_argument("--build-root", required=True)
    ap.add_argument("--ibex-root", required=True, help="Ibex repo root; paths become ${IBEX_ROOT}/...")
    ap.add_argument("-s", "--top", required=True)
    ap.add_argument("--extra-sv", action="append", default=[], type=Path)
    ap.add_argument("--replace-sv", nargs=2, action="append", default=[], metavar=("FROM", "TO"))
    ap.add_argument("--param-file")
    args = ap.parse_args()

    build_root = Path(args.build_root)
    replace = {Path(a): Path(b) for a, b in args.replace_sv}
    params: list[str] = []
    if args.param_file:
        params = [
            ln.strip()
            for ln in Path(args.param_file).read_text().splitlines()
            if ln.strip() and not ln.startswith("#")
        ]

    convert(
        Path(args.vc),
        Path(args.out),
        build_root,
        Path(args.ibex_root),
        args.top,
        args.extra_sv,
        replace,
        params,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
