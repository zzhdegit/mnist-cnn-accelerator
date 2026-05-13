`timescale 1ns / 1ps

module tb_line_buffer;
    localparam DATA_WIDTH = 16;
    localparam IMG_WIDTH = 6;

    reg clk = 0;
    reg rst_n = 0;
    reg valid_in = 0;
    wire ready_out;
    reg signed [DATA_WIDTH-1:0] pixel_in = 0;
    wire valid_out;
    reg ready_in = 1;
    wire signed [DATA_WIDTH-1:0] pixel_out [0:8];

    integer first_checked = 0;

    always #5 clk = ~clk;

    line_buffer #(
        .DATA_WIDTH(DATA_WIDTH),
        .IMG_WIDTH(IMG_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .ready_out(ready_out),
        .pixel_in(pixel_in),
        .valid_out(valid_out),
        .ready_in(ready_in),
        .pixel_out(pixel_out)
    );

    task check_window0;
        begin
            if (pixel_out[0] !== 16'sd0 || pixel_out[1] !== 16'sd1 || pixel_out[2] !== 16'sd2 ||
                pixel_out[3] !== 16'sd6 || pixel_out[4] !== 16'sd7 || pixel_out[5] !== 16'sd8 ||
                pixel_out[6] !== 16'sd12 || pixel_out[7] !== 16'sd13 || pixel_out[8] !== 16'sd14) begin
                $display("TEST_FAIL tb_line_buffer first window got %0d %0d %0d / %0d %0d %0d / %0d %0d %0d",
                    pixel_out[0], pixel_out[1], pixel_out[2],
                    pixel_out[3], pixel_out[4], pixel_out[5],
                    pixel_out[6], pixel_out[7], pixel_out[8]);
                $fatal;
            end
        end
    endtask

    initial begin
        repeat (3) @(posedge clk);
        rst_n <= 1;

        for (integer i = 0; i < 18; i = i + 1) begin
            @(negedge clk);
            valid_in <= 1;
            pixel_in <= i;
            if (!ready_out) begin
                $display("TEST_FAIL tb_line_buffer unexpected backpressure at input %0d", i);
                $fatal;
            end
            @(posedge clk);
            #1;
            if (valid_out && !first_checked) begin
                check_window0();
                first_checked = 1;
                ready_in <= 0;
                #1;
                if (ready_out !== 1'b0) begin
                    $display("TEST_FAIL tb_line_buffer ready_out did not deassert during backpressure");
                    $fatal;
                end
                @(negedge clk);
                ready_in <= 1;
            end
        end

        @(negedge clk);
        valid_in <= 0;
        repeat (5) @(posedge clk);
        if (!first_checked) begin
            $display("TEST_FAIL tb_line_buffer no valid window observed");
            $fatal;
        end
        $display("TEST_PASS tb_line_buffer");
        $finish;
    end
endmodule
