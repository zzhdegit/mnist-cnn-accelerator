`timescale 1ns / 1ps

module fc1_layer #(
    parameter DATA_WIDTH = 16,
    parameter IN_CHANNELS = 64,
    parameter OUT_CHANNELS = 128,
    parameter IN_PIXELS = 144
)(
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    input wire [IN_CHANNELS*DATA_WIDTH-1:0] pixel_in,
    
    output reg valid_out,
    output reg signed [DATA_WIDTH-1:0] out_pixels [0:OUT_CHANNELS-1]
);

    // 1D ROM for weights (1,179,648 elements)
    // Using a 1D array helps synthesis infer BRAM more reliably
    reg signed [DATA_WIDTH-1:0] w_rom [0:OUT_CHANNELS*IN_PIXELS*IN_CHANNELS-1];
    reg signed [DATA_WIDTH-1:0] b_rom [0:OUT_CHANNELS-1];

    initial begin
        $readmemh("D:/IC_Workspace/mnist/fpga/data/fc1_w.hex", w_rom);
        $readmemh("D:/IC_Workspace/mnist/fpga/data/fc1_b.hex", b_rom);
    end

    reg signed [39:0] accumulators [0:OUT_CHANNELS-1];
    reg [9:0] pixel_cnt;
    
    typedef enum logic {IDLE_ACCUM = 1'b0, FINALIZE = 1'b1} state_t;
    state_t state;

    integer oc, ic;
    // Use non-nested temporary variables to help synthesis
    logic signed [39:0] acc_prev;
    logic signed [39:0] prod_sum;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_cnt <= 0;
            valid_out <= 0;
            state <= IDLE_ACCUM;
            for (oc=0; oc<OUT_CHANNELS; oc=oc+1) begin
                accumulators[oc] <= 0;
                out_pixels[oc] <= 0;
            end
        end else begin
            case (state)
                IDLE_ACCUM: begin
                    valid_out <= 0;
                    if (valid_in) begin
                        for (oc=0; oc<OUT_CHANNELS; oc=oc+1) begin
                            acc_prev = (pixel_cnt == 0) ? 40'd0 : accumulators[oc];
                            prod_sum = 0;
                            for (ic=0; ic<IN_CHANNELS; ic=ic+1) begin
                                prod_sum = prod_sum + $signed(pixel_in[ic*DATA_WIDTH +: DATA_WIDTH]) * w_rom[oc*(IN_PIXELS*IN_CHANNELS) + pixel_cnt*IN_CHANNELS + ic];
                            end
                            accumulators[oc] <= acc_prev + prod_sum;
                        end
                        
                        if (pixel_cnt == IN_PIXELS - 1) begin
                            pixel_cnt <= 0;
                            state <= FINALIZE;
                        end else begin
                            pixel_cnt <= pixel_cnt + 1;
                        end
                    end
                end
                
                FINALIZE: begin
                    valid_out <= 1;
                    for (oc=0; oc<OUT_CHANNELS; oc=oc+1) begin
                        automatic logic signed [39:0] f_sum = accumulators[oc] + ($signed(b_rom[oc]) <<< 8);
                        automatic logic signed [15:0] sc;
                        if ((f_sum >>> 8) > 32767) sc = 32767;
                        else if ((f_sum >>> 8) < -32768) sc = -32768;
                        else sc = f_sum[23:8];
                        out_pixels[oc] <= (sc < 0) ? 16'd0 : sc;
                    end
                    state <= IDLE_ACCUM;
                end
            endcase
        end
    end
endmodule
