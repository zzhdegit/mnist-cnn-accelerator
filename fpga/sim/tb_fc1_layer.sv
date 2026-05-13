`timescale 1ns / 1ps

module tb_fc1_layer;
    reg clk = 0;
    reg rst_n = 0;
    reg valid_in = 0;
    wire [1:0] feature_addr;
    reg signed [15:0] feature_data;
    wire valid_out;
    wire signed [15:0] out_pixels [0:3];

    reg signed [15:0] features [0:3];

    always #5 clk = ~clk;

    always @(*) begin
        feature_data = features[feature_addr];
    end

    fc1_layer #(
        .DATA_WIDTH(16),
        .IN_CHANNELS(2),
        .OUT_CHANNELS(4),
        .IN_PIXELS(2),
        .W_FILE("D:/IC_Workspace/mnist/fpga/sim/data/fc1_small_w.hex"),
        .B_FILE("D:/IC_Workspace/mnist/fpga/sim/data/fc1_small_b.hex")
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .feature_addr(feature_addr),
        .feature_data(feature_data),
        .valid_out(valid_out),
        .out_pixels(out_pixels)
    );

    initial begin
        features[0] = 16'sh0100;
        features[1] = 16'sh0200;
        features[2] = -16'sh0100;
        features[3] = 16'sh0080;

        repeat (4) @(posedge clk);
        rst_n <= 1;
        @(posedge clk);
        valid_in <= 1;
        @(posedge clk);
        valid_in <= 0;

        for (integer cyc = 0; cyc < 200; cyc = cyc + 1) begin
            @(posedge clk);
            if (valid_out) begin
                #1;
                if (out_pixels[0] !== 16'sh0100 || out_pixels[1] !== 16'sh0200 ||
                    out_pixels[2] !== 16'sh0280 || out_pixels[3] !== 16'sh0000) begin
                    $display("TEST_FAIL tb_fc1_layer outputs=%h %h %h %h",
                        out_pixels[0], out_pixels[1], out_pixels[2], out_pixels[3]);
                    $fatal;
                end
                $display("TEST_PASS tb_fc1_layer");
                $finish;
            end
        end

        $display("TEST_FAIL tb_fc1_layer timeout");
        $fatal;
    end
endmodule
