// SPDX-License-Identifier: Apache-2.0
// xezim DPI glue for ibex_simple_system_cosim (no Verilator main).

#include <svdpi.h>

#include <cassert>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <iostream>
#include <memory>
#include <sstream>
#include <string>
#include <vector>

#include "cosim.h"
#include "spike_cosim.h"

namespace {

constexpr uint32_t kRAM_BaseAddr = 0x100000;
constexpr size_t kRAM_SizeBytes = 1024 * 1024;

std::unique_ptr<SpikeCosim> g_cosim;
bool g_match_printed = false;

void print_match_count() {
  if (g_match_printed || !g_cosim) {
    return;
  }
  g_match_printed = true;
  std::cout << "Co-simulation matched " << g_cosim->get_insn_cnt()
            << " instructions\n";
}

void atexit_print_match() { print_match_count(); }

bool parse_hex_byte(const std::string &s, uint8_t *out) {
  if (s.size() != 2) {
    return false;
  }
  char *end = nullptr;
  unsigned long v = std::strtoul(s.c_str(), &end, 16);
  if (end != s.c_str() + 2) {
    return false;
  }
  *out = static_cast<uint8_t>(v);
  return true;
}

bool load_vmem_to_buffer(const std::string &path, std::vector<uint8_t> &ram) {
  std::ifstream in(path);
  if (!in) {
    std::cerr << "sscosim: cannot open vmem " << path << "\n";
    return false;
  }
  ram.assign(kRAM_SizeBytes, 0);

  std::string line;
  while (std::getline(in, line)) {
    if (line.empty() || line[0] == '/' || line[0] == '#') {
      continue;
    }
    if (line[0] != '@') {
      continue;
    }
    size_t pos = 1;
    size_t at_end = line.find_first_not_of("0123456789abcdefABCDEF", pos);
    if (at_end == std::string::npos) {
      at_end = line.size();
    }
    char *end = nullptr;
    unsigned long word_addr =
        std::strtoul(line.substr(pos, at_end - pos).c_str(), &end, 16);
    pos = at_end;
    while (pos < line.size()) {
      while (pos < line.size() && (line[pos] == ' ' || line[pos] == '\t')) {
        pos++;
      }
      if (pos + 8 > line.size()) {
        break;
      }
      std::string word_hex = line.substr(pos, 8);
      pos += 8;
      for (int b = 0; b < 4; b++) {
        uint8_t byte;
        if (!parse_hex_byte(word_hex.substr(6 - 2 * b, 2), &byte)) {
          return false;
        }
        size_t off = word_addr * 4 + static_cast<size_t>(b);
        if (off < ram.size()) {
          ram[off] = byte;
        }
      }
      word_addr++;
    }
  }
  return true;
}

std::string isa_from_env() {
  const char *isa = std::getenv("SSCOSIM_ISA");
  if (!isa || !isa[0]) {
    std::cerr << "sscosim: SSCOSIM_ISA not set\n";
    return "rv32imc";
  }
  return isa;
}

std::string vmem_from_env() {
  const char *vmem = std::getenv("SSCOSIM_VMEM");
  if (!vmem || !vmem[0]) {
    std::cerr << "sscosim: SSCOSIM_VMEM not set\n";
    return {};
  }
  return vmem;
}

}  // namespace

extern "C" {

void *get_spike_cosim() {
  assert(g_cosim);
  return static_cast<Cosim *>(g_cosim.get());
}

void create_cosim(svBit secure_ibex, svBit icache_en,
                  const svBitVecVal *pmp_num_regions,
                  const svBitVecVal *pmp_granularity,
                  const svBitVecVal *mhpm_counter_num,
                  const svBitVecVal *DmStartAddr,
                  const svBitVecVal *DmEndAddr) {
  std::string isa = isa_from_env();
  g_cosim = std::make_unique<SpikeCosim>(
      isa, 0x100080, 0x100001, "simple_system_cosim.log", secure_ibex,
      icache_en, pmp_num_regions[0], pmp_granularity[0], mhpm_counter_num[0],
      DmStartAddr[0], DmEndAddr[0]);

  g_cosim->add_memory(0x00000000, 0xFFFF0000);

  std::string vmem_path = vmem_from_env();
  if (!vmem_path.empty()) {
    std::vector<uint8_t> ram;
    if (load_vmem_to_buffer(vmem_path, ram)) {
      g_cosim->backdoor_write_mem(kRAM_BaseAddr, ram.size(), ram.data());
    }
  }

  std::atexit(atexit_print_match);
}

}  // extern "C"
