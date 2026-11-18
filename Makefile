PYTHON ?= python3
DC_SHELL ?= dc_shell
CELL_VERILOG ?= /ip/tsmc/tsmc16adfp/stdcell/VERILOG/N16ADFP_StdCell.v

.PHONY: sim clean model-test vectors sim-golden synth sim-gate demo test software-demo software-test software-check
demo software-demo:
	$(MAKE) -C software demo PYTHON="$(PYTHON)"

test software-test:
	$(MAKE) -C software test PYTHON="$(PYTHON)"

software-check: model-test software-test software-demo

sim-gate: vectors
	test -s build/synth/netlist/ntt_butterfly_mapped.v
	cd build && vcs -full64 -sverilog -timescale=1ns/1ps +notimingcheck -top ntt_butterfly_vectors_tb synth/netlist/ntt_butterfly_mapped.v ../tb/ntt_butterfly_vectors_tb.sv $(CELL_VERILOG) -o simv_gate -l compile_gate.log
	cd build && ./simv_gate +VECTORS=butterfly_vectors.txt -l simulation_gate.log

synth:
	mkdir -p build/synth
	cd build/synth && $(DC_SHELL) -f ../../synth/run.tcl -output_log_file synthesis.log
	test -s build/synth/netlist/ntt_butterfly_mapped.v

model-test:
	$(PYTHON) -m unittest discover -s model -p 'test_*.py' -v

vectors:
	$(PYTHON) model/golden_model.py vectors build/butterfly_vectors.txt

sim-golden: vectors
	cd build && vcs -full64 -sverilog -top ntt_butterfly_vectors_tb ../rtl/ntt_butterfly.sv ../tb/ntt_butterfly_vectors_tb.sv -o simv_golden -l compile_golden.log
	cd build && ./simv_golden +VECTORS=butterfly_vectors.txt -l simulation_golden.log

sim:
	mkdir -p build
	cd build && vcs -full64 -sverilog -top ntt_butterfly_tb ../rtl/ntt_butterfly.sv ../tb/ntt_butterfly_tb.sv -o simv -l compile.log
	cd build && ./simv -l simulation.log

clean:
	rm -rf build
