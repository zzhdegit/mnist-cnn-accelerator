`timescale 1ns / 1ps

// Zynq-7020 Ultra-Lean FC1 (v6.13 - Fixed Pipeline Delay)
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

    typedef enum {IDLE, WAIT_ROM, WAIT_ROM2, COMPUTE_NEURON, STORE_NEURON, FINISH} state_t;
    state_t state;
    
    reg [7:0] oc_idx; reg [7:0] ic_idx;
    reg signed [39:0] acc;
    reg signed [31:0] prod_reg;
    reg signed [39:0] final_acc;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE; oc_idx <= 0; ic_idx <= 0;
            valid_out <= 0; w_addr <= 0; b_addr <= 0; acc <= 0;
            prod_reg <= 0;
            for (integer i=0; i<OUT_CHANNELS; i=i+1) out_pixels[i] <= 0;
        end else begin
            case (state)
                IDLE: begin
                    valid_out <= 0;
                    if (valid_in) begin
                        state <= WAIT_ROM;
                        oc_idx <= 0; b_addr <= 0; w_addr <= 0;
                    end
                end

                WAIT_ROM: begin
                    w_addr <= w_addr + 1; // Prepare next address
                    state <= WAIT_ROM2;
                end
                
                WAIT_ROM2: begin
                    w_addr <= w_addr + 1; // Prepare next address
                    state <= COMPUTE_NEURON;
                    ic_idx <= 0;
                end

                COMPUTE_NEURON: begin
                    prod_reg <= $signed(pixel_in[ic_idx*DATA_WIDTH +: DATA_WIDTH]) * rom_w_out;
                    
                    if (ic_idx == 0) acc <= (rom_b_out <<< 8);
                    else acc <= acc + prod_reg;
                    
                    if (oc_idx == 3) begin
                        if (ic_idx < 5 || ic_idx >= 60) begin
                            $display("[%t] HW oc=3, ic=%d: gap=%d, w=%d, prod=%d, acc=%d", 
                                     $time, ic_idx, $signed(pixel_in[ic_idx*DATA_WIDTH +: DATA_WIDTH]), 
                                     $signed(rom_w_out), prod_reg, acc);
                        end
                    end
                    
                    if (ic_idx == TOTAL_INPUTS) begin // Catch last product
                        state <= STORE_NEURON;
                        final_acc = acc + prod_reg;
                        // ⚡ FIXED: Added missing ReLU (limit lower bound to 0) and included final_acc
                        out_pixels[oc_idx] <= (final_acc >>> 8 > 32767) ? 16'h7FFF : (final_acc >>> 8 < 0) ? 16'd0 : final_acc[23:8];
                        if (oc_idx < 10) begin
                            $display("[%t] HW FC1_out[%d] = %d", $time, oc_idx, (final_acc >>> 8 > 32767) ? 16'h7FFF : (final_acc >>> 8 < 0) ? 16'd0 : final_acc[23:8]);
                        end
                    end else begin
                        ic_idx <= ic_idx + 1;
                        if (ic_idx < TOTAL_INPUTS - 1) w_addr <= w_addr + 1;
                    end
                end

                STORE_NEURON: begin
                    if (oc_idx == OUT_CHANNELS - 1) state <= FINISH;
                    else begin
                        oc_idx <= oc_idx + 1;
                        b_addr <= oc_idx + 1;
                        w_addr <= (oc_idx + 1) * TOTAL_INPUTS;
                        state <= WAIT_ROM;
                    end
                end

                FINISH: begin
                    valid_out <= 1; state <= IDLE;
                end
            endcase
        end
    end
endmodule
