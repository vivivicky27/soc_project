# Run from build/pg_e0_probe. Keep the original routed database unchanged.
set_multi_cpu_usage -local_cpu 1
read_db ../physical_e0/routed
delete_routes -nets {VDD VSS} -type regular
delete_routes -nets {VDD VSS} -type special
set core [get_db current_design .core_bbox]
add_stripes -nets {VDD VSS} -layer M4 -direction horizontal -area $core -width 0.20 -spacing 0.50 -set_to_set_distance 18 -start_from bottom -start_offset 9 -snap_wire_center_to_grid grid
add_stripes -nets {VDD VSS} -layer M5 -direction vertical -area $core -width 0.24 -spacing 0.60 -set_to_set_distance 18 -start_from left -start_offset 9 -snap_wire_center_to_grid grid
route_special -connect core_pin -nets {VDD VSS} -core_pin_target stripe -layer_change_range {M1 M5} -crossover_via_layer_range {M1 M5} -target_via_layer_range {M1 M5} -allow_layer_change 1 -allow_jogging 0
check_drc -out_file drc.rpt
check_connectivity -out_file connectivity.rpt
write_def -floorplan -netlist -routing candidate.def
exit
