# Define 100MHz clock (10ns period)
create_clock -period 10.000 -name clk [get_ports clk]

# Basic I/O constraints (not critical for internal logic timing, but good practice)
set_input_delay -clock clk 2.000 [get_ports {valid_in pixel_in[*]}]
set_output_delay -clock clk 2.000 [get_ports {valid_out ready_out out_scores[*]}]
