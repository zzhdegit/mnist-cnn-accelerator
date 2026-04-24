create_project -force conv2_sim ./conv2_sim
add_files ../src/line_buffer.v
add_files ../src/mac_3x3x32.v
add_files ../src/conv2_layer.v
add_files -fileset sim_1 ../sim/tb_conv2.v
set_property file_type SystemVerilog [get_files *.v]
set_property top tb_conv2 [get_filesets sim_1]
launch_simulation
run all
exit