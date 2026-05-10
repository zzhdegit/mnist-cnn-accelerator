set tag "iter0_baseline"
if {[llength $argv] >= 1} {
    set tag [lindex $argv 0]
}

set script_dir [file normalize [file dirname [info script]]]
set root [file normalize [file join $script_dir "../.."]]
set build_dir [file join $root "fpga/build/$tag"]
set project_dir [file join $build_dir "project"]
set report_dir [file join $build_dir "reports"]
file mkdir $report_dir

create_project -force $tag $project_dir -part xc7z020clg400-1
set_property target_language Verilog [current_project]

set src_dir [file join $root "fpga/src"]
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
add_files -fileset constrs_1 [file join $root "fpga/scripts/timing.xdc"]
set_property top top_mnist [current_fileset]
update_compile_order -fileset sources_1

launch_runs synth_1 -jobs 4
wait_on_run synth_1
open_run synth_1
report_utilization -file [file join $report_dir "synth_utilization.rpt"]
report_timing_summary -file [file join $report_dir "synth_timing_summary.rpt"]

launch_runs impl_1 -to_step route_design -jobs 4
wait_on_run impl_1
open_run impl_1
report_utilization -file [file join $report_dir "route_utilization.rpt"]
report_timing_summary -file [file join $report_dir "route_timing_summary.rpt"]
report_timing -max_paths 20 -file [file join $report_dir "route_timing_paths.rpt"]

close_project
