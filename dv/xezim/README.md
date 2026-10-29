# xezim flows for Ibex DV benches

The benches run on xezim through the same entry points as upstream: fusesoc
with the edalize backend in `python/edalize/xezim.py`, dvsim with
`vendor/lowrisc_ip/dv/tools/dvsim/xezim.hjson`, and the `ci/` scripts.

## Environment

| Variable | Purpose |
|----------|---------|
| `PYTHONPATH` | Must include `dv/xezim/python` so fusesoc finds `--tool=xezim` (dvsim sets it) |
| `XEZIM` | xezim simulator binary |
| `XEZIM_UVM_DIR` | UVM library for the UVM benches |
| `XEZIM_INCLUDE` | Directory containing `svdpi.h`, for the cosim DPI build |
| `LD_LIBRARY_PATH` | xezim and Spike shared libraries as needed |
| `PKG_CONFIG_PATH` | Spike pkg-config files for the cosim DPI build |

Requires `fusesoc`, the RV32 toolchain, and Spike development packages.

## Benches

| Bench | Entry |
|-------|--------|
| `tb_cs_registers` | `fusesoc --cores-root=. run --target=sim --tool=xezim lowrisc:ibex:tb_cs_registers` |
| RISC-V compliance | `dv/riscv_compliance/scripts/run_compliance_config.sh <ibex_config> <riscv-compliance checkout>` |
| icache UVM | `dvsim dv/uvm/icache/dv/ibex_icache_sim_cfg.hjson -t xezim -i <test>` |
| Simple-system Spike cosim | `examples/simple_system/xezim/scripts/run_cosim.sh <ibex_config> [[--skip-pass-check] <test> <elf>]` |
| core_ibex UVM | `make -C dv/uvm/core_ibex SIMULATOR=xezim ...` |
