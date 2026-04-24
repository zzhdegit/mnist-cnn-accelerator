module maxpool2d #(
    parameter DATA_WIDTH = 16,
    parameter CHANNELS = 64,
    parameter IMG_WIDTH = 24
)(
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    input wire [CHANNELS*DATA_WIDTH-1:0] pixel_in,
    
    output reg valid_out,
    output reg [CHANNELS*DATA_WIDTH-1:0] pixel_out
);

    reg [CHANNELS*DATA_WIDTH-1:0] line_buf [0:IMG_WIDTH-1];
    reg [9:0] col_cnt;
    reg [9:0] row_cnt;
    reg [CHANNELS*DATA_WIDTH-1:0] p_left; 
    
    integer ch;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            col_cnt <= 0;
            row_cnt <= 0;
            valid_out <= 0;
            pixel_out <= 0;
            p_left <= 0;
            for (integer i=0; i<IMG_WIDTH; i=i+1) line_buf[i] <= 0;
        end else if (valid_in) begin
            // 1. Store current pixel to compare with next row
            line_buf[col_cnt] <= pixel_in;
            p_left <= pixel_in;
            
            // 2. Perform pooling every 2x2 window
            // Maxpool happens when we are at odd rows (1, 3, 5...) and odd columns (1, 3, 5...)
            if (row_cnt[0] == 1'b1 && col_cnt[0] == 1'b1) begin
                valid_out <= 1;
                for (ch = 0; ch < CHANNELS; ch = ch + 1) begin
                    automatic logic signed [DATA_WIDTH-1:0] v0, v1, v2, v3, m0, m1;
                    v0 = $signed(pixel_in[ch*DATA_WIDTH +: DATA_WIDTH]); // Current (Bottom-Right)
                    v1 = $signed(p_left[ch*DATA_WIDTH +: DATA_WIDTH]);   // Previous in row (Bottom-Left) - wait p_left is current!
                    // Actually, p_left hasn't updated yet in non-blocking, so p_left IS the previous pixel.
                    v2 = $signed(line_buf[col_cnt][ch*DATA_WIDTH +: DATA_WIDTH]); // Same col, previous row (Top-Right)
                    v3 = $signed(line_buf[col_cnt-1][ch*DATA_WIDTH +: DATA_WIDTH]); // Prev col, previous row (Top-Left)
                    
                    m0 = (v0 > v1) ? v0 : v1;
                    m1 = (v2 > v3) ? v2 : v3;
                    pixel_out[ch*DATA_WIDTH +: DATA_WIDTH] <= (m0 > m1) ? m0 : m1;
                end
            end else begin
                valid_out <= 0;
            end
            
            // 3. Update Counters
            if (col_cnt == IMG_WIDTH - 1) begin
                col_cnt <= 0;
                row_cnt <= row_cnt + 1;
            end else begin
                col_cnt <= col_cnt + 1;
            end
        end else begin
            valid_out <= 0;
        end
    end
endmodule
