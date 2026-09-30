set root [file normalize [file dirname [info script]]/..]
create_project FIR-filter-FPGA $root/build -part xc7a35tcpg236-1 -force
set_property target_language VHDL [current_project]
add_files [glob $root/src/*.vhd]
add_files -fileset sim_1 [glob $root/sim/*.vhd]
set_property file_type {VHDL 2008} [get_files *.vhd]