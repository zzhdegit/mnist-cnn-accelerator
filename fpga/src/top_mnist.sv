`timescale 1ns / 1ps

module top_mnist #(
    parameter DATA_WIDTH = 16
)(
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    output wire ready_out,
    input wire signed [DATA_WIDTH-1:0] pixel_in,
    
    // Weights and Biases (Conv layers only)
    input wire signed [DATA_WIDTH-1:0] w_c1 [0:31][0:8],
    input wire signed [DATA_WIDTH-1:0] b_c1 [0:31],
    input wire signed [DATA_WIDTH-1:0] w_c2 [0:63][0:31][0:8],
    input wire signed [DATA_WIDTH-1:0] b_c2 [0:63],
    
    output wire valid_out,
    output wire signed [DATA_WIDTH-1:0] out_scores [0:9]
);

    // 1. Conv1 (1 -> 32)
    wire v_c1;
    wire r_c1; // Ready signal from Conv2
    wire r_c1_out; // Ready signal to top
    wire signed [DATA_WIDTH-1:0] p_c1 [0:31];
    conv1_layer #(16, 28, 32) conv1_inst (
        .clk(clk), .rst_n(rst_n), .valid_in(valid_in), .ready_in(r_c1), 
        .pixel_in(pixel_in), .valid_out(v_c1), .ready_out(r_c1_out),
        .weights(w_c1), .biases(b_c1), .out_pixels(p_c1)
    );
    
    assign ready_out = r_c1_out;

    // 2. ReLU1 & Packing
    wire [511:0] p_c1_packed;
    genvar i;
    generate
        for (i=0; i<32; i=i+1) begin : relu1_pack
            assign p_c1_packed[i*16 +: 16] = (p_c1[i] < 0) ? 16'd0 : p_c1[i];
        end
    endgenerate
    
    // 3. Conv2 (32 -> 64)
    wire v_c2;
    wire r_c2_out; // Ready signal to Conv1
    wire signed [DATA_WIDTH-1:0] p_c2 [0:63];
    conv2_layer #(16, 32, 64, 26) conv2_inst (
        .clk(clk), .rst_n(rst_n), .valid_in(v_c1), .ready_out(r_c2_out), .pixel_in(p_c1_packed),
        .weights(w_c2), .biases(b_c2), .valid_out(v_c2), .out_pixels(p_c2)
    );
    
    assign r_c1 = r_c2_out;

    // 4. ReLU2 & Packing
    wire [1023:0] p_c2_packed;
    generate
        for (i=0; i<64; i=i+1) begin : relu2_pack
            assign p_c2_packed[i*16 +: 16] = (p_c2[i] < 0) ? 16'd0 : p_c2[i];
        end
    endgenerate
    
    // 5. MaxPool (2x2 -> 12x12)
    wire v_mp;
    wire [1023:0] p_mp;
    maxpool2d #(16, 64, 24) pool_inst (
        .clk(clk), .rst_n(rst_n), .valid_in(v_c2), .pixel_in(p_c2_packed),
        .valid_out(v_mp), .pixel_out(p_mp)
    );

    // 6. AvgPool (3x3 s3 -> 12x12 to 4x4)
    wire v_ap;
    wire [1023:0] p_ap;
    avgpool_3x3_s3 #(16, 64, 12) avg_pool_inst (
        .clk(clk), .rst_n(rst_n), .valid_in(v_mp), .pixel_in(p_mp),
        .valid_out(v_ap), .pixel_out(p_ap)
    );
    
    // 7. FC1 (64*4*4=1024 -> 128)
    wire v_f1;
    wire signed [DATA_WIDTH-1:0] p_f1 [0:127];
    fc1_layer #(16, 64, 128, 16) fc1_inst ( 
        .clk(clk), .rst_n(rst_n), .valid_in(v_ap), .pixel_in(p_ap),
        .valid_out(v_f1), .out_pixels(p_f1)
    );
    
    // 8. FC2 (128 -> 10)
    fc2_layer #(16, 128, 10) fc2_inst (
        .clk(clk), .rst_n(rst_n), .valid_in(v_f1), .pixel_in(p_f1),
        .valid_out(valid_out), .out_pixels(out_scores)
    );

    // Debug signals
    always @(posedge clk) begin
        if (valid_in && ready_out) $display("[%t] TOP: Pixel In", $time);
        if (v_c1 && r_c1) $display("[%t] TOP: C1 -> C2 Handshake", $time);
        if (v_f1) $display("[%t] TOP: FC1 Finished", $time);
    end

endmodule
