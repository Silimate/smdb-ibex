# Non-UVM Verilator riscv-dv testbench

This directory provides a Verilator + Spike cosim harness that reimplements the
runtime contract of UVM `core_ibex_base_test` for random-instruction tests —
without a commercial simulator.

## Memory map (UVM-compatible)

| Region | Address |
|--------|---------|
| Boot / binary base | `0x80000000` |
| Reset PC | `0x80000080` |
| Signature | `0x8ffffffc` |
| Test done (pass/fail) | `0x8ffffff8` |
| Debug module | `0x1A110000`–`0x1A110FFF` |

## Dependencies

### Python

```bash
cd dv/verilator/riscv_dv_tb
# macOS: use Python 3.12 — PyBoolector only ships a macOS wheel for cp312
python3.12 -m venv .venv && source .venv/bin/activate
pip install -U pip setuptools wheel
pip install --only-binary=PyBoolector -e .
# or: uv sync
```

See [`pyproject.toml`](pyproject.toml) for the full list (FuseSoC, edalize, pyvsc/PyBoolector, etc.). Requires Python ≥ 3.10 (3.12 recommended on macOS).

### Other tools

1. **Verilator** (≥ 4.210 recommended)
2. **RISC-V GCC** (`riscv32-unknown-elf-gcc` or `riscv64-unknown-elf-gcc`) — full flow only
3. **Spike** built from the lowRISC `ibex_cosim` branch with
   `--enable-commitlog --enable-misaligned`, and `PKG_CONFIG_PATH` set so
   `pkg-config --libs riscv-riscv` works (see
   [`../simple_system_cosim/README.md`](../simple_system_cosim/README.md)) — full cosim only

## Quick start

### Bring-up smoke (no Spike / GCC / pyvsc)

Validates the TB, sparse memory load, and signature handshake with a stub cosim:

```bash
./dv/verilator/riscv_dv_tb/smoke/run_smoke.sh
```

### Full flow (Spike cosim + pyflow)

```bash
# Spike cosim (once) — see ../simple_system_cosim/README.md
export PKG_CONFIG_PATH=/opt/spike-cosim/lib/pkgconfig:$PKG_CONFIG_PATH

cd <ibex_repo>/dv/verilator/riscv_dv_tb
python3 -m venv .venv && source .venv/bin/activate
pip install -e .

python3 scripts/run_test.py --ibex-config small --seed 1 --iterations 1
```

Requires: Verilator, RISC-V GCC, Spike `ibex_cosim`, and the Python deps from `pyproject.toml`.

### Opentitan-like config (Phase 2)

```bash
python3 dv/verilator/riscv_dv_tb/scripts/run_test.py --ibex-config opentitan --seed 1
```

Enables SecureIbex SECDED responses and the scramble-key responder.

### Stimulus plusargs (Phase 3)

Pass through Verilator after `--` is not wired yet; set in the TB via plusargs
when launching the sim binary directly:

```
+enable_irq_stimulus=1
+enable_debug_stimulus=1
+enable_mem_err_stimulus=1
```

## Output layout (SMDB / UVM-compatible)

Artifacts land under `<out>/run/tests/riscv_rand_instr_test.<seed>/`, matching
[`smdb/tests/data/bugs/ibex/*/run/`](https://github.com/silimate/smdb) fixtures:

```
out/run/tests/riscv_rand_instr_test.1/
  test.S  test.o  test.bin
  gen.log  compile*.log
  rtl_sim.log  rtl_sim_stdstreams.log
  waves.fst  trace_core_00000000.log
  trr.yaml
out/run/report.json
out/run/regr.log
```

Point SMDB at those paths, e.g.:

```toml
waveform_file = "{CONFIG_DIR}/run/tests/riscv_rand_instr_test.1/waves.fst"
tb_log_file = "{CONFIG_DIR}/run/tests/riscv_rand_instr_test.1/rtl_sim.log"
tb_misc_outputs = [
  "{CONFIG_DIR}/run/tests/riscv_rand_instr_test.1/trace_core_00000000.log"
]
```

Bring-up (stub cosim, no Spike):

```bash
python3 scripts/run_test.py --ibex-config small --seed 1 --stub
```
