# xezim flows for Ibex DV benches

Shared helpers for running Ibex testbenches with xezim instead of the Verilator C++ `main()`.

## Environment

| Variable | Purpose |
|----------|---------|
| `IBEX_ROOT` | Ibex repository root (defaults from script location) |
| `XEZIM` | xezim simulator binary (`XEZIM_BIN` is accepted as an alias) |
| `XEZIM_INCLUDE` | Directory containing `svdpi.h` |
| `LD_LIBRARY_PATH` | xezim and Spike shared libraries as needed |
| `PKG_CONFIG_PATH` | Spike pkg-config files for cosim DPI build |
| `XEZIM_SLOT` | Optional wrapper invoked before the simulator command |
| `RISCV_COMPLIANCE_DIR` | Checkout of the riscv-compliance suite |
| `SSCOSIM_VMEM` | Path to a `.vmem` for cosim (hello can use the in-tree hello_test build) |
| `PRJ_DIR` / `LOWRISC_IP_DIR` | Expanded in generated `-f` files when needed |

Requires `fusesoc`, the RV32 toolchain, and Spike development packages on `PATH` / `PKG_CONFIG_PATH`.

Generated argument files use `${IBEX_ROOT}/...` paths only.

## Benches

| Bench | Entry |
|-------|--------|
| `tb_cs_registers` | `dv/cs_registers/scripts/run_xezim.sh` |
| RISC-V compliance | `dv/riscv_compliance/scripts/run_compliance_all.sh` |
| Simple-system Spike cosim | `examples/simple_system/xezim/scripts/run_all.sh` |
