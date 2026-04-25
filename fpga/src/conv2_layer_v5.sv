`timescale 1ns / 1ps

// Zynq-7020 Ultra-Slim Conv2 (v5.0 - Fixed Syntax)
module conv2_layer_v5 #(
    parameter DATA_WIDTH = 16,
    parameter IN_CHANNELS = 32,
    parameter OUT_CHANNELS = 64,
    parameter IMG_WIDTH = 26
)(
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    output reg ready_out,
    input wire signed [DATA_WIDTH-1:0] pixel_in,
    
    output reg valid_out,
    input wire ready_in,
    output reg signed [DATA_WIDTH-1:0] pixel_out
);

    wire signed [DATA_WIDTH-1:0] rom_w_out, rom_b_out;
    reg [15:0] w_addr, b_addr;
    weight_rom #(OUT_CHANNELS*IN_CHANNELS*9, "D:/IC_Workspace/mnist/fpga/data/conv2_w.hex") w_rom_inst (.clk(clk), .addr(w_addr), .data_out(rom_w_out));
    weight_rom #(OUT_CHANNELS, "D:/IC_Workspace/mnist/fpga/data/conv2_b.hex") b_rom_inst (.clk(clk), .addr(b_addr), .data_out(rom_b_out));

    reg signed [DATA_WIDTH-1:0] lb_in_array [0:31];
    reg [5:0] ic_fill_cnt;
    wire [511:0] lb_pixel_in;
    
    genvar pack_i;
    generate
        for (pack_i=0; pack_i<32; pack_i=pack_i+1) assign lb_pixel_in[pack_i*16 +: 16] = lb_in_array[pack_i];
    endgenerate

    wire signed [511:0] lb_out [0:8];
    wire lb_valid;
    reg lb_ready;

    line_buffer #(512, 26) lb_inst (
        .clk(clk), .rst_n(rst_n), .valid_in(ic_fill_cnt == 32), .ready_out(lb_ready_internal),
        .pixel_in(lb_pixel_in), .valid_out(lb_valid), .ready_in(lb_ready),
        .pixel_out(lb_out)
    );
    wire lb_ready_internal;

    typedef enum {IDLE, FETCH_CHANNELS, COMPUTE_OC, SERIAL_OUT} state_t;
    state_t state;
    
    reg [6:0] oc_idx; reg [3:0] px_idx; reg [5:0] ic_idx;
    reg signed [39:0] acc;
    reg [1:0] pipe_delay;
    reg signed [39:0] res_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE; oc_idx <= 0; px_idx <= 0; ic_idx <= 0;
            valid_out <= 0; acc <= 0; ic_fill_cnt <= 0; ready_out <= 1;
            lb_ready <= 0; res_reg <= 0; w_addr <= 0; b_addr <= 0;
            pipe_delay <= 0;
        end else begin
            case (state)
                IDLE: begin
                    valid_out <= 0; ready_out <= 1;
                    if (valid_in) begin
                        lb_in_array[ic_fill_cnt] <= pixel_in;
                        if (ic_fill_cnt == 31) begin
                            ic_fill_cnt <= 32;
                            ready_out <= 0;
                            state <= FETCH_CHANNELS;
                        end else ic_fill_cnt <= ic_fill_cnt + 1;
                    end
                end

                FETCH_CHANNELS: begin
                    if (lb_valid) begin
                        state <= COMPUTE_OC;
                        oc_idx <= 0; px_idx <= 0; ic_idx <= 0;
                        pipe_delay <= 0; lb_ready <= 0;
                    end
                end

                COMPUTE_OC: begin
                    if (pipe_delay < 2) begin
                        pipe_delay <= pipe_delay + 1;
                        w_addr <= oc_idx*32*9 + ic_idx*9 + px_idx;
                    end else begin
                        automatic logic signed [15:0] p_val = lb_out[px_idx][ic_idx*16 +: 16];
                        if (px_idx == 0 && ic_idx == 0) acc <= (rom_b_out <<< 8) + (p_val * rom_w_out);
                        else acc <= acc + (p_val * rom_w_out);

                        if (ic_idx == 31 && px_idx == 8) begin
                            res_reg = acc + (p_val * rom_w_out);
                            pixel_out <= (res_reg >>> 8 > 32767) ? 16'h7FFF : (res_reg >>> 8 < 0) ? 16'd0 : res_reg[23:8];
                            valid_out <= 1;
                            state <= SERIAL_OUT;
                        end else begin
                            if (px_idx == 8) begin px_idx <= 0; ic_idx <= ic_idx + 1; end
                            else px_idx <= px_idx + 1;
                            w_addr <= oc_idx*32*9 + (ic_idx*9 + px_idx) + 1;
                        end
                    end
                end

                SERIAL_OUT: begin
                    if (ready_in) begin
                        if (oc_idx == 63) begin
                            valid_out <= 0; ic_fill_cnt <= 0; lb_ready <= 1; state <= IDLE;
                        end else begin
                            oc_idx <= oc_idx + 1; ic_idx <= 0; px_idx <= 0;
                            pipe_delay <= 0; state <= COMPUTE_OC;
                        end
                    end
                end
            endcase
        end
    end
endmodule
