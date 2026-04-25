`timescale 1ns / 1ps

// Zynq-7020 Ultra-Lean FC1 (v5.5 - Corrected Pipeline)
module fc1_layer #(
    parameter DATA_WIDTH = 16,
    parameter IN_CHANNELS = 64,
    parameter OUT_CHANNELS = 128,
    parameter IN_PIXELS = 1
)(
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    input wire [IN_CHANNELS*DATA_WIDTH-1:0] pixel_in,
    
    output reg valid_out,
    output reg signed [DATA_WIDTH-1:0] out_pixels [0:OUT_CHANNELS-1]
);

    localparam TOTAL_INPUTS = IN_CHANNELS * IN_PIXELS; 
    localparam TOTAL_WEIGHTS = OUT_CHANNELS * TOTAL_INPUTS; 

    wire signed [DATA_WIDTH-1:0] rom_w_out, rom_b_out;
    reg [15:0] w_addr, b_addr;
    weight_rom #(TOTAL_WEIGHTS, "D:/IC_Workspace/mnist/fpga/data/fc1_w.hex") w_rom_inst (.clk(clk), .addr(w_addr), .data_out(rom_w_out));
    weight_rom #(OUT_CHANNELS, "D:/IC_Workspace/mnist/fpga/data/fc1_b.hex") b_rom_inst (.clk(clk), .addr(b_addr), .data_out(rom_b_out));

    typedef enum {IDLE, FETCH_B, COMPUTE_NEURON, STORE_NEURON, FINISH} state_t;
    state_t state;
    
    reg [7:0] oc_idx; reg [7:0] ic_idx;
    reg signed [39:0] acc;
    reg [1:0] pipeline_delay;
    reg signed [31:0] prod_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE; oc_idx <= 0; ic_idx <= 0;
            valid_out <= 0; w_addr <= 0; b_addr <= 0; acc <= 0; pipeline_delay <= 0;
            prod_reg <= 0;
        end else begin
            case (state)
                IDLE: begin
                    valid_out <= 0;
                    if (valid_in) begin
                        state <= FETCH_B; oc_idx <= 0; b_addr <= 0; w_addr <= 0;
                    end
                end

                FETCH_B: begin
                    state <= COMPUTE_NEURON;
                    ic_idx <= 0; pipeline_delay <= 0;
                end

                COMPUTE_NEURON: begin
                    if (pipeline_delay < 2) begin
                        pipeline_delay <= pipeline_delay + 1;
                        w_addr <= w_addr + 1;
                    end else begin
                        // Stage 1: Multiply
                        prod_reg <= $signed(pixel_in[ic_idx*DATA_WIDTH +: DATA_WIDTH]) * rom_w_out;
                        
                        // Stage 2: Accumulate (One cycle behind)
                        if (ic_idx == 0) begin
                            acc <= (rom_b_out <<< 8); // Reset with bias
                        end else begin
                            acc <= acc + prod_reg;
                        end
                        
                        if (ic_idx == TOTAL_INPUTS) begin // +1 cycle to catch last product
                            state <= STORE_NEURON;
                            out_pixels[oc_idx] <= (acc >>> 8 > 32767) ? 16'h7FFF : (acc >>> 8 < -32768) ? 16'h8000 : acc[23:8];
                        end else begin
                            ic_idx <= ic_idx + 1;
                            if (ic_idx < TOTAL_INPUTS - 1) w_addr <= w_addr + 1;
                        end
                    end
                end

                STORE_NEURON: begin
                    if (oc_idx == OUT_CHANNELS - 1) state <= FINISH;
                    else begin
                        oc_idx <= oc_idx + 1;
                        b_addr <= oc_idx + 1;
                        state <= FETCH_B;
                    end
                end

                FINISH: begin
                    valid_out <= 1; state <= IDLE;
                end
            endcase
        end
    end
endmodule
