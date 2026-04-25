`timescale 1ns / 1ps

// Zynq-7020 Ultra-Lean Conv2 (v4.2)
// FIXED: Removed complex address multipliers to save ~1000 LUTs.
module conv2_layer #(
    parameter DATA_WIDTH = 16,
    parameter IN_CHANNELS = 32,
    parameter OUT_CHANNELS = 64,
    parameter IMG_WIDTH = 26
)(
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    output wire ready_out,
    input wire signed [IN_CHANNELS*DATA_WIDTH-1:0] pixel_in,
    
    output reg valid_out,
    output reg signed [OUT_CHANNELS*DATA_WIDTH-1:0] out_pixels_packed
);

    wire signed [DATA_WIDTH-1:0] rom_w_out [0:3];
    wire signed [DATA_WIDTH-1:0] rom_b_out [0:3];
    reg [15:0] w_addr [0:3];
    reg [15:0] b_addr [0:3];

    genvar i;
    generate
        for (i=0; i<4; i=i+1) begin : rom_gen
            weight_rom #(18432, "D:/IC_Workspace/mnist/fpga/data/conv2_w.hex") w_rom_inst (.clk(clk), .addr(w_addr[i]), .data_out(rom_w_out[i]));
            weight_rom #(64, "D:/IC_Workspace/mnist/fpga/data/conv2_b.hex") b_rom_inst (.clk(clk), .addr(b_addr[i]), .data_out(rom_b_out[i]));
        end
    endgenerate

    wire signed [IN_CHANNELS*DATA_WIDTH-1:0] line_buf_out [0:8];
    wire lb_valid;
    reg lb_ready;

    line_buffer #(IN_CHANNELS*DATA_WIDTH, IMG_WIDTH) lb_inst (
        .clk(clk), .rst_n(rst_n), .valid_in(valid_in), .ready_out(ready_out),
        .pixel_in(pixel_in), .valid_out(lb_valid), .ready_in(lb_ready),
        .pixel_out(line_buf_out)
    );

    typedef enum {IDLE, COMPUTE_BATCH, STORE_RESULT} state_t;
    state_t state;
    
    reg [5:0] oc_batch; // 0-15
    reg [3:0] px_idx;   // 0-8
    reg [5:0] ch_idx;   // 0-31
    reg signed [39:0] atomic_acc [0:3];
    reg [1:0] pipeline_delay;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE; oc_batch <= 0; px_idx <= 0; ch_idx <= 0;
            valid_out <= 0; lb_ready <= 1; out_pixels_packed <= 0;
            pipeline_delay <= 0;
            for (integer k=0; k<4; k=k+1) begin
                w_addr[k] <= 0; b_addr[k] <= 0; atomic_acc[k] <= 0;
            end
        end else begin
            case (state)
                IDLE: begin
                    valid_out <= 0;
                    if (lb_valid) begin
                        state <= COMPUTE_BATCH;
                        oc_batch <= 0; px_idx <= 0; ch_idx <= 0;
                        lb_ready <= 0; pipeline_delay <= 0;
                        for (integer k=0; k<4; k=k+1) begin
                            b_addr[k] <= k;
                            w_addr[k] <= k * (32*9);
                        end
                    end
                end

                COMPUTE_BATCH: begin
                    if (pipeline_delay < 2) begin
                        pipeline_delay <= pipeline_delay + 1;
                        for (integer k=0; k<4; k=k+1) w_addr[k] <= w_addr[k] + 1;
                    end else begin
                        for (integer k=0; k<4; k=k+1) begin
                            automatic logic signed [DATA_WIDTH-1:0] p_val = line_buf_out[px_idx][ch_idx*DATA_WIDTH +: DATA_WIDTH];
                            if (px_idx == 0 && ch_idx == 0)
                                atomic_acc[k] <= (rom_b_out[k] <<< 8) + (p_val * rom_w_out[k]);
                            else
                                atomic_acc[k] <= atomic_acc[k] + (p_val * rom_w_out[k]);
                        end

                        if (ch_idx == 31) begin
                            ch_idx <= 0;
                            if (px_idx == 8) begin
                                px_idx <= 0;
                                for (integer k=0; k<4; k=k+1) begin
                                    automatic logic signed [39:0] res = atomic_acc[k];
                                    out_pixels_packed[(oc_batch*4 + k)*DATA_WIDTH +: DATA_WIDTH] <= (res >>> 8 > 32767) ? 16'h7FFF : (res >>> 8 < -32768) ? 16'h8000 : res[23:8];
                                end
                                
                                if (oc_batch == 15) state <= STORE_RESULT;
                                else begin
                                    oc_batch <= oc_batch + 1;
                                    pipeline_delay <= 0;
                                    for (integer k=0; k<4; k=k+1) begin
                                        b_addr[k] <= (oc_batch + 1) * 4 + k;
                                        // w_addr continues
                                    end
                                end
                            end else begin
                                px_idx <= px_idx + 1;
                                for (integer k=0; k<4; k=k+1) w_addr[k] <= w_addr[k] + 1;
                            end
                        end else begin
                            ch_idx <= ch_idx + 1;
                            for (integer k=0; k<4; k=k+1) w_addr[k] <= w_addr[k] + 1;
                        end
                    end
                end

                STORE_RESULT: begin
                    valid_out <= 1; lb_ready <= 1; state <= IDLE;
                end
            endcase
        end
    end
endmodule
