`timescale 1ns / 1ps

// Zynq-7020 Ultra-Lean Conv1 (v4.2)
// FIXED: Removed address multipliers to save ~1000 LUTs.
module conv1_layer #(
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
    output reg signed [OUT_CHANNELS*DATA_WIDTH-1:0] out_pixels_packed
);

    wire signed [DATA_WIDTH-1:0] rom_w_out, rom_b_out;
    reg [15:0] w_addr, b_addr;
    weight_rom #(OUT_CHANNELS*9, "D:/IC_Workspace/mnist/fpga/data/conv1_w.hex") w_rom_inst (.clk(clk), .addr(w_addr), .data_out(rom_w_out));
    weight_rom #(OUT_CHANNELS, "D:/IC_Workspace/mnist/fpga/data/conv1_b.hex") b_rom_inst (.clk(clk), .addr(b_addr), .data_out(rom_b_out));

    wire signed [DATA_WIDTH-1:0] line_buf_out [0:8];
    wire lb_valid;
    reg lb_ready;

    line_buffer #(DATA_WIDTH, IMG_WIDTH) lb_inst (
        .clk(clk), .rst_n(rst_n), .valid_in(valid_in), .ready_out(ready_out),
        .pixel_in(pixel_in), .valid_out(lb_valid), .ready_in(lb_ready),
        .pixel_out(line_buf_out)
    );

    typedef enum {IDLE, COMPUTE_OC, STORE_RESULT} state_t;
    state_t state;
    
    reg [5:0] oc_idx; 
    reg [3:0] px_idx;
    reg signed [39:0] atomic_acc;
    reg [1:0] pipeline_delay; // To account for BRAM 2-cycle latency

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE; oc_idx <= 0; px_idx <= 0;
            valid_out <= 0; lb_ready <= 1; atomic_acc <= 0; w_addr <= 0; b_addr <= 0;
            out_pixels_packed <= 0; pipeline_delay <= 0;
        end else begin
            case (state)
                IDLE: begin
                    valid_out <= 0;
                    if (lb_valid) begin
                        state <= COMPUTE_OC;
                        oc_idx <= 0; px_idx <= 0;
                        lb_ready <= 0; w_addr <= 0; b_addr <= 0;
                        pipeline_delay <= 0;
                    end
                end

                COMPUTE_OC: begin
                    // Pipeline Delay to align ROM output with pixel input
                    if (pipeline_delay < 2) begin
                        pipeline_delay <= pipeline_delay + 1;
                        w_addr <= w_addr + 1;
                    end else begin
                        if (px_idx == 0)
                            atomic_acc <= (rom_b_out <<< 8) + ($signed(line_buf_out[px_idx]) * rom_w_out);
                        else
                            atomic_acc <= atomic_acc + ($signed(line_buf_out[px_idx]) * rom_w_out);

                        if (px_idx == 8) begin
                            px_idx <= 0;
                            out_pixels_packed[oc_idx*DATA_WIDTH +: DATA_WIDTH] <= (atomic_acc >>> 8 > 32767) ? 16'h7FFF : (atomic_acc >>> 8 < -32768) ? 16'h8000 : atomic_acc[23:8];
                            
                            if (oc_idx == OUT_CHANNELS - 1) state <= STORE_RESULT;
                            else begin
                                oc_idx <= oc_idx + 1;
                                b_addr <= oc_idx + 1;
                                pipeline_delay <= 0; // Reset for next neuron
                                // w_addr continues from where it was
                            end
                        end else begin
                            px_idx <= px_idx + 1;
                            w_addr <= w_addr + 1;
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
