`timescale 1ns / 1ps

// Zynq-7020 Ultra-Lean FC2 (v6.13 - Fixed Pipeline Delay)
module fc2_layer #(
    parameter DATA_WIDTH = 16,
    parameter IN_CHANNELS = 128,
    parameter OUT_CHANNELS = 10
)(
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    input wire signed [DATA_WIDTH-1:0] pixel_in [0:IN_CHANNELS-1],
    
    output reg valid_out,
    output reg signed [DATA_WIDTH-1:0] out_pixels [0:OUT_CHANNELS-1]
);

    localparam TOTAL_WEIGHTS = OUT_CHANNELS * IN_CHANNELS; 

    wire signed [DATA_WIDTH-1:0] rom_w_out, rom_b_out;
    reg [15:0] w_addr, b_addr;
    weight_rom #(TOTAL_WEIGHTS, "D:/IC_Workspace/mnist/fpga/data/fc2_w.hex") w_rom_inst (.clk(clk), .addr(w_addr), .data_out(rom_w_out));
    weight_rom #(OUT_CHANNELS, "D:/IC_Workspace/mnist/fpga/data/fc2_b.hex") b_rom_inst (.clk(clk), .addr(b_addr), .data_out(rom_b_out));

    typedef enum {IDLE, WAIT_ROM, WAIT_ROM2, COMPUTE_NEURON, STORE_NEURON, FINISH} state_t;
    state_t state;
    
    reg [3:0] oc_idx; reg [7:0] ic_idx;
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
                    prod_reg <= pixel_in[ic_idx] * rom_w_out;
                    
                    if (ic_idx == 0) begin
                        acc <= (rom_b_out <<< 8);
                    end else begin
                        acc <= acc + prod_reg;
                    end
                    
                    if (ic_idx == IN_CHANNELS) begin // Catch last product
                        state <= STORE_NEURON;
                        final_acc = acc + prod_reg;
                        out_pixels[oc_idx] <= (final_acc >>> 8 > 32767) ? 16'h7FFF : (final_acc >>> 8 < -32768) ? 16'h8000 : final_acc[23:8];
                    end else begin
                        ic_idx <= ic_idx + 1;
                        if (ic_idx < IN_CHANNELS - 1) w_addr <= w_addr + 1;
                    end
                end

                STORE_NEURON: begin
                    if (oc_idx == OUT_CHANNELS - 1) state <= FINISH;
                    else begin
                        oc_idx <= oc_idx + 1;
                        b_addr <= oc_idx + 1;
                        w_addr <= (oc_idx + 1) * IN_CHANNELS;
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
