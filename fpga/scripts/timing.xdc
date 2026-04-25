# Define 100MHz clock (10ns period)
create_clock -period 10.000 -name clk [get_ports clk]

# Basic I/O constraints (Optimized for Zynq-7020 standard peripherals)
# 10ns period - 8ns delay = 2ns margin for OBUF + Package Delay.
# This is a realistic constraint for 100MHz GPIO on 7-series.
set_input_delay -clock clk 3.000 [get_ports {valid_in pixel_in[*]}]
set_output_delay -clock clk 8.000 [get_ports {valid_out ready_out score_out[*] score_idx[*]}]
