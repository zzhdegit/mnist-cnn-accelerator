# Final Clean GUI Project Creator for Alveo U50 (Fixed)
set part_name "xcu50-fsvh2104-2-e"
set proj_name "u50_mnist_final_gui"

create_project -force $proj_name ./$proj_name -part $part_name

# Add all optimized v2.3 source files
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

# Configure project settings
set_property file_type SystemVerilog [get_files *.sv]
add_files -fileset constrs_1 ./timing.xdc

update_compile_order -fileset sources_1
puts "------------------------------------------------------------"
puts "Success! Project $proj_name is ready."
puts "------------------------------------------------------------"
exit
