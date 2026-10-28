#!/usr/bin/env python3
"""Classify one simple-system cosim run (run-cosim-test.sh rules)."""

import re
import sys
from collections import Counter
from pathlib import Path

_, config, program, skip_pass, log_path, run_dir, exit_rc = sys.argv
skip_pass = skip_pass == "1"
log = Path(log_path).read_text(errors="replace") if Path(log_path).is_file() else ""
uart_file = Path(run_dir) / "ibex_simple_system.log"
uart = uart_file.read_text(errors="replace") if uart_file.is_file() else ""

asserts: Counter[str] = Counter()
first_assert = ""
for line in log.splitlines():
    if "Assertion failed" in line or "[ASSERT FAILED]" in line:
        m = re.search(r"(\w+)(?:\s|$)", line.split(":")[-1] if ":" in line else line)
        key = m.group(1) if m else line.strip()[:40]
        asserts[key] += 1
        if not first_assert:
            first_assert = line.strip()[:200]

cosim_match = ""
m = re.search(r"Co-simulation matched (\d+) instructions", log)
if m:
    cosim_match = m.group(1)

cosim_fail = "Co-simulation mismatch" in log or "FAILURE: Co-simulation mismatch" in log
uart_failure = "FAILURE" in uart
has_pass = "PASS" in uart

timed_out = "reached --max-time" in log
sim_rc = int(exit_rc)

if sim_rc != 0 or cosim_fail:
    result = "FAIL"
    first_err = first_assert or next(
        (ln.strip() for ln in log.splitlines() if "Co-simulation mismatch" in ln),
        f"exit={sim_rc}",
    )
elif uart_failure:
    result = "FAIL"
    first_err = next((ln for ln in uart.splitlines() if "FAILURE" in ln), "FAILURE in uart log")
elif not skip_pass and not has_pass:
    result = "FAIL"
    first_err = "no PASS in ibex_simple_system.log"
elif timed_out:
    result = "TIMEOUT"
    first_err = "reached --max-time"
else:
    result = "PASS"
    first_err = "-"

assert_classes = ",".join(sorted(asserts.keys())) if asserts else "-"
first_err = first_err.replace("\t", " ")[:200]
print(
    f"{config}\t{program}\t{result}\t{cosim_match or '-'}\t{first_err}\t{assert_classes}"
)
