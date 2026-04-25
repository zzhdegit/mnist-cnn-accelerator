# Zynq-7020 Absolute Survival Verification (v4.0 - ROM Based)
set part_name "xc7z020clg400-1"
create_project -force zynq_7020_v4_success ./zynq_7020_v4_success -part $part_name

# Add source files
add_files ../src/weight_rom.sv
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
set_property file_type SystemVerilog [get_files *.sv]
add_files -fileset constrs_1 ./timing.xdc
set_param general.maxThreads 16

# Run Full Implementation
synth_design -top top_mnist -part $part_name -directive RuntimeOptimized
opt_design
place_design
route_design

# Export Summary
report_timing_summary -file ../../docs/zynq_success_timing.txt
report_utilization -file ../../docs/zynq_success_utilization.txt

puts "ZYNQ SUCCESS REPORT GENERATED."
exit
