#!/usr/bin/env python3
"""Compute Spike ISA string like SimpleSystem::GetIsaString for an Ibex config."""
import os
import subprocess
import sys
from pathlib import Path


def ibex_root() -> Path:
    env = os.environ.get("IBEX_ROOT")
    if env:
        return Path(env)
    return Path(__file__).resolve().parents[4]


def parse_fusesoc_opts(config: str) -> dict[str, str]:
    root = ibex_root()
    out = subprocess.check_output(
        [str(root / "util/ibex_config.py"), config, "fusesoc_opts"],
        text=True,
        cwd=root,
    ).strip()
    opts: dict[str, str] = {}
    for tok in out.split():
        if tok.startswith("--") and "=" in tok:
            k, v = tok[2:].split("=", 1)
            opts[k] = v
    return opts


def isa_string(opts: dict[str, str]) -> str:
    rv32e = opts.get("RV32E", "0") == "1"
    base = "rv32e" if rv32e else "rv32i"
    extensions = ""
    rv32m = opts.get("RV32M", "ibex_pkg::RV32MNone")
    if "RV32MNone" not in rv32m:
        extensions += "m"
    extensions += "c"
    rv32b = opts.get("RV32B", "ibex_pkg::RV32BNone")
    if "RV32BBalanced" in rv32b:
        extensions += "_Zba_Zbb_Zbs_XZbf_XZbt"
    elif "RV32BOTEarlGrey" in rv32b:
        extensions += "_Zba_Zbb_Zbc_Zbs_XZbf_XZbp_XZbr_XZbt"
    elif "RV32BFull" in rv32b:
        extensions += "_Zba_Zbb_Zbc_Zbs_XZbe_XZbf_XZbp_XZbr_XZbt"
    return base + extensions


def main() -> None:
    if len(sys.argv) != 2:
        print(f"usage: {sys.argv[0]} <ibex_config>", file=sys.stderr)
        sys.exit(2)
    print(isa_string(parse_fusesoc_opts(sys.argv[1])))


if __name__ == "__main__":
    main()
