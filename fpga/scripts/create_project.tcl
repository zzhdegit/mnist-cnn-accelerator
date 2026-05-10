# Vivado project creation script for the current MNIST CNN accelerator.
# Usage from fpga/scripts:
#   vivado -mode batch -source create_project.tcl

set project_name "mnist_zynq_7020_rs"
set part_name "xc7z020clg400-1"

set script_dir [file normalize [file dirname [info script]]]
set root [file normalize [file join $script_dir "../.."]]
set project_dir [file join $root "fpga/build/manual_project"]
set src_dir [file join $root "fpga/src"]
set sim_dir [file join $root "fpga/sim"]

create_project -force $project_name $project_dir -part $part_name
set_property target_language Verilog [current_project]

add_files [list \
    [file join $src_dir "weight_rom.sv"] \
    [file join $src_dir "line_buffer.sv"] \
    [file join $src_dir "conv1_layer_v5.sv"] \
    [file join $src_dir "conv2_layer_v5.sv"] \
    [file join $src_dir "fc1_layer.sv"] \
    [file join $src_dir "fc2_layer.sv"] \
    [file join $src_dir "backend_v5.sv"] \
    [file join $src_dir "top_mnist.sv"] \
]
add_files -fileset sim_1 [file join $sim_dir "tb_mnist_top_acc.sv"]
add_files -fileset constrs_1 [file join $root "fpga/scripts/timing.xdc"]

set_property top top_mnist [current_fileset]
set_property top tb_mnist_top_acc [get_filesets sim_1]
set_property xsim.simulate.runtime "all" [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "===================================================="
puts "  MNIST CNN RS accelerator project created"
puts "  Target: Zynq-7020 xc7z020clg400-1"
puts "  Top: top_mnist"
puts "  Simulation top: tb_mnist_top_acc"
puts "===================================================="
