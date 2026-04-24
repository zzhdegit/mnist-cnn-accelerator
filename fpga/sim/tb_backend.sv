`timescale 1ns / 1ps

module tb_backend;
    parameter DATA_WIDTH = 16;
    parameter CHANNELS = 64;
    parameter IMG_WIDTH = 24;

    reg clk;
    reg rst_n;
    reg valid_in;
    reg [CHANNELS*DATA_WIDTH-1:0] pixel_in;
    
    wire maxpool_valid_out;
    wire [CHANNELS*DATA_WIDTH-1:0] maxpool_out;
    
    wire fc1_valid_out;
    wire signed [DATA_WIDTH-1:0] fc1_out [0:127];
    
    wire fc2_valid_out;
    wire signed [DATA_WIDTH-1:0] fc2_out [0:9];

    // Instantiate MaxPool
    maxpool2d #(
        .DATA_WIDTH(DATA_WIDTH),
        .CHANNELS(CHANNELS),
        .IMG_WIDTH(IMG_WIDTH)
    ) maxpool_inst (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .pixel_in(pixel_in),
        .valid_out(maxpool_valid_out),
        .pixel_out(maxpool_out)
    );
    
    // FC1 Weights & Biases
    reg signed [DATA_WIDTH-1:0] fc1_weights [0:127][0:9215];
    reg signed [DATA_WIDTH-1:0] fc1_biases [0:127];
    
    // Instantiate FC1
    fc1_layer #(
        .DATA_WIDTH(DATA_WIDTH),
        .IN_CHANNELS(CHANNELS),
        .OUT_CHANNELS(128),
        .IN_PIXELS(144)
    ) fc1_inst (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(maxpool_valid_out),
        .pixel_in(maxpool_out),
        .weights(fc1_weights),
        .biases(fc1_biases),
        .valid_out(fc1_valid_out),
        .out_pixels(fc1_out)
    );

    // FC2 Weights & Biases
    reg signed [DATA_WIDTH-1:0] fc2_weights [0:9][0:127];
    reg signed [DATA_WIDTH-1:0] fc2_biases [0:9];

    // Instantiate FC2
    fc2_layer #(
        .DATA_WIDTH(DATA_WIDTH),
        .IN_CHANNELS(128),
        .OUT_CHANNELS(10)
    ) fc2_inst (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(fc1_valid_out),
        .pixel_in(fc1_out),
        .weights(fc2_weights),
        .biases(fc2_biases),
        .valid_out(fc2_valid_out),
        .out_pixels(fc2_out)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    reg signed [DATA_WIDTH-1:0] conv2_relu_mem [0:CHANNELS*IMG_WIDTH*IMG_WIDTH-1];
    reg signed [DATA_WIDTH-1:0] w_fc1_mem [0:128*9216-1];
    reg signed [DATA_WIDTH-1:0] b_fc1_mem [0:127];
    reg signed [DATA_WIDTH-1:0] w_fc2_mem [0:10*128-1];
    reg signed [DATA_WIDTH-1:0] b_fc2_mem [0:9];
    reg signed [DATA_WIDTH-1:0] fc2_golden [0:9];

    integer oc, px, ch;
    integer v_in_cnt = 0;
    integer mp_out_cnt = 0;
    integer fc1_out_cnt = 0;

    initial begin
        $readmemh("D:/IC_Workspace/mnist/fpga/data/conv2_relu_golden.hex", conv2_relu_mem);
        $readmemh("D:/IC_Workspace/mnist/fpga/data/fc1_w.hex", w_fc1_mem);
        $readmemh("D:/IC_Workspace/mnist/fpga/data/fc1_b.hex", b_fc1_mem);
        $readmemh("D:/IC_Workspace/mnist/fpga/data/fc2_w.hex", w_fc2_mem);
        $readmemh("D:/IC_Workspace/mnist/fpga/data/fc2_b.hex", b_fc2_mem);
        $readmemh("D:/IC_Workspace/mnist/fpga/data/fc2_out_golden.hex", fc2_golden);
        
        for (oc = 0; oc < 128; oc = oc + 1) begin
            fc1_biases[oc] = b_fc1_mem[oc];
            for (px = 0; px < 144; px = px + 1) begin
                for (ch = 0; ch < 64; ch = ch + 1) begin
                    fc1_weights[oc][px*64 + ch] = w_fc1_mem[oc*9216 + ch*144 + px];
                end
            end
        end
        
        for (oc = 0; oc < 10; oc = oc + 1) begin
            fc2_biases[oc] = b_fc2_mem[oc];
            for (integer ic = 0; ic < 128; ic = ic + 1) begin
                fc2_weights[oc][ic] = w_fc2_mem[oc*128 + ic];
            end
        end

        rst_n = 0;
        valid_in = 0;
        pixel_in = 0;
        #50 rst_n = 1;
        
        $display("[%t] Starting streaming Conv2 data...", $time);
        for (integer i = 0; i < IMG_WIDTH*IMG_WIDTH; i = i + 1) begin
            reg [CHANNELS*DATA_WIDTH-1:0] temp_v;
            for (integer c = 0; c < CHANNELS; c = c + 1) begin
                temp_v[c*DATA_WIDTH +: DATA_WIDTH] = conv2_relu_mem[i * CHANNELS + c];
            end
            @(posedge clk);
            valid_in <= 1;
            pixel_in <= temp_v;
            v_in_cnt = v_in_cnt + 1;
        end
        
        @(posedge clk);
        valid_in <= 0;
        
        $display("[%t] Stream finished. Sent %d pixels. Waiting for results...", $time, v_in_cnt);
        
        // Timeout protection
        fork
            begin
                wait(fc2_valid_out);
                @(posedge clk);
                $display("[%t] SUCCESS: FC2 output captured!", $time);
            end
            begin
                #20000;
                $display("[%t] ERROR: Simulation Timeout! Backend stalled.", $time);
            end
        join_any
        
        $display("\n========================================");
        $display("Inference Summary:");
        $display("Input Pixels: %d (Expected 576)", v_in_cnt);
        $display("MaxPool Pixels: %d (Expected 144)", mp_out_cnt);
        $display("FC1 Results: %d (Expected 1)", fc1_out_cnt);
        
        if (fc2_valid_out) begin
            $display("\nFinal Classification Results:");
            for (oc = 0; oc < 10; oc = oc + 1) begin
                $display("Class %0d: HW=%h, Golden=%h", oc, fc2_out[oc], fc2_golden[oc]);
            end
        end
        $display("========================================\n");
        $finish;
    end

    // Monitor signals
    always @(posedge clk) begin
        if (maxpool_valid_out) mp_out_cnt <= mp_out_cnt + 1;
        if (fc1_valid_out) fc1_out_cnt <= fc1_out_cnt + 1;
    end

endmodule