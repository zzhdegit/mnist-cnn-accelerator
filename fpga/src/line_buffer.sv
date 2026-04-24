`timescale 1ns / 1ps

module line_buffer #(
    parameter DATA_WIDTH = 16,
    parameter IMG_WIDTH = 28
)(
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    input wire ready_in, 
    input wire signed [DATA_WIDTH-1:0] pixel_in,
    
    output wire valid_out,
    output wire ready_out,
    output wire signed [DATA_WIDTH-1:0] p00, p01, p02,
    output wire signed [DATA_WIDTH-1:0] p10, p11, p12,
    output wire signed [DATA_WIDTH-1:0] p20, p21, p22
);

    reg signed [DATA_WIDTH-1:0] shift_reg1 [0:IMG_WIDTH-1];
    reg signed [DATA_WIDTH-1:0] shift_reg2 [0:IMG_WIDTH-1];
    reg signed [DATA_WIDTH-1:0] win [0:2][0:2];
    reg [9:0] col_cnt, row_cnt;
    reg v_out_reg;

    assign ready_out = ready_in;
    assign valid_out = v_out_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            col_cnt <= 0; row_cnt <= 0; v_out_reg <= 0;
            for (integer i = 0; i < IMG_WIDTH; i = i + 1) begin
                shift_reg1[i] <= 0; shift_reg2[i] <= 0;
            end
            for (integer i = 0; i < 3; i = i + 1)
                for (integer j = 0; j < 3; j = j + 1)
                    win[i][j] <= 0;
        end else begin
            if (valid_in && ready_in) begin
                // Standard Shift Logic
                for (integer i = IMG_WIDTH-1; i > 0; i = i - 1) shift_reg2[i] <= shift_reg2[i-1];
                shift_reg2[0] <= pixel_in;
                for (integer i = IMG_WIDTH-1; i > 0; i = i - 1) shift_reg1[i] <= shift_reg1[i-1];
                shift_reg1[0] <= shift_reg2[IMG_WIDTH-1];

                win[0][2] <= shift_reg1[IMG_WIDTH-1];
                win[1][2] <= shift_reg2[IMG_WIDTH-1];
                win[2][2] <= pixel_in;
                for (integer i = 0; i < 3; i = i + 1) begin
                    win[i][1] <= win[i][2];
                    win[i][0] <= win[i][1];
                end

                if (col_cnt == IMG_WIDTH - 1) begin
                    col_cnt <= 0; row_cnt <= row_cnt + 1;
                end else col_cnt <= col_cnt + 1;

                v_out_reg <= (row_cnt >= 2 && col_cnt >= 2);
            end else if (ready_in) begin
                // If downstream is ready but no new input is being shifted in,
                // we must pull down valid_out to prevent re-processing the same window.
                v_out_reg <= 0;
            end
        end
    end
    
    assign p00 = win[0][0]; assign p01 = win[0][1]; assign p02 = win[0][2];
    assign p10 = win[1][0]; assign p11 = win[1][1]; assign p12 = win[1][2];
    assign p20 = win[2][0]; assign p21 = win[2][1]; assign p22 = win[2][2];

endmodule
