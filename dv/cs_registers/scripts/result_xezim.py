#!/usr/bin/env python3
"""Parse tb_cs_registers log for PASS/FAIL."""
import sys
from pathlib import Path

log = Path(sys.argv[1]).read_text(errors="replace")
if "// TEST PASSED //" in log:
    print("PASS\t")
    sys.exit(0)
if "// TEST FAILED //" in log:
    for ln in log.splitlines():
        if "error" in ln.lower() or "fail" in ln.lower():
            print(f"FAIL\t{ln[:200]}")
            sys.exit(0)
    print("FAIL\t// TEST FAILED //")
    sys.exit(0)
for pat in ("ERROR", "Error", "$fatal", "Assertion"):
    for ln in log.splitlines():
        if pat in ln:
            print(f"FAIL\t{ln[:200]}")
            sys.exit(0)
print("FAIL\tno TEST PASSED marker in log")
sys.exit(0)
