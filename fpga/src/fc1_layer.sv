`timescale 1ns / 1ps

module fc1_layer #(
    parameter DATA_WIDTH = 16,
    parameter IN_CHANNELS = 64,
    parameter OUT_CHANNELS = 128,
    parameter IN_PIXELS = 16 // 4x4
)(
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    input wire [IN_CHANNELS*DATA_WIDTH-1:0] pixel_in,
    
    output reg valid_out,
    output reg signed [DATA_WIDTH-1:0] out_pixels [0:OUT_CHANNELS-1]
);

    localparam TOTAL_INPUTS = IN_CHANNELS * IN_PIXELS; // 1024
    localparam TOTAL_WEIGHTS = OUT_CHANNELS * TOTAL_INPUTS; // 131072

    // Fixed: Using 1D array to bypass Vivado's 2D array bit-count limit (Synth 8-4556)
    (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] weights [0:TOTAL_WEIGHTS-1];
    (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] biases [0:OUT_CHANNELS-1];

    initial begin
        $readmemh("D:/IC_Workspace/mnist/fpga/data/fc1_w.hex", weights);
        $readmemh("D:/IC_Workspace/mnist/fpga/data/fc1_b.hex", biases);
    end

    reg [10:0] input_cnt;
    reg signed [39:0] acc [0:OUT_CHANNELS-1];
    
    typedef enum {IDLE, ACCUM, FINISH} state_t;
    state_t state;

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            input_cnt <= 0;
            valid_out <= 0;
            for (i=0; i<OUT_CHANNELS; i=i+1) acc[i] <= 0;
        end else begin
            case (state)
                IDLE: begin
                    valid_out <= 0;
                    if (valid_in) begin
                        for (i=0; i<OUT_CHANNELS; i=i+1) begin
                            acc[i] <= ($signed(biases[i]) <<< 8); 
                        end
                        state <= ACCUM;
                        input_cnt <= 0;
                    end
                end

                ACCUM: begin
                    if (valid_in) begin
                        for (i=0; i<OUT_CHANNELS; i=i+1) begin
                            // Optimized Indexing: Flattened 1D weight access
                            acc[i] <= acc[i] + $signed(pixel_in[ (input_cnt % 64)*DATA_WIDTH +: DATA_WIDTH ]) * weights[i * TOTAL_INPUTS + input_cnt];
                        end
                        
                        if (input_cnt == TOTAL_INPUTS - 1) begin
                            state <= FINISH;
                        end else begin
                            input_cnt <= input_cnt + 1;
                        end
                    end
                end

                FINISH: begin
                    for (i=0; i<OUT_CHANNELS; i=i+1) begin
                        automatic logic signed [39:0] val = acc[i];
                        if ((val >>> 8) > 32767) out_pixels[i] <= 16'h7FFF;
                        else if ((val >>> 8) < -32768) out_pixels[i] <= 16'h8000;
                        else out_pixels[i] <= val[23:8];
                    end
                    valid_out <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
