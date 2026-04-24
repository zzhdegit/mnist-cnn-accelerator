`timescale 1ns / 1ps

module tb_conv2;
    parameter DATA_WIDTH = 16;
    parameter IN_CHANNELS = 32;
    parameter OUT_CHANNELS = 64;
    parameter IMG_WIDTH = 26;

    reg clk;
    reg rst_n;
    reg valid_in;
    reg [IN_CHANNELS*DATA_WIDTH-1:0] pixel_in;
    reg [IN_CHANNELS*DATA_WIDTH-1:0] temp_pixel;
    
    wire valid_out;
    wire signed [DATA_WIDTH-1:0] out_pixels [0:OUT_CHANNELS-1];
    
    reg signed [DATA_WIDTH-1:0] in_mem [0:IN_CHANNELS*IMG_WIDTH*IMG_WIDTH-1];
    reg signed [DATA_WIDTH-1:0] w_mem [0:OUT_CHANNELS*IN_CHANNELS*9-1];
    reg signed [DATA_WIDTH-1:0] b_mem [0:OUT_CHANNELS-1];
    reg signed [DATA_WIDTH-1:0] golden_mem [0:OUT_CHANNELS*24*24-1];
    
    reg signed [DATA_WIDTH-1:0] weights [0:OUT_CHANNELS-1][0:IN_CHANNELS-1][0:8];
    reg signed [DATA_WIDTH-1:0] biases [0:OUT_CHANNELS-1];

    conv2_layer #(
        .DATA_WIDTH(DATA_WIDTH),
        .IN_CHANNELS(IN_CHANNELS),
        .OUT_CHANNELS(OUT_CHANNELS),
        .IMG_WIDTH(IMG_WIDTH)
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

    integer i, j, c, oc, ic, row, col;
    integer errors = 0;
    integer out_count = 0;

    initial begin
        $readmemh("D:/IC_Workspace/mnist/fpga/data/conv1_relu_golden.hex", in_mem);
        $readmemh("D:/IC_Workspace/mnist/fpga/data/conv2_w.hex", w_mem);
        $readmemh("D:/IC_Workspace/mnist/fpga/data/conv2_b.hex", b_mem);
        $readmemh("D:/IC_Workspace/mnist/fpga/data/conv2_out_golden.hex", golden_mem);
        
        for (oc = 0; oc < OUT_CHANNELS; oc = oc + 1) begin
            biases[oc] = b_mem[oc];
            for (ic = 0; ic < IN_CHANNELS; ic = ic + 1) begin
                for (j = 0; j < 9; j = j + 1) begin
                    weights[oc][ic][j] = w_mem[oc*IN_CHANNELS*9 + ic*9 + j];
                end
            end
        end

        rst_n = 0;
        valid_in = 0;
        pixel_in = 0;
        
        #20 rst_n = 1;
        

        for (i = 0; i < IMG_WIDTH*IMG_WIDTH; i = i + 1) begin
            for (c = 0; c < IN_CHANNELS; c = c + 1) begin
                temp_pixel[c*DATA_WIDTH +: DATA_WIDTH] = in_mem[i * IN_CHANNELS + c];
            end
            @(posedge clk);
            valid_in <= 1;
            pixel_in <= temp_pixel;
        end
        
        @(posedge clk);
        valid_in <= 0;
        
        #200;
        
        if (errors == 0 && out_count == 24*24) begin
            $display("========================================");
            $display("SUCCESS: Conv2 Simulation Passed! Fully Bit-Accurate!");
            $display("Processed 1 relu_map (32x26x26) to Output Feature Map (64x24x24)");
            $display("========================================");
        end else begin
            $display("========================================");
            $display("FAILED: Errors = %d, Valid Outputs Count = %d / %d", errors, out_count, 24*24);
            $display("========================================");
        end
        $finish;
    end

    integer error_print_cnt = 0;
    always @(posedge clk) begin
        if (valid_out) begin
            for (c = 0; c < OUT_CHANNELS; c = c + 1) begin
                if (out_pixels[c] !== golden_mem[out_count * OUT_CHANNELS + c]) begin
                    if (error_print_cnt < 10) begin
                        $display("Mismatch at OutPixel[%d] Channel[%d]: HW=%h, Golden=%h", out_count, c, out_pixels[c], golden_mem[out_count * OUT_CHANNELS + c]);
                        error_print_cnt = error_print_cnt + 1;
                    end
                    errors = errors + 1;
                end
            end
            out_count = out_count + 1;
        end
    end

endmodule