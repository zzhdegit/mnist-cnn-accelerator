# Use a new project name to avoid permission denied on locked files
create_project -force mnist_top_sim_final ./mnist_top_sim_final

# Add ALL files explicitly
add_files ../src/line_buffer.sv
add_files ../src/mac_3x3.sv
add_files ../src/mac_3x3x32.sv
add_files ../src/conv1_layer.sv
add_files ../src/conv2_layer.sv
add_files ../src/maxpool_layer.sv
add_files ../src/fc1_layer.sv
add_files ../src/fc2_layer.sv
add_files ../src/top_mnist.sv
add_files -fileset sim_1 ../sim/tb_mnist_top.sv

# Force SystemVerilog type
set_property file_type SystemVerilog [get_files *.sv]

# Refresh
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

set_property top tb_mnist_top [get_filesets sim_1]
launch_simulation
run all
exit