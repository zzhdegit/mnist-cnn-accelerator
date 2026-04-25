`timescale 1ns / 1ps

// Zynq-7020 Ultra-Slim Conv1 (v5.7 - Fully Optimized)
module conv1_layer_v5 #(
    parameter DATA_WIDTH = 16,
    parameter IMG_WIDTH = 28,
    parameter OUT_CHANNELS = 32
)(
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    output wire ready_out,
    input wire signed [DATA_WIDTH-1:0] pixel_in,
    
    output reg valid_out,
    input wire ready_in,
    output reg signed [DATA_WIDTH-1:0] pixel_out
);

    wire signed [DATA_WIDTH-1:0] rom_w_out, rom_b_out;
    reg [15:0] w_addr, b_addr;
    weight_rom #(OUT_CHANNELS*9, "D:/IC_Workspace/mnist/fpga/data/conv1_w.hex") w_rom_inst (.clk(clk), .addr(w_addr), .data_out(rom_w_out));
    weight_rom #(OUT_CHANNELS, "D:/IC_Workspace/mnist/fpga/data/conv1_b.hex") b_rom_inst (.clk(clk), .addr(b_addr), .data_out(rom_b_out));

    wire signed [DATA_WIDTH-1:0] line_buf_out [0:8];
    wire lb_valid, lb_ready;

    line_buffer #(DATA_WIDTH, IMG_WIDTH) lb_inst (
        .clk(clk), .rst_n(rst_n), .valid_in(valid_in), .ready_out(ready_out),
        .pixel_in(pixel_in), .valid_out(lb_valid), .ready_in(lb_ready),
        .pixel_out(line_buf_out)
    );

    typedef enum {IDLE, COMPUTE_OC, SERIAL_OUT} state_t;
    state_t state;
    
    reg [5:0] oc_idx; reg [3:0] px_idx;
    reg signed [39:0] acc;
    reg [1:0] pipe_delay;
    reg signed [31:0] prod_q;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE; oc_idx <= 0; px_idx <= 0;
            valid_out <= 0; acc <= 0; w_addr <= 0; b_addr <= 0;
            pipe_delay <= 0; prod_q <= 0;
        end else begin
            case (state)
                IDLE: begin
                    valid_out <= 0;
                    if (lb_valid) begin
                        state <= COMPUTE_OC;
                        oc_idx <= 0; px_idx <= 0;
                        w_addr <= 0; b_addr <= 0;
                        pipe_delay <= 0;
                    end
                end

                COMPUTE_OC: begin
                    if (pipe_delay < 2) begin
                        pipe_delay <= pipe_delay + 1;
                        w_addr <= w_addr + 1;
                    end else begin
                        // Sequential Pipeline
                        prod_q <= $signed(line_buf_out[px_idx]) * rom_w_out;
                        
                        if (px_idx == 0) acc <= (rom_b_out <<< 8);
                        else acc <= acc + prod_q;

                        if (px_idx == 9) begin // +1 cycle to catch last product
                            px_idx <= 0;
                            // Saturated RELU
                            pixel_out <= (acc >>> 8 > 32767) ? 16'h7FFF : (acc >>> 8 < 0) ? 16'd0 : acc[23:8];
                            valid_out <= 1;
                            state <= SERIAL_OUT;
                        end else begin
                            px_idx <= px_idx + 1;
                            if (px_idx < 8) w_addr <= w_addr + 1;
                        end
                    end
                end

                SERIAL_OUT: begin
                    if (ready_in) begin
                        valid_out <= 0;
                        if (oc_idx == OUT_CHANNELS - 1) begin
                            state <= IDLE;
                        end else begin
                            oc_idx <= oc_idx + 1;
                            b_addr <= oc_idx + 1;
                            w_addr <= (oc_idx + 1) * 9; // Reset address for next neuron
                            pipe_delay <= 0;
                            state <= COMPUTE_OC;
                        end
                    end
                end
            endcase
        end
    end
    assign lb_ready = (state == IDLE);
endmodule
