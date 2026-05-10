`timescale 1ns / 1ps

// Zynq-7020 Total Stream Version (v6.4 - Debug & Fix)
module top_mnist #(
    parameter DATA_WIDTH = 16
)(
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    output wire ready_out,
    input wire signed [DATA_WIDTH-1:0] pixel_in,
    
    output wire valid_out,
    output wire [3:0] score_idx,
    output wire signed [DATA_WIDTH-1:0] score_out
);

    wire v_c1, r_c1, v_c2, r_c2;
    wire r_input_to_conv1;
    wire signed [DATA_WIDTH-1:0] p_c1_serial, p_c2_serial;

    (* IOB = "true" *) reg ready_out_q;
    reg in_buf_valid;
    reg signed [DATA_WIDTH-1:0] in_buf_pixel;
    wire conv1_accept = in_buf_valid && r_input_to_conv1;
    wire input_accept = valid_in && ready_out_q;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ready_out_q <= 1'b1;
            in_buf_valid <= 1'b0;
            in_buf_pixel <= '0;
        end else begin
            if (conv1_accept) begin
                in_buf_valid <= 1'b0;
            end
            if (input_accept) begin
                in_buf_valid <= 1'b1;
                in_buf_pixel <= pixel_in;
            end
            ready_out_q <= !((in_buf_valid && !conv1_accept) || input_accept);
        end
    end

    assign ready_out = ready_out_q;

    // 1. Conv1
    conv1_layer_v5 conv1_inst (
        .clk(clk), .rst_n(rst_n), .valid_in(in_buf_valid), .ready_out(r_input_to_conv1),
        .pixel_in(in_buf_pixel), .valid_out(v_c1), .ready_in(r_c1),
        .pixel_out(p_c1_serial)
    );

    // 2. Conv2 - FIXED HANDSHAKE
    conv2_layer_v5 conv2_inst (
        .clk(clk), .rst_n(rst_n), .valid_in(v_c1), .ready_out(r_c1), 
        .pixel_in(p_c1_serial), .valid_out(v_c2), .ready_in(r_c2),
        .pixel_out(p_c2_serial)
    );

    // Final Outputs (Wires declared before use)
    wire v_out_internal;
    wire [3:0] idx_internal;
    wire signed [DATA_WIDTH-1:0] score_internal;

    // 3. Backend
    backend_v5 backend_inst (
        .clk(clk), .rst_n(rst_n), .valid_in(v_c2), .ready_out(r_c2),
        .pixel_in(p_c2_serial), 
        .valid_out(v_out_internal), .score_idx(idx_internal), .score_out(score_internal)
    );
    
    (* IOB = "true" *) reg v_out_q;
    (* IOB = "true" *) reg [3:0] idx_q;
    (* IOB = "true" *) reg signed [DATA_WIDTH-1:0] score_q;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v_out_q <= 0; idx_q <= 0; score_q <= 0;
        end else begin
            v_out_q <= v_out_internal;
            idx_q <= idx_internal;
            score_q <= score_internal;
        end
    end

    assign valid_out = v_out_q;
    assign score_idx = idx_q;
    assign score_out = score_q;

endmodule
