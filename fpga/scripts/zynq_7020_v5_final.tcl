# Zynq-7020 Total Stream Verification (v5.0)
set part_name "xc7z020clg400-1"
create_project -force zynq_7020_v5_success ./zynq_7020_v5_success -part $part_name

# Add all optimized v5.0 serial source files
add_files ../src/weight_rom.sv
add_files ../src/line_buffer.sv
add_files ../src/conv1_layer_v5.sv
add_files ../src/conv2_layer_v5.sv
add_files ../src/backend_v5.sv
add_files ../src/fc1_layer.sv
add_files ../src/fc2_layer.sv
add_files ../src/top_mnist.sv

# Configure project
set_property file_type SystemVerilog [get_files *.sv]
add_files -fileset constrs_1 ./timing.xdc
set_param general.maxThreads 16
set_param drc.disableLUTOverUtilError 1

# Run Full Implementation
synth_design -top top_mnist -part $part_name -directive RuntimeOptimized
opt_design
place_design
route_design

# Export Summary
report_timing_summary -file ../../docs/v5_success_timing.txt
report_utilization -file ../../docs/v5_success_utilization.txt

puts "V5 TOTAL STREAM COMPLETE."
exit
