module line_buffer #(
    parameter DATA_WIDTH = 16,
    parameter IMG_WIDTH = 28
)(
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    input wire ready_in, // added for backpressure
    input wire signed [DATA_WIDTH-1:0] pixel_in,
    
    output reg valid_out,
    output wire ready_out, // added for backpressure
    output reg signed [DATA_WIDTH-1:0] p00, p01, p02,
    output reg signed [DATA_WIDTH-1:0] p10, p11, p12,
    output reg signed [DATA_WIDTH-1:0] p20, p21, p22
);
    assign ready_out = 1'b1; // Always ready for now
    // Use explicit shift registers for better simulation/synthesis alignment
    reg signed [DATA_WIDTH-1:0] shift_reg1 [0:IMG_WIDTH-1];
    reg signed [DATA_WIDTH-1:0] shift_reg2 [0:IMG_WIDTH-1];
    
    // Window registers
    reg signed [DATA_WIDTH-1:0] win [0:2][0:2];
    
    // Counters to track position
    reg [9:0] col_cnt;
    reg [9:0] row_cnt;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            col_cnt <= 0;
            row_cnt <= 0;
            valid_out <= 0;
            for (integer i = 0; i < IMG_WIDTH; i = i + 1) begin
                shift_reg1[i] <= 0;
                shift_reg2[i] <= 0;
            end
            for (integer i = 0; i < 3; i = i + 1)
                for (integer j = 0; j < 3; j = j + 1)
                    win[i][j] <= 0;
        end else if (valid_in) begin
            // 1. Vertical Shift (Pixel -> SR2 -> SR1)
            // Shift Register 2 stores the previous row
            for (integer i = IMG_WIDTH-1; i > 0; i = i - 1) shift_reg2[i] <= shift_reg2[i-1];
            shift_reg2[0] <= pixel_in;
            
            // Shift Register 1 stores the row before that
            for (integer i = IMG_WIDTH-1; i > 0; i = i - 1) shift_reg1[i] <= shift_reg1[i-1];
            shift_reg1[0] <= shift_reg2[IMG_WIDTH-1];

            // 2. Horizontal Window Shift (Forming the 3x3 matrix)
            // Column 2 is the newest data
            win[0][2] <= shift_reg1[IMG_WIDTH-1];
            win[1][2] <= shift_reg2[IMG_WIDTH-1];
            win[2][2] <= pixel_in;
            
            // Column 1 and 0 are the historical data
            for (integer i = 0; i < 3; i = i + 1) begin
                win[i][1] <= win[i][2];
                win[i][0] <= win[i][1];
            end
            
            // 3. Counter Logic
            if (col_cnt == IMG_WIDTH - 1) begin
                col_cnt <= 0;
                row_cnt <= row_cnt + 1;
            end else begin
                col_cnt <= col_cnt + 1;
            end
            
            // 4. Valid Logic: Assert when 3x3 is full
            if (row_cnt >= 2 && col_cnt >= 2)
                valid_out <= 1;
            else
                valid_out <= 0;
        end else begin
            valid_out <= 0;
        end
    end
    
    // Output the current 3x3 window
    always @(*) begin
        p00 = win[0][0]; p01 = win[0][1]; p02 = win[0][2];
        p10 = win[1][0]; p11 = win[1][1]; p12 = win[1][2];
        p20 = win[2][0]; p21 = win[2][1]; p22 = win[2][2];
    end

endmodule
