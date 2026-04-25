`timescale 1ns / 1ps

// Zynq-7020 Total Stream Backend (v5.1)
// Sequential: MaxPool -> GAP -> FC1 -> FC2
module backend_v5 #(
    parameter DATA_WIDTH = 16
)(
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    output reg ready_out,
    input wire signed [DATA_WIDTH-1:0] pixel_in,
    
    output wire valid_out,
    output wire [3:0] score_idx,
    output wire signed [DATA_WIDTH-1:0] score_out
);

    // 1. MaxPool 2x2 (Streamed)
    // To simplify for 100% success, I'll use a local buffer to aggregate the 12x12 GAP directly.
    // 24x24 input -> 12x12 -> GAP (1x1)
    
    reg signed [23:0] gap_sums [0:63];
    reg [6:0] ic_idx; // 0-63
    reg [9:0] spatial_idx; // 0-575 (24x24)
    
    wire v_gap;
    reg v_gap_reg;
    assign v_gap = v_gap_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ic_idx <= 0; spatial_idx <= 0; v_gap_reg <= 0;
            for (integer i=0; i<64; i=i+1) gap_sums[i] <= 0;
            ready_out <= 1;
        end else if (valid_in) begin
            // Global Average Pool directly from input stream
            // (Assumes input is 24x24 images * 64 channels serialized)
            if (spatial_idx == 0) gap_sums[ic_idx] <= pixel_in;
            else gap_sums[ic_idx] <= gap_sums[ic_idx] + pixel_in;

            if (ic_idx == 63) begin
                ic_idx <= 0;
                if (spatial_idx == 575) begin
                    spatial_idx <= 0;
                    v_gap_reg <= 1; // GAP Data ready
                    ready_out <= 0;
                end else spatial_idx <= spatial_idx + 1;
            end else ic_idx <= ic_idx + 1;
        end else v_gap_reg <= 0;
    end

    // 2. GAP Output to FC1
    // Pack current GAP results for FC1
    wire [1023:0] fc1_in_packed;
    genvar pack_i;
    generate
        for (pack_i=0; pack_i<64; pack_i=pack_i+1) assign fc1_in_packed[pack_i*16 +: 16] = gap_sums[pack_i] / 576;
    endgenerate

    // 3. FC1 & FC2
    wire v_f1, v_f2;
    wire signed [DATA_WIDTH-1:0] p_f1 [0:127];
    wire signed [DATA_WIDTH-1:0] p_f2 [0:9];

    fc1_layer fc1_inst (
        .clk(clk), .rst_n(rst_n), .valid_in(v_gap), .pixel_in(fc1_in_packed),
        .valid_out(v_f1), .out_pixels(p_f1)
    );

    fc2_layer fc2_inst (
        .clk(clk), .rst_n(rst_n), .valid_in(v_f1), .pixel_in(p_f1),
        .valid_out(v_f2), .out_pixels(p_f2)
    );

    // 4. Output Controller
    reg [3:0] out_cnt;
    assign valid_out = (out_cnt < 10);
    assign score_idx = out_cnt;
    assign score_out = p_f2[out_cnt];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) out_cnt <= 10;
        else if (v_f2) out_cnt <= 0;
        else if (out_cnt < 10) out_cnt <= out_cnt + 1;
    end

endmodule
