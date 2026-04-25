# Zynq-7020 Ultra-Lean Final Verification (v4.2)
set part_name "xc7z020clg400-1"
create_project -force zynq_7020_v4_2_final ./zynq_7020_v4_2_final -part $part_name

# Add source files (Removed non-existent MAC files)
add_files ../src/weight_rom.sv
add_files ../src/line_buffer.sv
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
report_timing_summary -file ../../docs/v4_2_final_timing.txt
report_utilization -file ../../docs/v4_2_final_utilization.txt

puts "V4.2 FINAL COMPLETE."
exit
