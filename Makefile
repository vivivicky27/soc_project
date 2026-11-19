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

.PHONY: sim-hy3281 sim-e0-hy3281 sim-e1-hy3281 sim-e2-hy3281
sim-hy3281: sim-e0-hy3281 sim-e1-hy3281 sim-e2-hy3281

sim-e0-hy3281 sim-e1-hy3281 sim-e2-hy3281: sim-%-hy3281:
	mkdir -p build/$*_hy3281
	cd build/$*_hy3281 && vcs -full64 -sverilog -top tb_butterfly_$*_hy3281 ../../rtl/butterfly_$*_hy3281.sv ../../tb/tb_butterfly_$*_hy3281.sv -o simv -l compile.log
	cd build/$*_hy3281 && ./simv -l simulation.log

.PHONY: cosim-e1-hy3281 cosim-e2-hy3281 synth-hy3281
cosim-e1-hy3281 cosim-e2-hy3281: cosim-%-hy3281:
	mkdir -p build/cosim_$*
	cd build/cosim_$* && vcs -full64 -sverilog +define+BUTTERFLY_DUT=butterfly_$*_hy3281 -top butterfly_cosim_tb ../../rtl/butterfly_$*_hy3281.sv ../../tb/butterfly_cosim_tb.sv -o simv -l compile.log
	timeout 120s $(PYTHON) software/rtl_cosim.py build/cosim_$*/simv

synth-hy3281:
	for variant in e0 e1 e2; do \
	    mkdir -p build/synth_$$variant && \
	    (cd build/synth_$$variant && BUTTERFLY_TOP=butterfly_$${variant}_hy3281 $(DC_SHELL) -f ../../synth/run.tcl -output_log_file synthesis.log) && \
	    test -s build/synth_$$variant/netlist/butterfly_$${variant}_hy3281_mapped.v || exit 1; \
	done

.PHONY: route-e0-hy3281 route-e1-hy3281 route-e2-hy3281
route-e0-hy3281 route-e1-hy3281 route-e2-hy3281: route-%-hy3281:
	test -s build/synth_$*/netlist/butterfly_$*_hy3281_mapped.v
	mkdir -p build/physical_$*
	cd build/physical_$* && BUTTERFLY_NETLIST=../synth_$*/netlist/butterfly_$*_hy3281_mapped.v innovus -stylus -no_gui -files ../../physical/run.tcl -log innovus
	test -s build/physical_$*/routed.gds
