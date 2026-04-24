`timescale 1ns / 1ps

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

    reg signed [DATA_WIDTH-1:0] w_rom [0:OUT_CHANNELS*IN_CHANNELS-1];
    reg signed [DATA_WIDTH-1:0] b_rom [0:OUT_CHANNELS-1];

    initial begin
        $readmemh("D:/IC_Workspace/mnist/fpga/data/fc2_w.hex", w_rom);
        $readmemh("D:/IC_Workspace/mnist/fpga/data/fc2_b.hex", b_rom);
    end

    typedef enum logic {IDLE_CALC = 1'b0, DONE = 1'b1} state_t;
    state_t state;
    
    integer oc, ic;
    logic signed [39:0] cur_acc;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 0;
            state <= IDLE_CALC;
            for (oc=0; oc<OUT_CHANNELS; oc=oc+1) out_pixels[oc] <= 0;
        end else begin
            case (state)
                IDLE_CALC: begin
                    if (valid_in) begin
                        for (oc=0; oc<OUT_CHANNELS; oc=oc+1) begin
                            cur_acc = $signed(b_rom[oc]) <<< 8;
                            for (ic=0; ic<IN_CHANNELS; ic=ic+1) begin
                                cur_acc = cur_acc + $signed(pixel_in[ic]) * w_rom[oc*IN_CHANNELS + ic];
                            end
                            
                            if ((cur_acc >>> 8) > 32767) out_pixels[oc] <= 16'h7FFF;
                            else if ((cur_acc >>> 8) < -32768) out_pixels[oc] <= 16'h8000;
                            else out_pixels[oc] <= cur_acc[23:8];
                        end
                        valid_out <= 1;
                        state <= DONE;
                    end else begin
                        valid_out <= 0;
                    end
                end
                
                DONE: begin
                    valid_out <= 0;
                    state <= IDLE_CALC;
                end
            endcase
        end
    end
endmodule
