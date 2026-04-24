# Create project with a common part (Zynq-7020) since U50 might not be installed
set part_name "xc7z020clg400-1"
create_project -force mnist_timing ./mnist_timing -part $part_name

# Add all source files
add_files ../src/line_buffer.sv
add_files ../src/mac_3x3.sv
add_files ../src/mac_3x3x32.sv
add_files ../src/conv1_layer.sv
add_files ../src/conv2_layer.sv
add_files ../src/maxpool_layer.sv
add_files ../src/fc1_layer.sv
add_files ../src/fc2_layer.sv
add_files ../src/top_mnist.sv

# Add constraints
add_files -fileset constrs_1 ./timing.xdc

# Run Synthesis
synth_design -top top_mnist -part $part_name

# Run Implementation
opt_design
place_design
route_design

# Report Timing and Utilization
report_timing_summary -file ../../docs/timing_summary.txt
report_utilization -file ../../docs/utilization_report.txt

exit
