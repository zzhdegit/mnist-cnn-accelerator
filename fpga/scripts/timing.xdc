# Define 80MHz clock (12.5ns period)
create_clock -period 12.500 -name clk [get_ports clk]

# Basic I/O constraints
set_input_delay -clock clk 3.000 [get_ports {valid_in pixel_in[*]}]
set_output_delay -clock clk 3.000 [get_ports {valid_out ready_out score_out[*] score_idx[*]}]
