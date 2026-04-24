create_project -force backend_sim ./backend_sim
add_files ../src/maxpool_layer.v
add_files ../src/fc1_layer.v
add_files ../src/fc2_layer.v
add_files -fileset sim_1 ../sim/tb_backend.v
set_property file_type SystemVerilog [get_files *.v]
update_compile_order -fileset sources_1
set_property top tb_backend [get_filesets sim_1]
launch_simulation
run all
exit