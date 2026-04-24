# Targeted Timing evaluation for Alveo U50
set part_name "xcu50-fsvh2104-2-e"
create_project -force u50_conv2_timing ./u50_conv2_timing -part $part_name

# Add only required source files
add_files ../src/line_buffer.sv
add_files ../src/mac_3x3x32.sv
add_files ../src/conv2_layer.sv

# Add constraints (Assumes 100MHz clock)
add_files -fileset constrs_1 ./timing.xdc
set_property file_type SystemVerilog [get_files *.sv]

# Run Synthesis (Fast mode)
synth_design -top conv2_layer -part $part_name -directive RuntimeOptimized

# Run Implementation (U50 specialized)
opt_design
place_design
route_design

# Report results
report_timing_summary -file ../../docs/u50_timing_summary.txt
report_utilization -file ../../docs/u50_utilization_report.txt

exit
