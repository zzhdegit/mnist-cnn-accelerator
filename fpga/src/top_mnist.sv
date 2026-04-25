`timescale 1ns / 1ps

// Zynq-7020 Total Stream Version (v5.0)
// No wide buses. All data flows via 16-bit serial stream.
module top_mnist #(
    parameter DATA_WIDTH = 16
)(
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    output wire ready_out,
    input wire signed [DATA_WIDTH-1:0] pixel_in,
    
    output wire valid_out,
    output wire [3:0] score_idx,
    output wire signed [DATA_WIDTH-1:0] score_out
);

    // 1. Conv1 (1 -> 32)
    wire v_c1, r_c1;
    wire signed [DATA_WIDTH-1:0] p_c1_serial;
    conv1_layer_v5 conv1_inst (
        .clk(clk), .rst_n(rst_n), .valid_in(valid_in), .ready_out(ready_out), 
        .pixel_in(pixel_in), .valid_out(v_c1), .ready_in(r_c1),
        .pixel_out(p_c1_serial) // 16-bit only!
    );

    // 2. ReLU1 + Conv2 (32 -> 64)
    // Note: ReLU is now implicit inside the stream or next layer
    wire v_c2, r_c2;
    wire signed [DATA_WIDTH-1:0] p_c2_serial;
    conv2_layer_v5 conv2_inst (
        .clk(clk), .rst_n(rst_n), .valid_in(v_c1), .ready_out(r_c1), 
        .pixel_in(p_c1_serial), .valid_out(v_c2), .ready_in(r_c2),
        .pixel_out(p_c2_serial) // 16-bit only!
    );

    // 3. MaxPool -> GAP -> FC1 -> FC2 (Streamed)
    // To save time, I am merging these into a simplified backend stream
    backend_v5 backend_inst (
        .clk(clk), .rst_n(rst_n), .valid_in(v_c2), .ready_out(r_c2),
        .pixel_in(p_c2_serial), .valid_out(valid_out), .score_idx(score_idx), .score_out(score_out)
    );

endmodule
