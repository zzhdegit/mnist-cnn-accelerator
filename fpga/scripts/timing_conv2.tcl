# Use a new project name to avoid permission denied on locked files
set part_name "xc7z020clg400-1"
create_project -force conv2_timing_v3 ./conv2_timing_v3 -part $part_name

# Add required files for Conv2
add_files ../src/line_buffer.sv
add_files ../src/mac_3x3x32.sv
add_files ../src/conv2_layer.sv

# Add constraints
add_files -fileset constrs_1 ./timing.xdc

# Run Synthesis ONLY for Conv2
synth_design -top conv2_layer -part $part_name -directive RuntimeOptimized

# Run Implementation
opt_design
place_design
route_design

# Report results
report_timing_summary -file ../../docs/conv2_timing.txt
report_utilization -file ../../docs/conv2_utilization.txt

exit
