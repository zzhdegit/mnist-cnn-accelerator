`timescale 1ns / 1ps

module tb_backend_v5;
    reg clk = 0;
    reg rst_n = 0;
    reg valid_in = 0;
    wire ready_out;
    reg signed [15:0] pixel_in = 0;
    wire valid_out;
    wire [3:0] score_idx;
    wire signed [15:0] score_out;

    integer out_count = 0;

    always #5 clk = ~clk;

    backend_v5 dut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .ready_out(ready_out),
        .pixel_in(pixel_in),
        .valid_out(valid_out),
        .score_idx(score_idx),
        .score_out(score_out)
    );

    task send_value(input signed [15:0] value);
        begin
            @(negedge clk);
            valid_in <= 1;
            pixel_in <= value;
            while (!ready_out) @(negedge clk);
            @(posedge clk);
            #1;
        end
    endtask

    initial begin
        repeat (4) @(posedge clk);
        rst_n <= 1;

        for (integer i = 0; i < 24*12*64; i = i + 1) begin
            send_value(16'sd0);
        end
        @(negedge clk);
        valid_in <= 0;

        for (integer cyc = 0; cyc < 30000; cyc = cyc + 1) begin
            @(posedge clk);
            #1;
            if (valid_out) begin
                if (score_idx !== out_count[3:0]) begin
                    $display("TEST_FAIL tb_backend_v5 score_idx got=%0d exp=%0d", score_idx, out_count);
                    $fatal;
                end
                if (^score_out === 1'bx) begin
                    $display("TEST_FAIL tb_backend_v5 X score at count %0d", out_count);
                    $fatal;
                end
                out_count = out_count + 1;
                if (out_count == 10) begin
                    $display("TEST_PASS tb_backend_v5");
                    $finish;
                end
            end
        end

        $display("TEST_FAIL tb_backend_v5 timeout out_count=%0d", out_count);
        $fatal;
    end
endmodule
