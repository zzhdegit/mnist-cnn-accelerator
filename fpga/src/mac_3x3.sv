`timescale 1ns / 1ps

module mac_3x3 #(
    parameter DATA_WIDTH = 16
)(
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    
    input wire [DATA_WIDTH-1:0] p00, p01, p02,
    input wire [DATA_WIDTH-1:0] p10, p11, p12,
    input wire [DATA_WIDTH-1:0] p20, p21, p22,
    
    input wire [DATA_WIDTH-1:0] w00, w01, w02,
    input wire [DATA_WIDTH-1:0] w10, w11, w12,
    input wire [DATA_WIDTH-1:0] w20, w21, w22,
    input wire [DATA_WIDTH-1:0] bias,
    
    output reg valid_out,
    output reg [DATA_WIDTH-1:0] mac_out
);

    // Pipeline stages for high frequency and timing safety
    logic signed [31:0] prod [0:8];
    logic signed [31:0] b_ext;
    logic v1, v2, v3, v4;

    logic signed [35:0] sum_stage1 [0:4];
    logic signed [37:0] sum_stage2 [0:2];
    logic signed [39:0] final_sum;
    logic signed [39:0] shifted_val;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 0;
            mac_out <= 0;
            final_sum <= 0;
            shifted_val <= 0;
            v1 <= 0; v2 <= 0; v3 <= 0; v4 <= 0;
            for (integer i=0; i<9; i=i+1) prod[i] <= 0;
            for (integer i=0; i<5; i=i+1) sum_stage1[i] <= 0;
            for (integer i=0; i<3; i=i+1) sum_stage2[i] <= 0;
            b_ext <= 0;
        end else begin
            // Stage 1: Multiplication (Strict Signed)
            prod[0] <= $signed(p00) * $signed(w00);
            prod[1] <= $signed(p01) * $signed(w01);
            prod[2] <= $signed(p02) * $signed(w02);
            prod[3] <= $signed(p10) * $signed(w10);
            prod[4] <= $signed(p11) * $signed(w11);
            prod[5] <= $signed(p12) * $signed(w12);
            prod[6] <= $signed(p20) * $signed(w20);
            prod[7] <= $signed(p21) * $signed(w21);
            prod[8] <= $signed(p22) * $signed(w22);
            b_ext   <= $signed(bias) <<< 8; // Bias Q8.8 -> Q16.16
            v1      <= valid_in;

            // Stage 2: Summation Level 1
            sum_stage1[0] <= prod[0] + prod[1];
            sum_stage1[1] <= prod[2] + prod[3];
            sum_stage1[2] <= prod[4] + prod[5];
            sum_stage1[3] <= prod[6] + prod[7];
            sum_stage1[4] <= prod[8] + b_ext;
            v2 <= v1;

            // Stage 3: Summation Level 2
            sum_stage2[0] <= sum_stage1[0] + sum_stage1[1];
            sum_stage2[1] <= sum_stage1[2] + sum_stage1[3];
            sum_stage2[2] <= sum_stage1[4];
            v3 <= v2;

            // Stage 4: Final Sum
            final_sum <= sum_stage2[0] + sum_stage2[1] + sum_stage2[2];
            v4 <= v3;

            // Stage 5: Truncate and Saturate (Q16.16 -> Q8.8)
            shifted_val <= final_sum >>> 8;
            if (v4) begin
                valid_out <= 1;
                if (shifted_val > 32767) mac_out <= 16'h7FFF;
                else if (shifted_val < -32768) mac_out <= 16'h8000;
                else mac_out <= shifted_val[15:0];
            end else begin
                valid_out <= 0;
            end
        end
    end
endmodule
