# Run from project/build/synth via make synth. Logical synthesis only.
set script_dir [file dirname [file normalize [info script]]]
set project_dir [file dirname $script_dir]
set lib_file /ip/tsmc/tsmc16adfp/stdcell/CCS/N16ADFP_StdCelltt0p8v25c_ccs.db
if {[info exists env(BUTTERFLY_TARGET_DB)]} {
    set lib_file $env(BUTTERFLY_TARGET_DB)
}
if {![file readable $lib_file]} {
    puts stderr "ERROR: Cannot read target library $lib_file"
    exit 1
}
file mkdir work reports netlist alib
set_app_var alib_library_analysis_path [file normalize alib]
set_app_var target_library [list $lib_file]
set_app_var link_library [concat * $target_library]
define_design_lib WORK -path ./work

set top ntt_butterfly
if {[info exists env(BUTTERFLY_TOP)]} {
    set top $env(BUTTERFLY_TOP)
}
if {![analyze -format sverilog $project_dir/rtl/${top}.sv]} {exit 1}
if {[elaborate $top] == ""} {exit 1}
current_design $top
if {![link]} {exit 1}
redirect reports/units.rpt {report_units}
redirect reports/library.rpt {report_lib [get_object_name [get_libs *]]}
source $script_dir/constraints.sdc
redirect reports/check_design_before.rpt {check_design}
if {![compile]} {exit 1}
# Flatten arithmetic helper modules, removing unused quotient/helper ports.
ungroup -all -flatten
# Repair short register-feedback paths while keeping the same constraints.
redirect reports/qor_before_hold_fix.rpt {report_qor}
set_fix_hold [get_clocks clk]
if {![compile -incremental_mapping -only_hold_time]} {exit 1}
change_names -rules verilog -hierarchy

redirect reports/check_design.rpt {check_design}
redirect reports/check_timing.rpt {check_timing}
redirect reports/area.rpt {report_area -hierarchy}
redirect reports/cells.rpt {report_cell}
redirect reports/resources.rpt {report_resources}
redirect reports/timing_setup.rpt {report_timing -delay_type max -max_paths 10 -input_pins -nets}
redirect reports/timing_hold.rpt {report_timing -delay_type min -max_paths 10 -input_pins -nets}
redirect reports/constraints.rpt {report_constraint -all_violators}
redirect reports/qor.rpt {report_qor}
redirect reports/clocks.rpt {report_clock}
write -format verilog -hierarchy -output netlist/${top}_mapped.v
write -format ddc -hierarchy -output netlist/${top}.ddc
write_sdc netlist/${top}.sdc
puts "SYNTHESIS_FINISHED: inspect reports for timing/design violations."
exit 0
