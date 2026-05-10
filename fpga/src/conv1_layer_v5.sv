`timescale 1ns / 1ps

// Zynq-7020 Conv1 (v8.4 - Pipelined 9-way MAC with staged reduction)
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

    typedef enum logic [1:0] {IDLE, COMPUTE, SERIAL_OUT} state_t;
    state_t state;

    reg [5:0] serial_oc;
    wire lb_ready = (state == SERIAL_OUT && serial_oc == 31 && valid_out && ready_in);

    line_buffer #(DATA_WIDTH, IMG_WIDTH) lb_inst (
        .clk(clk), .rst_n(rst_n), .valid_in(valid_in), .ready_out(lb_ready_internal),
        .pixel_in(pixel_in), .valid_out(lb_valid), .ready_in(lb_ready),
        .pixel_out(lb_out)
    );

    reg signed [DATA_WIDTH-1:0] results [0:31];
    reg signed [31:0] prod_regs [0:8];
    reg signed [39:0] part_sum0;
    reg signed [39:0] part_sum1;
    reg signed [39:0] part_sum2;
    reg signed [39:0] part_bias;
    reg [5:0] issue_oc;
    reg [5:0] prod_oc;
    reg [5:0] part_oc;
    reg prod_valid;
    reg part_valid;

    function automatic signed [DATA_WIDTH-1:0] sat_relu(input signed [39:0] value);
        begin
            if ((value >>> 8) > 32767) sat_relu = 16'sh7fff;
            else if ((value >>> 8) < 0) sat_relu = 16'sh0000;
            else sat_relu = value[23:8];
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            serial_oc <= 0;
            valid_out <= 0;
            pixel_out <= 0;
            issue_oc <= 0;
            prod_oc <= 0;
            part_oc <= 0;
            prod_valid <= 0;
            part_valid <= 0;
            part_sum0 <= 0;
            part_sum1 <= 0;
            part_sum2 <= 0;
            part_bias <= 0;
            for (integer i = 0; i < 32; i = i + 1) results[i] <= 0;
            for (integer i = 0; i < 9; i = i + 1) prod_regs[i] <= 0;
        end else begin
            case (state)
                IDLE: begin
                    valid_out <= 0;
                    prod_valid <= 0;
                    part_valid <= 0;
                    if (lb_valid) begin
                        state <= COMPUTE;
                        issue_oc <= 0;
                    end
                end

                COMPUTE: begin
                    if (part_valid) begin
                        automatic logic signed [39:0] final_sum;
                        final_sum = part_bias + part_sum0 + part_sum1 + part_sum2;
                        results[part_oc] <= sat_relu(final_sum);
                        if (part_oc == 31) begin
                            state <= SERIAL_OUT;
                            serial_oc <= 0;
                            valid_out <= 1;
                            pixel_out <= results[0];
                        end
                    end

                    if (prod_valid) begin
                        part_sum0 <= $signed(prod_regs[0]) + $signed(prod_regs[1]) + $signed(prod_regs[2]);
                        part_sum1 <= $signed(prod_regs[3]) + $signed(prod_regs[4]) + $signed(prod_regs[5]);
                        part_sum2 <= $signed(prod_regs[6]) + $signed(prod_regs[7]) + $signed(prod_regs[8]);
                        part_bias <= (b_mem[prod_oc] <<< 8);
                        part_oc <= prod_oc;
                        part_valid <= 1;
                    end else begin
                        part_valid <= 0;
                    end

                    if (issue_oc < 32) begin
                        for (integer i = 0; i < 9; i = i + 1) begin
                            prod_regs[i] <= $signed(lb_out[i]) * w_mem[issue_oc * 9 + i];
                        end
                        prod_oc <= issue_oc;
                        prod_valid <= 1;
                        issue_oc <= issue_oc + 1;
                    end else begin
                        prod_valid <= 0;
                    end
                end

                SERIAL_OUT: begin
                    if (valid_out && ready_in) begin
                        if (serial_oc == 31) begin
                            valid_out <= 0;
                            state <= IDLE;
                        end else begin
                            serial_oc <= serial_oc + 1;
                            pixel_out <= results[serial_oc + 1];
                        end
                    end
                end
            endcase
        end
    end
endmodule
