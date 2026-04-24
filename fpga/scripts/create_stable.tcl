# Create final stable project for U50
set part_name "xcu50-fsvh2104-2-e"
create_project -force mnist_u50_stable ./mnist_u50_stable -part $part_name

# Add all files
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

update_compile_order -fileset sources_1
puts "Project mnist_u50_stable created successfully."
exit
