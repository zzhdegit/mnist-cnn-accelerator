`timescale 1ns / 1ps

module tb_conv2_layer_v5;
    reg clk = 0;
    reg rst_n = 0;
    reg valid_in = 0;
    wire ready_out;
    reg signed [15:0] pixel_in = 0;
    wire valid_out;
    reg ready_in = 1;
    wire signed [15:0] pixel_out;

    integer out_count = 0;

    always #5 clk = ~clk;

    conv2_layer_v5 dut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .ready_out(ready_out),
        .pixel_in(pixel_in),
        .valid_out(valid_out),
        .ready_in(ready_in),
        .pixel_out(pixel_out)
    );

    task send_scalar(input signed [15:0] value);
        begin
            @(negedge clk);
            valid_in <= 1;
            pixel_in <= value;
            while (!ready_out) @(negedge clk);
            @(posedge clk);
            #1;
        end
    endtask

    task send_vector_zero;
        begin
            for (integer ch = 0; ch < 32; ch = ch + 1) begin
                send_scalar(16'sd0);
            end
        end
    endtask

    initial begin
        repeat (4) @(posedge clk);
        rst_n <= 1;

        // Conv2 needs two adjacent 3x3 vector windows. With IMG_WIDTH=26,
        // the first pair is available after row 2, columns 2 and 3.
        for (integer pos = 0; pos < 82; pos = pos + 1) begin
            send_vector_zero();
        end
        @(negedge clk);
        valid_in <= 0;

        for (integer cyc = 0; cyc < 2000; cyc = cyc + 1) begin
            @(posedge clk);
            #1;
            if (valid_out) begin
                if (^pixel_out === 1'bx) begin
                    $display("TEST_FAIL tb_conv2_layer_v5 X output at count %0d", out_count);
                    $fatal;
                end
                out_count = out_count + 1;
                if (out_count == 64) begin
                    $display("TEST_PASS tb_conv2_layer_v5");
                    $finish;
                end
            end
        end

        $display("TEST_FAIL tb_conv2_layer_v5 timeout out_count=%0d", out_count);
        $fatal;
    end
endmodule
