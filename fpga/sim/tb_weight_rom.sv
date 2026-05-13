`timescale 1ns / 1ps

module tb_weight_rom;
    reg clk = 0;
    reg [1:0] addr = 0;
    wire signed [15:0] data_out;

    always #5 clk = ~clk;

    weight_rom #(
        .DEPTH(4),
        .DATA_FILE("D:/IC_Workspace/mnist/fpga/sim/data/weight_rom_small.hex"),
        .ADDR_WIDTH(2)
    ) dut (
        .clk(clk),
        .addr(addr),
        .data_out(data_out)
    );

    task check_value(input signed [15:0] got, input signed [15:0] exp, input string what);
        begin
            if (got !== exp) begin
                $display("TEST_FAIL tb_weight_rom %s got=%h exp=%h", what, got, exp);
                $fatal;
            end
        end
    endtask

    initial begin
        repeat (2) @(posedge clk);
        addr <= 2'd0; @(posedge clk); @(posedge clk); #1; check_value(data_out, 16'h0011, "addr0");
        addr <= 2'd1; @(posedge clk); @(posedge clk); #1; check_value(data_out, 16'h0022, "addr1");
        addr <= 2'd2; @(posedge clk); @(posedge clk); #1; check_value(data_out, 16'hffee, "addr2");
        addr <= 2'd3; @(posedge clk); @(posedge clk); #1; check_value(data_out, 16'h0044, "addr3");
        $display("TEST_PASS tb_weight_rom");
        $finish;
    end
endmodule
