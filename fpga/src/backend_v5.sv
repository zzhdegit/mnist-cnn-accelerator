`timescale 1ns / 1ps

// Zynq-7020 Ultra-Slim Backend (v7.0 - Accuracy Restored)
// Sequential: MaxPool(2x2) -> GAP(12x12) -> Pipeline Register -> FC1 -> FC2
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

    // 1. MaxPool 2x2 + GAP
    reg [5:0] ic_idx; // 0-63
    reg [4:0] col_idx; // 0-23
    reg [4:0] row_idx; // 0-23
    
    // MaxPool Buffer (stores max of upper row)
    // 12 columns * 64 channels = 768 elements
    (* ram_style = "block" *) reg signed [15:0] mp_buf [0:767];
    // Temporary max for current 2x2 window (horizontal max)
    reg signed [15:0] temp_max [0:63];
    
    // GAP Accumulator
    reg signed [23:0] gap_sums [0:63];
    
    reg v_gap_pre;
    reg ready_out_reg;
    reg [3:0] out_cnt;
    reg v_gap_pipelined; // Declaration moved up
    wire release_stall = (out_cnt == 10 && v_gap_pre == 0 && v_gap_pipelined == 0);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ic_idx <= 0; col_idx <= 0; row_idx <= 0;
            v_gap_pre <= 0; ready_out_reg <= 1; ready_out <= 1;
            for(integer i=0; i<64; i=i+1) gap_sums[i] <= 0;
            for(integer i=0; i<64; i=i+1) temp_max[i] <= 0;
        end else begin
            // Pulse v_gap_pre for one cycle
            if (v_gap_pre) v_gap_pre <= 0;
            
            ready_out <= ready_out_reg;

            if (release_stall) ready_out_reg <= 1; // ⚡ FIXED: stall release logic moved here

            if (valid_in && ready_out_reg) begin
                // 1. Horizontal Max
                if (col_idx[0] == 0) begin // Even column: store
                    temp_max[ic_idx] <= pixel_in;
                end else begin // Odd column: horizontal max
                    automatic logic signed [15:0] h_max = (pixel_in > temp_max[ic_idx]) ? pixel_in : temp_max[ic_idx];
                    
                    // 2. Vertical Max
                    if (row_idx[0] == 0) begin // Even row: store to line buffer
                        mp_buf[(col_idx[4:1] * 64) + ic_idx] <= h_max;
                    end else begin // Odd row: compare with line buffer and accumulate GAP
                        automatic logic signed [15:0] top_max = mp_buf[(col_idx[4:1] * 64) + ic_idx];
                        automatic logic signed [15:0] v_max = (h_max > top_max) ? h_max : top_max;
                        
                        if (row_idx == 1 && col_idx == 1) begin
                            gap_sums[ic_idx] <= v_max; // Overwrite on first pooled pixel of new image
                        end else begin
                            gap_sums[ic_idx] <= gap_sums[ic_idx] + v_max;
                        end
                        if (ic_idx == 0) begin
                            if (row_idx == 1 && col_idx == 1)
                                $display("[%t] gap_sums[0] reset to %d", $time, v_max);
                            else if (v_max > 0)
                                $display("[%t] gap_sums[0] added %d, new total will be %d", $time, v_max, gap_sums[0] + v_max);
                        end
                    end
                end
                
                // 3. Counters
                if (ic_idx == 63) begin
                    ic_idx <= 0;
                    if (col_idx == 23) begin
                        col_idx <= 0;
                        if (row_idx == 23) begin
                            row_idx <= 0;
                            v_gap_pre <= 1;
                            ready_out_reg <= 0; // Stall input while FC processes
                        end else begin
                            row_idx <= row_idx + 1;
                        end
                    end else begin
                        col_idx <= col_idx + 1;
                    end
                end else begin
                    ic_idx <= ic_idx + 1;
                end
            end
        end
    end

    // 2. ⚡ Pipeline Stage 1
    reg [1023:0] fc1_in_packed_reg;
    // (v_gap_pipelined moved to top)
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fc1_in_packed_reg <= 0;
            v_gap_pipelined <= 0;
        end else begin
            v_gap_pipelined <= v_gap_pre;
            if (v_gap_pre) begin
                $display("[%t] HW GAP_out[0:4] = %d, %d, %d, %d, %d", $time, 
                         gap_sums[0] >>> 7, gap_sums[1] >>> 7, gap_sums[2] >>> 7, gap_sums[3] >>> 7, gap_sums[4] >>> 7);
                for (integer i=0; i<64; i=i+1) begin
                    automatic logic signed [23:0] shifted = gap_sums[i] >>> 7; // Divide by 128
                    fc1_in_packed_reg[i*16 +: 16] <= (shifted > 32767) ? 16'h7FFF : shifted[15:0];
                end
            end
        end
    end

    // 3. FC1 & FC2
    wire v_f1, v_f2;
    wire signed [DATA_WIDTH-1:0] p_f1 [0:127];
    wire signed [DATA_WIDTH-1:0] p_f2 [0:9];

    // 4. Output Controller
    // (out_cnt declaration moved to top)

    // Output Controller logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_cnt <= 10;
        end else begin
            if (v_f2) out_cnt <= 0;
            else if (out_cnt < 10) out_cnt <= out_cnt + 1;
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
