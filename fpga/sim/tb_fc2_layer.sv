`timescale 1ns / 1ps

module tb_fc2_layer;
    reg clk = 0;
    reg rst_n = 0;
    reg valid_in = 0;
    reg signed [15:0] pixel_in [0:3];
    wire valid_out;
    wire signed [15:0] out_pixels [0:2];

    always #5 clk = ~clk;

    fc2_layer #(
        .DATA_WIDTH(16),
        .IN_CHANNELS(4),
        .OUT_CHANNELS(3),
        .W_FILE("D:/IC_Workspace/mnist/fpga/sim/data/fc2_small_w.hex"),
        .B_FILE("D:/IC_Workspace/mnist/fpga/sim/data/fc2_small_b.hex")
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .pixel_in(pixel_in),
        .valid_out(valid_out),
        .out_pixels(out_pixels)
    );

    initial begin
        pixel_in[0] = 16'sh0100;
        pixel_in[1] = 16'sh0200;
        pixel_in[2] = -16'sh0100;
        pixel_in[3] = 16'sh0080;

        repeat (4) @(posedge clk);
        rst_n <= 1;
        @(posedge clk);
        valid_in <= 1;
        @(posedge clk);
        valid_in <= 0;

        for (integer cyc = 0; cyc < 300; cyc = cyc + 1) begin
            @(posedge clk);
            if (valid_out) begin
                #1;
                if (out_pixels[0] !== 16'sh0100 || out_pixels[1] !== 16'sh0200 ||
                    out_pixels[2] !== -16'sh0100) begin
                    $display("TEST_FAIL tb_fc2_layer outputs=%h %h %h",
                        out_pixels[0], out_pixels[1], out_pixels[2]);
                    $fatal;
                end
                $display("TEST_PASS tb_fc2_layer");
                $finish;
            end
        end

        $display("TEST_FAIL tb_fc2_layer timeout");
        $fatal;
    end
endmodule
