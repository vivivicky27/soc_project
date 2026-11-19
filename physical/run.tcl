# Invoke from an isolated build directory with BUTTERFLY_NETLIST set.
proc implement {} {
    global pdk_root constraints
    set script_dir [file dirname [file normalize [info script]]]
    set constraints [file join [file dirname $script_dir] synth constraints.sdc]
    set pdk_root /ip/tsmc/tsmc16adfp
    set collateral $pdk_root/source/DAFP0203001_2_X/Executable_Package/Collaterals
    set apr $collateral/Tech/APR/N16ADFP_APR_Innovus
    set cells $collateral/IP/stdcell/N16ADFP_StdCell

    set_multi_cpu_usage -local_cpu 1
    read_mmmc [file join $script_dir mmmc.tcl]
    read_physical -lef [list $apr/N16ADFP_APR_Innovus_11M.10a.tlef $cells/LEF/lef/N16ADFP_StdCell.lef]
    read_netlist $::env(BUTTERFLY_NETLIST)
    init_design
    create_floorplan -core_size {70 70 9 9 9 9} -core_margins_by die -match_to_site
    foreach {attribute value} {
        right_top_edge FILL4BWP20P90
        right_bottom_edge FILL4BWP20P90
        left_edge BOUNDARY_LEFTBWP20P90
        right_edge BOUNDARY_RIGHTBWP20P90
        left_top_corner BOUNDARY_PCORNERBWP20P90
        right_top_corner BOUNDARY_PCORNERBWP20P90
        left_bottom_corner BOUNDARY_NCORNERBWP20P90
        right_bottom_corner BOUNDARY_NCORNERBWP20P90
        top_edge BOUNDARY_PROW1BWP20P90
        bottom_edge BOUNDARY_NROW1BWP20P90
        boundary_tap true
    } {
        set_db add_endcaps_$attribute $value
    }
    set_db add_well_taps_rule 15
    set_db add_well_taps_top_tap_cell BOUNDARY_PTAPBWP20P90
    set_db add_well_taps_bottom_tap_cell BOUNDARY_NTAPBWP20P90
    add_endcaps -prefix ENDCAP
    add_well_taps -cell TAPCELLBWP20P90 -cell_interval 60 -checker_board -prefix WELLTAP

    set left {}
    set right {}
    foreach pin [lsort -dictionary [get_db ports .name]] {
        if {[regexp {^(u\[|v\[|out_valid$|in_ready$)} $pin]} {
            lappend right $pin
        } else {
            lappend left $pin
        }
    }
    edit_pin -pin $left -side Left -layer M3 -spread_type side -spread_direction clockwise -fix_overlap 1
    edit_pin -pin $right -side Right -layer M3 -spread_type side -spread_direction clockwise -fix_overlap 1
    legalize_pins
    check_pin_assignment -out_file pins.rpt

    foreach supply {VDD VSS} {
        if {![llength [get_db nets $supply]]} {
            create_net -name $supply [dict get {VDD -power VSS -ground} $supply]
        }
        connect_global_net $supply -type pg_pin -pin_base_name $supply -all
    }
    set core [get_db current_design .core_bbox]
    add_stripes -nets {VDD VSS} -layer M4 -direction horizontal -area $core -width 0.20 -spacing 0.50 -set_to_set_distance 18 -start_from bottom -start_offset 9
    add_stripes -nets {VDD VSS} -layer M5 -direction vertical -area $core -width 0.20 -spacing 0.50 -set_to_set_distance 18 -start_from left -start_offset 9
    route_special -connect corePin -nets {VDD VSS}

    place_design
    set_db cts_use_inverters true
    ccopt_design
    foreach supply {VDD VSS} {
        connect_global_net $supply -type pg_pin -pin_base_name $supply -all
    }
    set_db timing_analysis_type ocv
    set_db timing_analysis_cppr both
    route_design
    time_design -post_route -report_dir setup
    time_design -post_route -hold -report_dir hold
    check_drc -out_file drc.rpt
    check_connectivity -out_file connectivity.rpt
    report_area > area.rpt
    write_db routed
    write_def -floorplan -netlist -routing routed.def
    write_netlist routed.v
    write_netlist -include_pg_ports routed_pg.v
    streamOut routed.gds -mapFile $apr/N16ADFP_APR_Innovus_Gdsout_11M.10a.map -merge [list $pdk_root/stdcell/GDS/N16ADFP_StdCell.gds] -units 1000 -mode ALL
}

if {[catch {implement} message options]} {
    puts stderr [dict get $options -errorinfo]
    exit 1
}
exit 0
