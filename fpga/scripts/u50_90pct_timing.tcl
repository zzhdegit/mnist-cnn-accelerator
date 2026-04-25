# Final Full System Timing evaluation for Alveo U50 (90% Accuracy Ultra-Stable)
set part_name "xcu50-fsvh2104-2-e"
create_project -force u50_90pct_final ./u50_90pct_final -part $part_name

# Add all source files
add_files ../src/line_buffer.sv
add_files ../src/mac_3x3.sv
add_files ../src/mac_3x3x32.sv
add_files ../src/conv1_layer.sv
add_files ../src/conv2_layer.sv
add_files ../src/maxpool_layer.sv
add_files ../src/avgpool_3x3_s3.sv
add_files ../src/fc1_layer.sv
add_files ../src/fc2_layer.sv
add_files ../src/top_mnist.sv

# Add constraints
add_files -fileset constrs_1 ./timing.xdc
set_property file_type SystemVerilog [get_files *.sv]

# Optimize for 9700X
set_param general.maxThreads 16

# Run Full Implementation
synth_design -top top_mnist -part $part_name -directive RuntimeOptimized
opt_design
place_design
route_design

# Report results
report_timing_summary -file ../../docs/v2_2_timing_summary.txt
report_utilization -file ../../docs/v2_2_utilization_report.txt

exit
