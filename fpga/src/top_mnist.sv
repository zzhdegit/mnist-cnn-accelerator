`timescale 1ns / 1ps

// Zynq-7020 Ultra-Stable Top Level (v5.4 - Final IO Optimized)
// FIXED: Added registered outputs with IOB attributes to close 100MHz IO timing.
module top_mnist #(
    parameter DATA_WIDTH = 16
)(
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    output wire ready_out,
    input wire signed [DATA_WIDTH-1:0] pixel_in,
    
    output reg valid_out,
    output reg [3:0] score_idx,
    output reg signed [DATA_WIDTH-1:0] score_out
);

    // Internal connections to backend
    wire v_out_internal;
    wire [3:0] idx_internal;
    wire signed [DATA_WIDTH-1:0] score_internal;
    wire v_c1, r_c1, v_c2, r_c2;
    wire signed [DATA_WIDTH-1:0] p_c1_serial, p_c2_serial;

    // 1. Conv1
    conv1_layer_v5 conv1_inst (
        .clk(clk), .rst_n(rst_n), .valid_in(valid_in), .ready_out(ready_out), 
        .pixel_in(pixel_in), .valid_out(v_c1), .ready_in(r_c1),
        .pixel_out(p_c1_serial)
    );

    // 2. Conv2
    conv2_layer_v5 conv2_inst (
        .clk(clk), .rst_n(rst_n), .valid_in(v_c1), .ready_out(r_c1), 
        .pixel_in(p_c1_serial), .valid_out(v_c2), .ready_in(r_c2),
        .pixel_out(p_c2_serial)
    );

    // 3. Backend (MaxPool -> GAP -> FCs)
    backend_v5 backend_inst (
        .clk(clk), .rst_n(rst_n), .valid_in(v_c2), .ready_out(r_c2),
        .pixel_in(p_c2_serial), 
        .valid_out(v_out_internal), .score_idx(idx_internal), .score_out(score_internal)
    );

    // ⚡ Final Pipeline Stage: Registered Outputs to ensure IOB placement
    // This breaks the combinationsl path from internal registers to pads.
    (* IOB = "true" *) reg v_out_q;
    (* IOB = "true" *) reg [3:0] idx_q;
    (* IOB = "true" *) reg signed [DATA_WIDTH-1:0] score_q;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v_out_q <= 0;
            idx_q <= 0;
            score_q <= 0;
        end else begin
            v_out_q <= v_out_internal;
            idx_q <= idx_internal;
            score_q <= score_internal;
        end
    end

    // Connect引脚
    assign valid_out = v_out_q;
    assign score_idx = idx_q;
    assign score_out = score_q;

endmodule
