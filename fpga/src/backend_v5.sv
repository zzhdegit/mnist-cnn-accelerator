`timescale 1ns / 1ps

// Zynq-7020 Ultra-Slim Backend (v5.3 - Fixed Multi-Driver)
// FINAL MERGE: All ready_out logic in ONE always block.
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

    reg signed [23:0] gap_sums [0:63];
    reg [6:0] ic_idx; 
    reg [9:0] spatial_idx; 
    reg v_gap_pre;

    reg [1023:0] fc1_in_packed_reg;
    reg v_gap_pipelined;
    
    wire v_f1, v_f2;
    wire signed [DATA_WIDTH-1:0] p_f1 [0:127];
    wire signed [DATA_WIDTH-1:0] p_f2 [0:9];

    reg [3:0] out_cnt;

    // ⚡ ONE SINGLE ALWAYS BLOCK for all sequential logic in this module
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ic_idx <= 0; spatial_idx <= 0; v_gap_pre <= 0;
            for (integer i=0; i<64; i=i+1) gap_sums[i] <= 0;
            ready_out <= 1;
            fc1_in_packed_reg <= 0;
            v_gap_pipelined <= 0;
            out_cnt <= 10;
        end else begin
            // 1. GAP Logic
            if (valid_in) begin
                if (spatial_idx == 0) gap_sums[ic_idx] <= pixel_in;
                else gap_sums[ic_idx] <= gap_sums[ic_idx] + pixel_in;

                if (ic_idx == 63) begin
                    ic_idx <= 0;
                    if (spatial_idx == 575) begin
                        spatial_idx <= 0;
                        v_gap_pre <= 1; 
                        ready_out <= 0; // Stall input while processing FC
                    end else spatial_idx <= spatial_idx + 1;
                end else ic_idx <= ic_idx + 1;
            end else begin
                v_gap_pre <= 0;
            end

            // 2. Pipeline Scaling
            v_gap_pipelined <= v_gap_pre;
            if (v_gap_pre) begin
                for (integer i=0; i<64; i=i+1) begin
                    fc1_in_packed_reg[i*16 +: 16] <= (gap_sums[i] >>> 9);
                end
            end

            // 3. Output Controller & Ready Release
            if (v_f2) begin
                out_cnt <= 0;
            end else if (out_cnt < 10) begin
                out_cnt <= out_cnt + 1;
            end else if (out_cnt == 10) begin
                ready_out <= 1; // Processing finished, ready for next image
            end
        end
    end

    fc1_layer fc1_inst (
        .clk(clk), .rst_n(rst_n), .valid_in(v_gap_pipelined), .pixel_in(fc1_in_packed_reg),
        .valid_out(v_f1), .out_pixels(p_f1)
    );

    fc2_layer fc2_inst (
        .clk(clk), .rst_n(rst_n), .valid_in(v_f1), .pixel_in(p_f1),
        .valid_out(v_f2), .out_pixels(p_f2)
    );

    assign valid_out = (out_cnt < 10);
    assign score_idx = out_cnt;
    assign score_out = p_f2[out_cnt];

endmodule
