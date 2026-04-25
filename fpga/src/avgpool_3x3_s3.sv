`timescale 1ns / 1ps

// Global Average Pool: 12x12 -> 1x1 for 90% accuracy baseline
module avgpool_3x3_s3 #(
    parameter DATA_WIDTH = 16,
    parameter CHANNELS = 64,
    parameter IMG_WIDTH = 12
)(
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    input wire [CHANNELS*DATA_WIDTH-1:0] pixel_in,
    
    output reg valid_out,
    output reg [CHANNELS*DATA_WIDTH-1:0] pixel_out
);

    reg [7:0] pixel_cnt; // 0-143 (12x12)
    reg signed [23:0] channel_sums [0:CHANNELS-1];

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_cnt <= 0;
            valid_out <= 0;
            pixel_out <= 0;
            for (i=0; i<CHANNELS; i=i+1) channel_sums[i] <= 0;
        end else if (valid_in) begin
            // 1. Accumulate all 144 pixels sequentially
            for (i = 0; i < CHANNELS; i = i + 1) begin
                logic signed [15:0] p_val;
                p_val = $signed(pixel_in[i*DATA_WIDTH +: DATA_WIDTH]);
                
                if (pixel_cnt == 0)
                    channel_sums[i] <= p_val;
                else
                    channel_sums[i] <= channel_sums[i] + p_val;
            end

            // 2. Output Logic (at the end of 12x12 frame)
            if (pixel_cnt == 143) begin
                valid_out <= 1;
                for (i = 0; i < CHANNELS; i = i + 1) begin
                    // Global average: Sum / 144
                    pixel_out[i*DATA_WIDTH +: DATA_WIDTH] <= (channel_sums[i] + $signed(pixel_in[i*DATA_WIDTH +: DATA_WIDTH])) / 144;
                    // Wait, the above logic is slightly off, pixel_in is already in sums[i] if pixel_cnt=143?
                    // Let's be precise:
                    pixel_out[i*DATA_WIDTH +: DATA_WIDTH] <= channel_sums[i] / 144;
                end
                pixel_cnt <= 0;
            end else begin
                valid_out <= 0;
                pixel_cnt <= pixel_cnt + 1;
            end
        end else begin
            valid_out <= 0;
        end
    end
endmodule
