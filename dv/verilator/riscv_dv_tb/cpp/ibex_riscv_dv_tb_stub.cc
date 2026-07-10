// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Bring-up harness with stub cosim (no Spike link required).

#include <svdpi.h>

#include <cstdint>
#include <cstdio>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

#include "verilated_toplevel.h"
#include "verilator_sim_ctrl.h"

extern "C" {
void riscv_dv_mem_write_byte(unsigned int addr, unsigned char data);
void riscv_dv_mem_clear();
}

static int stub_insn_cnt = 0;
static constexpr uint32_t kBootAddr = 0x80000000u;

class IbexRiscvDvTbStub {
 public:
  int Main(int argc, char **argv) {
    bool exit_app = false;
    int ret = Setup(argc, argv, exit_app);
    if (exit_app) {
      return ret;
    }
    std::cout << "Simulation of Ibex (riscv-dv TB, STUB cosim)\n";
    VerilatorSimCtrl::GetInstance().RunSimulation();
    return VerilatorSimCtrl::GetInstance().WasSimulationSuccessful() ? 0 : 1;
  }

 private:
  ibex_riscv_dv_tb top_;
  std::string bin_path_;

  bool LoadBinary(const std::string &path) {
    std::ifstream ifs(path, std::ios::binary);
    if (!ifs) {
      std::cerr << "Failed to open binary: " << path << std::endl;
      return false;
    }
    std::vector<uint8_t> bytes((std::istreambuf_iterator<char>(ifs)),
                               std::istreambuf_iterator<char>());
    svScope scope = svGetScopeFromName("TOP.ibex_riscv_dv_tb.u_mem");
    if (!scope) {
      std::cerr << "Failed to find SV scope TOP.ibex_riscv_dv_tb.u_mem\n";
      return false;
    }
    svSetScope(scope);
    riscv_dv_mem_clear();
    for (size_t i = 0; i < bytes.size(); ++i) {
      riscv_dv_mem_write_byte(kBootAddr + static_cast<uint32_t>(i), bytes[i]);
    }
    std::cout << "Loaded " << bytes.size()
              << " bytes at 0x80000000 (stub cosim)\n";
    return true;
  }

  int Setup(int argc, char **argv, bool &exit_app) {
    VerilatorSimCtrl &simctrl = VerilatorSimCtrl::GetInstance();
    simctrl.SetTop(&top_, &top_.IO_CLK, &top_.IO_RST_N,
                   VerilatorSimCtrlFlags::ResetPolarityNegative);
    for (int i = 1; i < argc; ++i) {
      std::string arg(argv[i]);
      if (arg.rfind("--bin=", 0) == 0) {
        bin_path_ = arg.substr(6);
      } else if (arg.rfind("+bin=", 0) == 0) {
        bin_path_ = arg.substr(5);
      }
    }
    exit_app = false;
    int ret = simctrl.ParseCommandArgs(argc, argv, exit_app);
    if (exit_app) {
      return ret;
    }
    if (bin_path_.empty() || !LoadBinary(bin_path_)) {
      std::cerr << "ERROR: provide --bin=<path>\n";
      exit_app = true;
      return 1;
    }
    return 0;
  }
};

extern "C" {
void *get_spike_cosim() {
  static int handle = 1;
  return &handle;
}

void create_cosim(svBit, svBit, const svBitVecVal *, const svBitVecVal *,
                  const svBitVecVal *, const svBitVecVal *,
                  const svBitVecVal *) {
  std::printf("NOTE: using stub cosim (Spike not linked)\n");
}

int riscv_cosim_step(void *, const svBitVecVal *, const svBitVecVal *,
                     const svBitVecVal *, svBit, svBit) {
  stub_insn_cnt++;
  return 1;
}

void riscv_cosim_set_mip(void *, const svBitVecVal *, const svBitVecVal *) {}
void riscv_cosim_set_nmi(void *, svBit) {}
void riscv_cosim_set_nmi_int(void *, svBit) {}
void riscv_cosim_set_debug_req(void *, svBit) {}
void riscv_cosim_set_mcycle(void *, svBitVecVal *) {}
void riscv_cosim_set_csr(void *, int, const svBitVecVal *) {}
void riscv_cosim_set_ic_scr_key_valid(void *, svBit) {}
void riscv_cosim_notify_dside_access(void *, svBit, svBitVecVal *,
                                     svBitVecVal *, svBitVecVal *, svBit, svBit,
                                     svBit, svBit, svBit) {}
void riscv_cosim_set_iside_error(void *, svBitVecVal *) {}
int riscv_cosim_get_num_errors(void *) { return 0; }
const char *riscv_cosim_get_error(void *, int) { return ""; }
void riscv_cosim_clear_errors(void *) {}
void riscv_cosim_write_mem_byte(void *, const svBitVecVal *,
                                const svBitVecVal *) {}
unsigned int riscv_cosim_get_insn_cnt(void *) {
  return static_cast<unsigned int>(stub_insn_cnt);
}
}

int main(int argc, char **argv) {
  IbexRiscvDvTbStub tb;
  return tb.Main(argc, argv);
}
