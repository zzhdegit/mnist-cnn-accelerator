`timescale 1ns / 1ps

module tb_conv1;
    parameter DATA_WIDTH = 16;
    parameter IMG_WIDTH = 28;
    parameter OUT_CHANNELS = 32;

    reg clk;
    reg rst_n;
    reg valid_in;
    reg signed [DATA_WIDTH-1:0] pixel_in;
    
    wire valid_out;
    wire signed [DATA_WIDTH-1:0] out_pixels [0:OUT_CHANNELS-1];
    
    reg signed [DATA_WIDTH-1:0] image_mem [0:28*28-1];
    reg signed [DATA_WIDTH-1:0] w_mem [0:32*9-1];
    reg signed [DATA_WIDTH-1:0] b_mem [0:31];
    reg signed [DATA_WIDTH-1:0] golden_mem [0:32*26*26-1];
    
    reg signed [DATA_WIDTH-1:0] weights [0:OUT_CHANNELS-1][0:8];
    reg signed [DATA_WIDTH-1:0] biases [0:OUT_CHANNELS-1];

    conv1_layer #(
        .DATA_WIDTH(DATA_WIDTH),
        .IMG_WIDTH(IMG_WIDTH),
        .OUT_CHANNELS(OUT_CHANNELS)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .pixel_in(pixel_in),
        .weights(weights),
        .biases(biases),
        .valid_out(valid_out),
        .out_pixels(out_pixels)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    integer i, j, c;
    integer errors = 0;
    integer out_count = 0;

    initial begin
        $readmemh("D:/IC_Workspace/mnist/fpga/data/image.hex", image_mem);
        $readmemh("D:/IC_Workspace/mnist/fpga/data/conv1_w.hex", w_mem);
        $readmemh("D:/IC_Workspace/mnist/fpga/data/conv1_b.hex", b_mem);
        $readmemh("D:/IC_Workspace/mnist/fpga/data/conv1_out_golden.hex", golden_mem);
        
        for (c = 0; c < OUT_CHANNELS; c = c + 1) begin
            biases[c] = b_mem[c];
            for (j = 0; j < 9; j = j + 1) begin
                weights[c][j] = w_mem[c*9 + j];
            end
        end

        rst_n = 0;
        valid_in = 0;
        pixel_in = 0;
        
        #20 rst_n = 1;
        
        for (i = 0; i < 28*28; i = i + 1) begin
            @(posedge clk);
            valid_in <= 1;
            pixel_in <= image_mem[i];
        end
        
        @(posedge clk);
        valid_in <= 0;
        
        #200;
        
        if (errors == 0 && out_count == 26*26) begin
            $display("========================================");
            $display("SUCCESS: Conv1 Simulation Passed! Fully Bit-Accurate!");
            $display("Processed 1 image (28x28) to Output Feature Map (32x26x26)");
            $display("========================================");
        end else begin
            $display("========================================");
            $display("FAILED: Errors = %d, Valid Outputs Count = %d / %d", errors, out_count, 26*26);
            $display("========================================");
        end
        $finish;
    end

    integer error_print_cnt = 0;
    always @(posedge clk) begin
        if (valid_out) begin
            for (c = 0; c < OUT_CHANNELS; c = c + 1) begin
                if (out_pixels[c] !== golden_mem[out_count * 32 + c]) begin
                    if (error_print_cnt < 10) begin
                        $display("Mismatch at OutPixel[%d] Channel[%d]: HW=%h, Golden=%h", out_count, c, out_pixels[c], golden_mem[out_count * 32 + c]);
                        error_print_cnt = error_print_cnt + 1;
                    end
                    errors = errors + 1;
                end
            end
            out_count = out_count + 1;
        end
    end

endmodule