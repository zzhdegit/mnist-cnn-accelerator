`timescale 1ns / 1ps

// Zynq-7020 Robust FIFO-style Line Buffer (v8.2 - Zero-initialized)
module line_buffer #(
    parameter DATA_WIDTH = 16,
    parameter IMG_WIDTH = 28
)(
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    output wire ready_out,
    input wire signed [DATA_WIDTH-1:0] pixel_in,
    
    output reg valid_out,
    input wire ready_in,
    output reg signed [DATA_WIDTH-1:0] pixel_out [0:8]
);

    // Three rows of storage: 2 FIFOs (for row 0 and 1) + current row registers
    // Since width is small (28), we use registers/Distributed RAM to save BRAM
    reg signed [DATA_WIDTH-1:0] fifo1 [0:IMG_WIDTH-1];
    reg signed [DATA_WIDTH-1:0] fifo2 [0:IMG_WIDTH-1];
    
    reg [7:0] write_ptr;
    reg [7:0] row_cnt;
    reg [7:0] col_cnt;
    
    // Window registers (3x3)
    reg signed [DATA_WIDTH-1:0] r0_t0, r0_t1;
    reg signed [DATA_WIDTH-1:0] r1_t0, r1_t1;
    reg signed [DATA_WIDTH-1:0] r2_t0, r2_t1;

    assign ready_out = !valid_out || ready_in;

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_ptr <= 0; row_cnt <= 0; col_cnt <= 0;
            valid_out <= 0;
            r0_t0 <= 0; r0_t1 <= 0;
            r1_t0 <= 0; r1_t1 <= 0;
            r2_t0 <= 0; r2_t1 <= 0;
            for (i=0; i<IMG_WIDTH; i=i+1) begin
                fifo1[i] <= 0; fifo2[i] <= 0;
            end
            for (i=0; i<9; i=i+1) pixel_out[i] <= 0;
        end else if (valid_in && ready_out) begin
            // Shift registers for current window
            r0_t1 <= r0_t0; r0_t0 <= fifo1[write_ptr];
            r1_t1 <= r1_t0; r1_t0 <= fifo2[write_ptr];
            r2_t1 <= r2_t0; r2_t0 <= pixel_in;

            // Update FIFOs
            fifo1[write_ptr] <= fifo2[write_ptr];
            fifo2[write_ptr] <= pixel_in;

            // Pointers
            if (write_ptr == IMG_WIDTH - 1) begin
                write_ptr <= 0;
                row_cnt <= (row_cnt == IMG_WIDTH - 1) ? 0 : row_cnt + 1;
            end else write_ptr <= write_ptr + 1;

            if (col_cnt == IMG_WIDTH - 1) col_cnt <= 0;
            else col_cnt <= col_cnt + 1;

            if (row_cnt >= 2 && col_cnt >= 2) begin
                valid_out <= 1;
                pixel_out[0] <= r0_t1; pixel_out[1] <= r0_t0; pixel_out[2] <= fifo1[write_ptr];
                pixel_out[3] <= r1_t1; pixel_out[4] <= r1_t0; pixel_out[5] <= fifo2[write_ptr];
                pixel_out[6] <= r2_t1; pixel_out[7] <= r2_t0; pixel_out[8] <= pixel_in;
            end else valid_out <= 0;
        end else if (valid_out && ready_in) begin
            valid_out <= 0;
        end
    end
endmodule
