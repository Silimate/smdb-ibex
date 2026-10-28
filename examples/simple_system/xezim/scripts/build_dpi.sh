#!/usr/bin/env bash
set -euo pipefail

ibex_root="${IBEX_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)}"
out="$ibex_root/build/xezim/simple_system_cosim/simple_system_cosim_dpi.so"

: "${XEZIM_INCLUDE:?set XEZIM_INCLUDE}"

if ! pkg-config --exists riscv-riscv 2>/dev/null; then
  echo "pkg-config riscv-riscv not found (set PKG_CONFIG_PATH for Spike)" >&2
  exit 2
fi

CFLAGS=$(pkg-config --cflags riscv-riscv riscv-disasm riscv-fdt riscv-fesvr)
LIBS=$(pkg-config --libs riscv-riscv riscv-disasm riscv-fdt riscv-fesvr)

mkdir -p "$(dirname "$out")"
# The linker rewrites its output in place, which corrupts the library under any
# simulation that has it loaded; link to a temporary name and rename it.
tmp="$out.$$.tmp"
g++ -shared -fPIC -O2 -std=c++17 \
  -I"$XEZIM_INCLUDE" -I"$ibex_root/dv/cosim" \
  $CFLAGS \
  -o "$tmp" \
  "$ibex_root/dv/cosim/cosim_dpi.cc" \
  "$ibex_root/dv/cosim/spike_cosim.cc" \
  "$ibex_root/examples/simple_system/xezim/simple_system_cosim_dpi.cc" \
  -Wl,--no-as-needed $LIBS -lstdc++ -Wl,--as-needed
mv -f "$tmp" "$out"

echo "Wrote $out"
