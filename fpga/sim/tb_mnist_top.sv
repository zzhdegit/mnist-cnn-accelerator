`timescale 1ns / 1ps

module tb_mnist_top;
    parameter DATA_WIDTH = 16;

    reg clk;
    reg rst_n;
    reg valid_in;
    reg signed [DATA_WIDTH-1:0] pixel_in;
    
    // Conv Weights and Biases memory (Still passed via ports as they are small)
    reg signed [DATA_WIDTH-1:0] w_c1 [0:31][0:8];
    reg signed [DATA_WIDTH-1:0] b_c1 [0:31];
    reg signed [DATA_WIDTH-1:0] w_c2 [0:63][0:31][0:8];
    reg signed [DATA_WIDTH-1:0] b_c2 [0:63];

    wire valid_out;
    wire signed [DATA_WIDTH-1:0] out_pixels [0:9];

    // Instantiate Top Module - UPDATED: FC weights are now internal
    top_mnist #(DATA_WIDTH) dut (
        .clk(clk), .rst_n(rst_n), .valid_in(valid_in), .pixel_in(pixel_in),
        .w_c1(w_c1), .b_c1(b_c1), .w_c2(w_c2), .b_c2(b_c2),
        .valid_out(valid_out), .out_scores(out_pixels)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Simulation Progress Monitor
    initial begin
        forever begin
            #100000;
            $display("[%t] Simulation still running...", $time);
        end
    end

    // Load Weights once
    reg signed [DATA_WIDTH-1:0] tmp_mem [0:100000]; 
    integer oc, ic, row, col, i, img_idx;

    initial begin
        // 1. Load All Weights (Conv layers only)
        $readmemh("D:/IC_Workspace/mnist/fpga/data/conv1_w.hex", tmp_mem);
        for (oc=0; oc<32; oc=oc+1) for (i=0; i<9; i=i+1) w_c1[oc][i] = tmp_mem[oc*9+i];
        $readmemh("D:/IC_Workspace/mnist/fpga/data/conv1_b.hex", b_c1);
        
        $readmemh("D:/IC_Workspace/mnist/fpga/data/conv2_w.hex", tmp_mem);
        for (oc=0; oc<64; oc=oc+1) for (ic=0; ic<32; ic=ic+1) for (i=0; i<9; i=i+1) w_c2[oc][ic][i] = tmp_mem[oc*32*9 + ic*9 + i];
        $readmemh("D:/IC_Workspace/mnist/fpga/data/conv2_b.hex", b_c2);

        // 2. Loop through 5 images
        for (img_idx = 0; img_idx < 5; img_idx = img_idx + 1) begin
            reg signed [DATA_WIDTH-1:0] img_mem [0:28*28-1];
            reg signed [DATA_WIDTH-1:0] golden_mem [0:9];
            string img_path, golden_path;
            
            $sformat(img_path, "D:/IC_Workspace/mnist/fpga/data/image_%0d.hex", img_idx);
            $sformat(golden_path, "D:/IC_Workspace/mnist/fpga/data/golden_%0d.hex", img_idx);
            $readmemh(img_path, img_mem);
            $readmemh(golden_path, golden_mem);
            
            rst_n = 0;
            valid_in = 0;
            pixel_in = 0;
            #100 rst_n = 1;
            
            $display("[%t] Testing Image %0d...", $time, img_idx);
            for (i = 0; i < 28*28; i = i + 1) begin
                integer timeout_cnt;
                timeout_cnt = 0;
                while (!dut.ready_out) begin
                    @(posedge clk);
                    valid_in <= 0; // Ensure valid is low while waiting
                    timeout_cnt = timeout_cnt + 1;
                    if (timeout_cnt > 2000) begin
                        $display("[%t] ERROR: Testbench timeout waiting for ready_out at pixel %d", $time, i);
                        $finish;
                    end
                end
                valid_in <= 1;
                pixel_in <= img_mem[i];
                @(posedge clk);
                valid_in <= 0; // Immediate pull down after one clock
            end
            @(posedge clk);
            valid_in <= 0;
            
            wait(valid_out);
            @(posedge clk);
            
            $display("--- Result for Image %0d ---", img_idx);
            for (oc = 0; oc < 10; oc = oc + 1) begin
                $display("Class %0d: HW=%h, Golden=%h", oc, out_pixels[oc], golden_mem[oc]);
            end
            
            // Basic accuracy check: max score index
            begin
                integer hw_max_idx, golden_max_idx;
                integer signed hw_max_val, golden_max_val;
                hw_max_idx = 0; golden_max_idx = 0;
                hw_max_val = out_pixels[0]; golden_max_val = golden_mem[0];
                for (oc=1; oc<10; oc=oc+1) begin
                    if (out_pixels[oc] > hw_max_val) begin
                        hw_max_val = out_pixels[oc];
                        hw_max_idx = oc;
                    end
                    if (golden_mem[oc] > golden_max_val) begin
                        golden_max_val = golden_mem[oc];
                        golden_max_idx = oc;
                    end
                end
                if (hw_max_idx == golden_max_idx)
                    $display(">>> SUCCESS: Image %0d correctly identified as %0d", img_idx, hw_max_idx);
                else
                    $display(">>> FAILED: Image %0d misidentified (HW=%0d, Golden=%0d)", img_idx, hw_max_idx, golden_max_idx);
            end
            $display("---------------------------\n");
            #1000;
        end
        
        $display("All tests finished.");
        $finish;
    end

endmodule
