`timescale 1ns / 1ps

// Zynq-7020 Ultra-Lean ROM (v4.2)
// Uses BRAM output registers to minimize LUT usage
module weight_rom #(
    parameter DEPTH = 8192,
    parameter DATA_FILE = ""
)(
    input wire clk,
    input wire [15:0] addr,
    output reg signed [15:0] data_out
);
    (* ram_style = "block" *) reg signed [15:0] mem [0:DEPTH-1];
    initial if (DATA_FILE != "") $readmemh(DATA_FILE, mem);

    // Using two-stage pipeline for BRAM readout to save logic
    reg signed [15:0] mem_reg;
    always @(posedge clk) begin
        mem_reg <= mem[addr];
        data_out <= mem_reg;
    end
endmodule
