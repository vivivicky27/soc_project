# Time unit: ns, as reported by the course TSMC library.
create_clock -name clk -period 10.0 [get_ports clk]
set_clock_uncertainty 0.1 [get_clocks clk]
set_clock_transition 0.1 [get_clocks clk]

# Initial interface budget, not measured board/interface delays.
set data_inputs [remove_from_collection [all_inputs] [get_ports {clk rst_n}]]
set_input_delay -max 2.0 -clock clk $data_inputs
set_input_delay -min 0.5 -clock clk $data_inputs
set_input_transition 0.1 $data_inputs
set_output_delay -max 2.0 -clock clk [all_outputs]
set_output_delay -min 0.5 -clock clk [all_outputs]
# Small placeholder load in library capacitance units; see units.rpt.
set_load 0.005 [all_outputs]

# Reset assertion is asynchronous. Reset release must be synchronized by the
# surrounding system; recovery/removal signoff is outside this baseline run.
set_false_path -from [get_ports rst_n]
