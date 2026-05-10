`timescale 1ns / 1ps

// Zynq-7020 Ultra-Lean ROM (v4.2)
// Uses BRAM output registers to minimize LUT usage
module weight_rom #(
    parameter DEPTH = 8192,
    parameter DATA_FILE = "",
    parameter ADDR_WIDTH = (DEPTH <= 1) ? 1 : $clog2(DEPTH)
)(
    input wire clk,
    input wire [ADDR_WIDTH-1:0] addr,
    output reg signed [15:0] data_out
);
    (* ram_style = "block" *) reg signed [15:0] mem [0:DEPTH-1];
    reg signed [15:0] mem_reg;
    initial begin
        mem_reg = 0;
        data_out = 0;
        if (DATA_FILE != "") $readmemh(DATA_FILE, mem);
    end

    // Using two-stage pipeline for BRAM readout to save logic
    always @(posedge clk) begin
        mem_reg <= mem[addr];
        data_out <= mem_reg;
    end
endmodule
