`timescale 1ns / 1ps

// Zynq-7020 Conv1 (v8.3 - Pipelined 9-way Parallel MAC)
module conv1_layer_v5 #(
    parameter DATA_WIDTH = 16,
    parameter IN_CHANNELS = 1,
    parameter OUT_CHANNELS = 32,
    parameter IMG_WIDTH = 28
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

    reg signed [DATA_WIDTH-1:0] w_mem [0:287];
    reg signed [DATA_WIDTH-1:0] b_mem [0:31];
    initial begin
        $readmemh("D:/IC_Workspace/mnist/fpga/data/conv1_w.hex", w_mem);
        $readmemh("D:/IC_Workspace/mnist/fpga/data/conv1_b.hex", b_mem);
    end

    wire signed [DATA_WIDTH-1:0] lb_out [0:8];
    wire lb_valid, lb_ready_internal;
    assign ready_out = lb_ready_internal;

    typedef enum {IDLE, COMPUTE, WAIT_PIPE, SERIAL_OUT} state_t;
    state_t state;
    
    reg [5:0] oc_idx;
    wire lb_ready = (state == SERIAL_OUT && oc_idx == 31 && valid_out && ready_in);

    line_buffer #(DATA_WIDTH, IMG_WIDTH) lb_inst (
        .clk(clk), .rst_n(rst_n), .valid_in(valid_in), .ready_out(lb_ready_internal),
        .pixel_in(pixel_in), .valid_out(lb_valid), .ready_in(lb_ready),
        .pixel_out(lb_out)
    );

    reg signed [DATA_WIDTH-1:0] results [0:31];
    reg signed [31:0] prod_regs [0:8];
    reg signed [39:0] acc_reg;
    reg [1:0] pipe_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE; oc_idx <= 0; valid_out <= 0; pixel_out <= 0;
            pipe_cnt <= 0; acc_reg <= 0;
            for (integer i=0; i<32; i=i+1) results[i] <= 0;
            for (integer i=0; i<9; i=i+1) prod_regs[i] <= 0;
        end else begin
            case (state)
                IDLE: begin
                    valid_out <= 0;
                    if (lb_valid) begin
                        state <= COMPUTE;
                        oc_idx <= 0;
                        pipe_cnt <= 0;
                    end
                end

                COMPUTE: begin
                    // Stage 1: Multiply (9 parallel multipliers)
                    for (integer i=0; i<9; i=i+1) begin
                        prod_regs[i] <= $signed(lb_out[i]) * w_mem[oc_idx*9 + i];
                    end
                    
                    // Stage 2: Sum (Accumulate results of previous cycle)
                    if (pipe_cnt > 0) begin
                        automatic logic signed [39:0] t_sum = (b_mem[oc_idx-1] <<< 8);
                        for (integer i=0; i<9; i=i+1) t_sum = t_sum + prod_regs[i];
                        results[oc_idx-1] <= (t_sum >>> 8 > 32767) ? 16'h7FFF : (t_sum >>> 8 < 0) ? 16'd0 : t_sum[23:8];
                    end

                    if (oc_idx == 32) begin
                        state <= SERIAL_OUT;
                        oc_idx <= 0;
                        valid_out <= 1;
                        pixel_out <= results[0]; 
                    end else begin
                        oc_idx <= oc_idx + 1;
                        pipe_cnt <= 1;
                    end
                end

                SERIAL_OUT: begin
                    if (valid_out && ready_in) begin
                        if (oc_idx == 31) begin
                            valid_out <= 0;
                            state <= IDLE;
                        end else begin
                            oc_idx <= oc_idx + 1;
                            pixel_out <= results[oc_idx + 1];
                        end
                    end
                end
            endcase
        end
    end
endmodule
