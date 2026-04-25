# Alveo U50 Ultra-Fast Verification (v2.3)
set part_name "xcu50-fsvh2104-2-e"
create_project -force u50_v2_3_ultrafast ./u50_v2_3_ultrafast -part $part_name

# Add source files
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

# Configure project
add_files -fileset constrs_1 ./timing.xdc
set_property file_type SystemVerilog [get_files *.sv]
set_param general.maxThreads 16

# Run Full Implementation (Synthesis + Route)
synth_design -top top_mnist -part $part_name -directive RuntimeOptimized
opt_design
place_design
route_design

# Export Summary
report_timing_summary -file ../../docs/v2_3_timing_summary.txt
report_utilization -file ../../docs/v2_3_utilization_report.txt

puts "V2.3 Ultra-Fast implementation complete."
exit
