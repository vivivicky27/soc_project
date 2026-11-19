create_library_set -name LIB_TT -timing [list $pdk_root/stdcell/NLDM/N16ADFP_StdCelltt0p8v25c.lib]
create_timing_condition -name TC_TT -library_sets {LIB_TT}
create_rc_corner -name RC_TT -temperature 25 -qrc_tech $pdk_root/source/DAFP0203001_2_X/Executable_Package/Collaterals/Tech/RC/N16ADFP_QRC/worst/qrcTechFile
create_delay_corner -name DC_TT -timing_condition TC_TT -rc_corner RC_TT
create_constraint_mode -name FUNC -sdc_files [list $constraints]
create_analysis_view -name TT -constraint_mode FUNC -delay_corner DC_TT
set_analysis_view -setup {TT} -hold {TT}
