# SPDX-License-Identifier: Apache-2.0
"""Edalize backend for the xezim simulator (legacy tool API).

edalize is a namespace package, so putting the directory above this one on
PYTHONPATH makes `fusesoc run --tool=xezim` find this backend without
installing anything.

configure writes <name>.f (options, defines, parameters, include dirs and HDL
files, all with absolute paths; the top modules are left to the caller) and a
Makefile. build elaborates the design into the compiled artifact <name>.xezim;
run simulates the artifact. C and C++ sources are not compiled here: DPI
libraries come from the core's hooks and are passed with the dpi_libs option.
"""

import logging
import os

from edalize.edatool import Edatool

logger = logging.getLogger(__name__)

MAKEFILE = """\
XEZIM ?= xezim

all:
\t$(XEZIM) --compile --compat -o {name}.xezim {tops} -f {name}.f

run:
\t$(XEZIM) {name}.xezim --compat {dpi_libs} {run_options} $(EXTRA_OPTIONS)
"""


class Xezim(Edatool):
    _description = "xezim SystemVerilog simulator"
    argtypes = ["plusarg", "vlogdefine", "vlogparam"]
    tool_options = {
        "lists": {
            "xezim_options": "String",
            "run_options": "String",
            "dpi_libs": "String",
        }
    }

    def configure_main(self):
        (src_files, incdirs) = self._get_fileset_files()
        work_root = os.path.abspath(self.work_root)
        tops = self.toplevel.split()

        lines = list(self.tool_options.get("xezim_options", []))
        for key, value in self.vlogdefine.items():
            lines.append("+define+{}={}".format(key, self._param_value_str(value)))
        for key, value in self.vlogparam.items():
            for top in tops:
                lines.append(
                    "-g/{}/{}={}".format(top, key, self._param_value_str(value, '"'))
                )
        lines += ["+incdir+" + os.path.join(work_root, d) for d in incdirs]
        for f in src_files:
            if f.file_type.startswith(("systemVerilogSource", "verilogSource")):
                lines.append(os.path.join(work_root, f.name))
            elif f.file_type not in ("user", "cSource", "cppSource", "vlt"):
                logger.warning("%s has unknown file type '%s'", f.name, f.file_type)

        with open(os.path.join(work_root, self.name + ".f"), "w") as out:
            out.write("\n".join(lines) + "\n")

        dpi_libs = " ".join(
            "--dpi-lib " + lib for lib in self.tool_options.get("dpi_libs", [])
        )
        with open(os.path.join(work_root, "Makefile"), "w") as out:
            out.write(
                MAKEFILE.format(
                    name=self.name,
                    tops=" ".join("-s " + top for top in tops),
                    dpi_libs=dpi_libs,
                    run_options=" ".join(self.tool_options.get("run_options", [])),
                )
            )

    def run_main(self):
        args = ["run"]
        if self.plusarg:
            plusargs = [
                "+{}={}".format(key, self._param_value_str(value))
                for key, value in self.plusarg.items()
            ]
            args.append("EXTRA_OPTIONS=" + " ".join(plusargs))
        self._run_tool("make", args)
