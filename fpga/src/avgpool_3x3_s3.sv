`timescale 1ns / 1ps

// Accurate 12x12 -> 4x4 Average Pool (3x3 window, stride 3)
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

    // Buffers to store 2 full rows
    reg [CHANNELS*DATA_WIDTH-1:0] row_mem1 [0:IMG_WIDTH-1];
    reg [CHANNELS*DATA_WIDTH-1:0] row_mem2 [0:IMG_WIDTH-1];
    
    reg [3:0] col_ptr;
    reg [3:0] row_ptr;
    
    // Sum registers for the 3x3 window
    // We need to accumulate 9 pixels of 16-bit each
    reg signed [23:0] sums [0:CHANNELS-1];

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            col_ptr <= 0;
            row_ptr <= 0;
            valid_out <= 0;
            pixel_out <= 0;
            for (i=0; i<IMG_WIDTH; i=i+1) begin
                row_mem1[i] <= 0;
                row_mem2[i] <= 0;
            end
            for (i=0; i<CHANNELS; i=i+1) sums[i] <= 0;
        end else if (valid_in) begin
            // 1. Shift row memories
            row_mem1[col_ptr] <= row_mem2[col_ptr];
            row_mem2[col_ptr] <= pixel_in;

            // 2. Accumulate spatial values for the current 3x3 window
            // The window is formed by [row_mem1, row_mem2, pixel_in] at [col_ptr-2, col_ptr-1, col_ptr]
            // However, to keep it simple and low-resource, we accumulate as pixels arrive.
            for (i=0; i<CHANNELS; i=i+1) begin
                logic signed [15:0] p_now, p_m1, p_m2;
                p_now = $signed(pixel_in[i*DATA_WIDTH +: DATA_WIDTH]);
                p_m1  = $signed(row_mem2[col_ptr][i*DATA_WIDTH +: DATA_WIDTH]);
                p_m2  = $signed(row_mem1[col_ptr][i*DATA_WIDTH +: DATA_WIDTH]);
                
                if (col_ptr % 3 == 0) begin
                    // Start of a new 3x3 horizontal window
                    sums[i] <= p_now + p_m1 + p_m2;
                end else begin
                    // Add to current horizontal accumulation
                    sums[i] <= sums[i] + p_now + p_m1 + p_m2;
                end
            end

            // 3. Output Logic (Stride 3)
            if (row_ptr % 3 == 2 && col_ptr % 3 == 2) begin
                valid_out <= 1;
                for (i=0; i<CHANNELS; i=i+1) begin
                    // The division by 9 is performed on the final sum
                    // Final sum = current pixel + previous 2 rows + previous 2 columns (of 3-row stacks)
                    // Note: 'sums' already contains (row_ptr, col_ptr-1) and (row_ptr, col_ptr-2) contributions
                    // plus current column's 3-pixel stack.
                    pixel_out[i*DATA_WIDTH +: DATA_WIDTH] <= (sums[i] / 9);
                end
            end else begin
                valid_out <= 0;
            end

            // 4. Pointer Management
            if (col_ptr == IMG_WIDTH - 1) begin
                col_ptr <= 0;
                if (row_ptr == IMG_WIDTH - 1) row_ptr <= 0;
                else row_ptr <= row_ptr + 1;
            end else begin
                col_ptr <= col_ptr + 1;
            end
        end else begin
            valid_out <= 0;
        end
    end
endmodule
