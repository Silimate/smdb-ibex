#!/usr/bin/env bash
set -euo pipefail

ibex_root="${IBEX_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
csreg="$ibex_root/dv/cs_registers"
out="$ibex_root/build/xezim/cs_registers/reg_dpi.so"

: "${XEZIM_INCLUDE:?set XEZIM_INCLUDE to the directory containing svdpi.h}"

inc="-I$csreg/env -I$csreg/rst_driver -I$csreg/reg_driver -I$csreg/model -I$XEZIM_INCLUDE"
cxx="${CXX:-g++}"
cflags="-std=c++17 -m64 -fPIC -Wall -pedantic -g $inc"

mkdir -p "$(dirname "$out")/obj"
mapfile -t srcs < <(find "$csreg" -name '*.cc' ! -path '*/tb/*' ! -path '*/build/*' | sort)
objs=()
for s in "${srcs[@]}"; do
  rel="${s#"$csreg"/}"
  o="$(dirname "$out")/obj/$rel.o"
  mkdir -p "$(dirname "$o")"
  "$cxx" $cflags -c "$s" -o "$o"
  objs+=("$o")
done
"$cxx" "${objs[@]}" -shared -o "$out"
echo "Wrote $out"
