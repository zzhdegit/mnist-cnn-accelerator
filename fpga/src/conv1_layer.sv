module conv1_layer #(
    parameter DATA_WIDTH = 16,
    parameter IMG_WIDTH = 28,
    parameter OUT_CHANNELS = 32
)(
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    input wire ready_in,
    input wire signed [DATA_WIDTH-1:0] pixel_in,
    
    // Weights and Biases interface (flattened for simplicity in this top module)
    input wire signed [DATA_WIDTH-1:0] weights [0:OUT_CHANNELS-1][0:8],
    input wire signed [DATA_WIDTH-1:0] biases [0:OUT_CHANNELS-1],
    
    output wire valid_out,
    output wire ready_out,
    output wire signed [DATA_WIDTH-1:0] out_pixels [0:OUT_CHANNELS-1]
);

    wire window_valid;
    wire signed [DATA_WIDTH-1:0] p00, p01, p02, p10, p11, p12, p20, p21, p22;
    
    // Instantiate 1 Line Buffer
    line_buffer #(
        .DATA_WIDTH(DATA_WIDTH),
        .IMG_WIDTH(IMG_WIDTH)
    ) lb_inst (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .ready_in(ready_in),
        .pixel_in(pixel_in),
        .valid_out(window_valid),
        .ready_out(ready_out),
        .p00(p00), .p01(p01), .p02(p02),
        .p10(p10), .p11(p11), .p12(p12),
        .p20(p20), .p21(p21), .p22(p22)
    );
    
    wire [OUT_CHANNELS-1:0] mac_valids;
    
    // Instantiate 32 MAC units in parallel
    genvar i;
    generate
        for (i = 0; i < OUT_CHANNELS; i = i + 1) begin : mac_array
            mac_3x3 #(
                .DATA_WIDTH(DATA_WIDTH)
            ) mac_inst (
                .clk(clk),
                .rst_n(rst_n),
                .valid_in(window_valid),
                
                .p00(p00), .p01(p01), .p02(p02),
                .p10(p10), .p11(p11), .p12(p12),
                .p20(p20), .p21(p21), .p22(p22),
                
                .w00(weights[i][0]), .w01(weights[i][1]), .w02(weights[i][2]),
                .w10(weights[i][3]), .w11(weights[i][4]), .w12(weights[i][5]),
                .w20(weights[i][6]), .w21(weights[i][7]), .w22(weights[i][8]),
                .bias(biases[i]),
                
                .valid_out(mac_valids[i]),
                .mac_out(out_pixels[i])
            );
        end
    endgenerate

    // All MACs will have identical valid_out timing, just use the first one
    assign valid_out = mac_valids[0];

endmodule
