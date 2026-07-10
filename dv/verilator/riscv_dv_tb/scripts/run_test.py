#!/usr/bin/env python3
# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Run riscv_rand_instr_test on the Verilator riscv-dv TB.

Flow:
  1. pyflow generate (Ibex asm program gen) -> test.S
  2. RISC-V GCC compile -> test.o / test.bin
  3. FuseSoC build Verilator sim (cached)
  4. Run sim with --bin=test.bin (+ optional Spike cosim)

Output layout matches UVM core_ibex / SMDB fixtures under
smdb/tests/data/bugs/ibex/*/run/:

  <out>/
    run/
      regr.log
      report.json
      tests/
        riscv_rand_instr_test.<seed>/
          test.S
          test.o
          test.bin
          gen.log
          compile_gen.riscv-dv.log
          compile.riscvdv.log
          rtl_sim.log
          rtl_sim_stdstreams.log
          waves.fst
          trace_core_00000000.log
          trr.yaml
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[4]
RISCV_DV = REPO_ROOT / "vendor" / "google_riscv-dv"
TB_DIR = Path(__file__).resolve().parents[1]
DEFAULT_OUT = TB_DIR / "out"
TEST_NAME = "riscv_rand_instr_test"


def run(cmd, cwd=None, env=None, check=True, log_file=None):
    print("+", " ".join(str(c) for c in cmd), flush=True)
    if log_file is None:
        return subprocess.run(cmd, cwd=cwd, env=env, check=check)
    with open(log_file, "w") as lf:
        return subprocess.run(
            cmd, cwd=cwd, env=env, check=check,
            stdout=lf, stderr=subprocess.STDOUT)


def find_tool(names):
    for name in names:
        path = shutil.which(name)
        if path:
            return path
    return None


def test_dir(out_dir: Path, seed: int) -> Path:
    """SMDB/UVM-style per-seed test directory."""
    return out_dir / "run" / "tests" / "{}.{}".format(TEST_NAME, seed)


def step_gen(out_dir: Path, tdir: Path, seed: int, iterations: int) -> Path:
    """Generate assembly via pyflow Ibex test; copy to tdir/test.S."""
    gen_root = out_dir / "gen"
    gen_root.mkdir(parents=True, exist_ok=True)
    tdir.mkdir(parents=True, exist_ok=True)

    env = os.environ.copy()
    pygen = str(RISCV_DV / "pygen")
    env["PYTHONPATH"] = pygen + os.pathsep + env.get("PYTHONPATH", "")

    gen_log = tdir / "gen.log"
    cmd = [
        sys.executable,
        str(RISCV_DV / "run.py"),
        "--steps=gen",
        "--simulator=pyflow",
        "--target=ibex",
        "--custom_target", str(RISCV_DV / "pygen" / "pygen_src" / "target" / "ibex"),
        "--testlist", str(TB_DIR / "testlist.yaml"),
        "--test", TEST_NAME,
        "--output", str(gen_root),
        "--iterations", str(iterations),
        "--seed", str(seed),
        "--isa", "rv32imc",
        "--mabi", "ilp32",
        "--end_signature_addr", "8ffffff8",
    ]
    run(cmd, cwd=str(RISCV_DV), env=env, log_file=gen_log)

    # Also keep a copy of the pyflow sim log if present
    pyflow_log = gen_root / "sim_{}_0.log".format(TEST_NAME)
    if pyflow_log.exists():
        shutil.copy2(pyflow_log, tdir / "compile_gen.riscv-dv.log")
    else:
        (tdir / "compile_gen.riscv-dv.log").write_text(
            "pyflow gen; see gen.log\n")

    candidates = list((gen_root / "asm_test").glob("{}*.S".format(TEST_NAME)))
    if not candidates:
        candidates = list(gen_root.rglob("{}*.S".format(TEST_NAME)))
    if not candidates:
        raise FileNotFoundError("No generated .S found under {}".format(gen_root))
    asm_src = sorted(candidates)[0]
    asm = tdir / "test.S"
    shutil.copy2(asm_src, asm)
    print("Generated:", asm)
    return asm


def step_compile(asm: Path, tdir: Path) -> Path:
    """Compile assembly to test.o + test.bin in the test directory."""
    gcc = find_tool([
        "riscv32-unknown-elf-gcc",
        "riscv64-unknown-elf-gcc",
        "riscv64-elf-gcc",
    ])
    objcopy = find_tool([
        "riscv32-unknown-elf-objcopy",
        "riscv64-unknown-elf-objcopy",
        "riscv64-elf-objcopy",
    ])
    if not gcc or not objcopy:
        raise RuntimeError(
            "RISC-V GCC toolchain not found. Install riscv32-unknown-elf-gcc "
            "(or Homebrew riscv64-elf-gcc) and ensure it is on PATH.")

    link_ld = RISCV_DV / "scripts" / "link.ld"
    elf = tdir / "test.o"  # UVM/SMDB name for the ELF
    binary = tdir / "test.bin"
    compile_log = tdir / "compile.riscvdv.log"

    gcc_cmd = [
        gcc,
        "-march=rv32imc_zicsr_zifencei",
        "-mabi=ilp32",
        "-static",
        "-mcmodel=medany",
        "-fvisibility=hidden",
        "-nostdlib",
        "-nostartfiles",
        "-I", str(asm.parent),
        "-T", str(link_ld),
        str(asm),
        "-o", str(elf),
    ]
    with open(compile_log, "w") as lf:
        print("+", " ".join(str(c) for c in gcc_cmd), flush=True)
        subprocess.run(gcc_cmd, check=True, stdout=lf, stderr=subprocess.STDOUT)
        obj_cmd = [objcopy, "-O", "binary", str(elf), str(binary)]
        print("+", " ".join(str(c) for c in obj_cmd), flush=True)
        subprocess.run(obj_cmd, check=True, stdout=lf, stderr=subprocess.STDOUT)
    print("Compiled:", binary)
    return binary


def step_build_sim(ibex_config: str, stub: bool = False) -> Path:
    """Build Verilator sim via FuseSoC; return path to executable."""
    config_py = REPO_ROOT / "util" / "ibex_config.py"
    opts = subprocess.check_output(
        [sys.executable, str(config_py), ibex_config, "fusesoc_opts"],
        cwd=str(REPO_ROOT), text=True).strip().split()

    target = "sim_stub" if stub else "sim"
    sim_dir = "sim_stub-verilator" if stub else "sim-verilator"
    cmd = [
        "fusesoc", "--cores-root", str(REPO_ROOT),
        "run", "--target={}".format(target), "--setup", "--build",
        "lowrisc:ibex:ibex_riscv_dv_tb",
    ] + opts
    run(cmd, cwd=str(REPO_ROOT))

    build_root = REPO_ROOT / "build"
    matches = list(build_root.glob(
        "lowrisc_ibex_ibex_riscv_dv_tb_*/{}/Vibex_riscv_dv_tb".format(sim_dir)))
    if not matches:
        raise FileNotFoundError("Verilator sim binary not found under {}".format(build_root))
    sim = sorted(matches)[-1]
    print("Simulator:", sim)
    return sim


def write_trr_yaml(tdir: Path, seed: int, passed: bool, failure_message: str = ""):
    """Minimal trr.yaml matching UVM core_ibex fields SMDB/fixtures use."""
    lines = [
        "passed:                   {}".format(passed),
        "failure_mode:             {}".format(
            "NONE" if passed else "SIM_ERROR"),
        "failure_message:          |-",
        "  {}".format(failure_message.replace("\n", "\n  ") if failure_message else ""),
        "timeout_s:                10",
        "testtype:                 TestType.RISCVDV",
        "testdotseed:              {}.{}".format(TEST_NAME, seed),
        "testname:                 {}".format(TEST_NAME),
        "seed:                     {}".format(seed),
        "binary:                   test.bin",
        "rtl_simulator:            verilator",
        "iss_cosim:                spike",
        "gen_test:                 riscv_ibex_rand_instr_test",
        "rtl_test:                 verilator_riscv_dv_tb",
        "assembly:                 test.S",
        "objectfile:               test.o",
        "compile_asm_gen_log:      compile_gen.riscv-dv.log",
        "compile_asm_log:          compile.riscvdv.log",
        "rtl_log:                  rtl_sim.log",
        "rtl_stdout:               rtl_sim_stdstreams.log",
        "rtl_trace:                trace_core_00000000.log",
        "yaml_file:                trr.yaml",
        "",
    ]
    (tdir / "trr.yaml").write_text("\n".join(lines))


def write_report(out_dir: Path, seed: int, passed: bool):
    report = {
        "tool": "verilator",
        "block_name": "ibex",
        "block_variant": "riscv_dv_tb",
        "results": {
            "coverage": {},
            "testpoints": [],
            "unmapped_tests": [
                {
                    "name": TEST_NAME,
                    "max_runtime_s": 0,
                    "simulated_time_us": 0,
                    "passing_runs": 1 if passed else 0,
                    "total_runs": 1,
                    "pass_rate": 1.0 if passed else 0.0,
                    "seeds": [seed],
                }
            ],
        },
    }
    run_dir = out_dir / "run"
    run_dir.mkdir(parents=True, exist_ok=True)
    (run_dir / "report.json").write_text(json.dumps(report, indent=2) + "\n")


def step_run(sim: Path, binary: Path, tdir: Path, timeout_cycles: int,
             enable_waves: bool) -> int:
    """Run sim in tdir so waves/trace land next to test.bin (SMDB layout)."""
    rtl_log = tdir / "rtl_sim.log"
    std_log = tdir / "rtl_sim_stdstreams.log"
    cmd = [
        str(sim),
        "--bin={}".format(binary.name),
        "--timeout-cycles={}".format(timeout_cycles),
        "+ibex_tracer_file_base=trace_core",
    ]
    if enable_waves:
        cmd.append("--trace=waves.fst")

    print("+", " ".join(cmd), "(cwd={})".format(tdir), flush=True)
    with open(rtl_log, "w") as lf, open(std_log, "w") as sf:
        proc = subprocess.run(
            cmd, cwd=str(tdir),
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        lf.write(proc.stdout)
        sf.write(proc.stdout)

    # If tracer wrote to CWD with default name, ensure expected path exists
    default_trace = tdir / "trace_core_00000000.log"
    if not default_trace.exists():
        # Some builds may place it relative to process start; search nearby
        for cand in Path.cwd().glob("trace_core_*.log"):
            shutil.move(str(cand), str(default_trace))
            break

    print("Sim log:", rtl_log)
    try:
        for line in rtl_log.read_text().splitlines()[-40:]:
            print(line)
    except OSError:
        pass
    return proc.returncode


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT,
                        help="Top-level out dir (contains run/ like UVM core_ibex)")
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--iterations", type=int, default=1)
    parser.add_argument("--ibex-config", default="small",
                        help="Ibex config name from ibex_configs.yaml (default: small)")
    parser.add_argument("--timeout-cycles", type=int, default=100000000)
    parser.add_argument("--skip-gen", action="store_true")
    parser.add_argument("--skip-build", action="store_true")
    parser.add_argument("--stub", action="store_true",
                        help="Use sim_stub (no Spike cosim) for bring-up")
    parser.add_argument("--no-waves", action="store_true",
                        help="Skip FST dump (faster)")
    parser.add_argument("--bin", type=Path, default=None,
                        help="Use an existing test.bin (skips gen+compile)")
    args = parser.parse_args()

    out_dir = args.out.resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    tdir = test_dir(out_dir, args.seed)
    tdir.mkdir(parents=True, exist_ok=True)
    regr_log = out_dir / "run" / "regr.log"
    regr_log.parent.mkdir(parents=True, exist_ok=True)

    def log_regr(msg: str):
        with open(regr_log, "a") as f:
            f.write(msg + "\n")
        print(msg, flush=True)

    log_regr("=== {}.{} ===".format(TEST_NAME, args.seed))

    if args.bin:
        binary = args.bin.resolve()
        shutil.copy2(binary, tdir / "test.bin")
        binary = tdir / "test.bin"
    else:
        if not args.skip_gen:
            asm = step_gen(out_dir, tdir, args.seed, args.iterations)
        else:
            existing = list((out_dir / "gen").rglob("{}*.S".format(TEST_NAME)))
            if not existing and (tdir / "test.S").exists():
                asm = tdir / "test.S"
            elif existing:
                asm = tdir / "test.S"
                shutil.copy2(sorted(existing)[0], asm)
            else:
                raise FileNotFoundError("No .S found; omit --skip-gen")
        binary = step_compile(asm, tdir)

    sim_dir = "sim_stub-verilator" if args.stub else "sim-verilator"
    if not args.skip_build:
        sim = step_build_sim(args.ibex_config, stub=args.stub)
    else:
        build_root = REPO_ROOT / "build"
        matches = list(build_root.glob(
            "lowrisc_ibex_ibex_riscv_dv_tb_*/{}/Vibex_riscv_dv_tb".format(sim_dir)))
        if not matches:
            raise FileNotFoundError(
                "No {} sim found; omit --skip-build to build it".format(sim_dir))
        sim = sorted(matches)[-1]

    rc = step_run(sim, binary, tdir, args.timeout_cycles,
                  enable_waves=not args.no_waves)
    passed = rc == 0
    fail_msg = ""
    if not passed:
        try:
            fail_msg = (tdir / "rtl_sim.log").read_text()[-500:]
        except OSError:
            fail_msg = "sim exit {}".format(rc)
    write_trr_yaml(tdir, args.seed, passed, fail_msg)
    write_report(out_dir, args.seed, passed)

    status = "PASS" if passed else "FAIL (exit {})".format(rc)
    log_regr(status)
    log_regr("Artifacts: {}".format(tdir))
    print(status)
    return rc


if __name__ == "__main__":
    sys.exit(main())
