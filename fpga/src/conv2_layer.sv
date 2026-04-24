module conv2_layer #(
    parameter DATA_WIDTH = 16,
    parameter IN_CHANNELS = 32,
    parameter OUT_CHANNELS = 64,
    parameter IMG_WIDTH = 26
)(
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    input wire [IN_CHANNELS*DATA_WIDTH-1:0] pixel_in, // 512-bit input (Conv1 output flattened)
    
    // Weights and Biases
    input wire signed [DATA_WIDTH-1:0] weights [0:OUT_CHANNELS-1][0:IN_CHANNELS-1][0:8],
    input wire signed [DATA_WIDTH-1:0] biases [0:OUT_CHANNELS-1],
    
    output wire valid_out,
    output wire signed [DATA_WIDTH-1:0] out_pixels [0:OUT_CHANNELS-1]
);

    wire window_valid;
    wire [IN_CHANNELS*DATA_WIDTH-1:0] p00, p01, p02, p10, p11, p12, p20, p21, p22;
    
    // Line buffer with 512-bit width
    line_buffer #(
        .DATA_WIDTH(IN_CHANNELS * DATA_WIDTH),
        .IMG_WIDTH(IMG_WIDTH)
    ) lb_inst (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .ready_in(1'b1),
        .pixel_in(pixel_in),
        .valid_out(window_valid),
        .ready_out(),
        .p00(p00), .p01(p01), .p02(p02),
        .p10(p10), .p11(p11), .p12(p12),
        .p20(p20), .p21(p21), .p22(p22)
    );
    
    wire [OUT_CHANNELS-1:0] mac_valids;
    
    // Instantiate 64 MAC units in parallel
    genvar i;
    generate
        for (i = 0; i < OUT_CHANNELS; i = i + 1) begin : mac_array
            mac_3x3x32 #(
                .IN_CHANNELS(IN_CHANNELS),
                .DATA_WIDTH(DATA_WIDTH)
            ) mac_inst (
                .clk(clk),
                .rst_n(rst_n),
                .valid_in(window_valid),
                
                .p00(p00), .p01(p01), .p02(p02),
                .p10(p10), .p11(p11), .p12(p12),
                .p20(p20), .p21(p21), .p22(p22),
                
                .weights(weights[i]),
                .bias(biases[i]),
                
                .valid_out(mac_valids[i]),
                .mac_out(out_pixels[i])
            );
        end
    endgenerate

    assign valid_out = mac_valids[0];

endmodule