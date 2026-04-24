# Alveo U50 Performance Project (99% Accuracy Full-Speed)
set part_name "xcu50-fsvh2104-2-e"
create_project -force mnist_u50_final ./mnist_u50_final -part $part_name

# Add all high-accuracy source files
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

# Optimize for U50 architecture
set_param general.maxThreads 16

# Update compile order
update_compile_order -fileset sources_1

puts "Project mnist_u50_final created for Alveo U50."
exit
