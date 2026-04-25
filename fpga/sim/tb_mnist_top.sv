`timescale 1ns / 1ps

// Zynq-7020 Performance & Accuracy Testbench (v5.4)
module tb_mnist_top;
    parameter DATA_WIDTH = 16;

    reg clk;
    reg rst_n;
    reg valid_in;
    reg signed [DATA_WIDTH-1:0] pixel_in;
    
    wire ready_out;
    wire valid_out;
    wire [3:0] score_idx;
    wire signed [DATA_WIDTH-1:0] score_out;

    // Instantiate Top Module (All weights are internal)
    top_mnist #(DATA_WIDTH) dut (
        .clk(clk), .rst_n(rst_n), .valid_in(valid_in), .ready_out(ready_out),
        .pixel_in(pixel_in), 
        .valid_out(valid_out), .score_idx(score_idx), .score_out(score_out)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz
    end

    // Capture results in a local array
    reg signed [DATA_WIDTH-1:0] hw_scores [0:9];
    always @(posedge clk) begin
        if (valid_out) begin
            hw_scores[score_idx] <= score_out;
        end
    end

    integer img_idx, i;
    longint start_time, end_time;
    longint total_cycles;

    initial begin
        $display("--- Starting Zynq-7020 MNIST Accelerator Verification (v5.4) ---");
        $monitor("[%t] ready_out=%b, valid_out=%b, score_idx=%d, score_out=%h", $time, ready_out, valid_out, score_idx, score_out);
        
        for (img_idx = 0; img_idx < 5; img_idx = img_idx + 1) begin
            reg signed [DATA_WIDTH-1:0] img_mem [0:28*28-1];
            reg signed [DATA_WIDTH-1:0] golden_mem [0:9];
            string img_path, golden_path;
            
            $sformat(img_path, "D:/IC_Workspace/mnist/fpga/data/image_%0d.hex", img_idx);
            $sformat(golden_path, "D:/IC_Workspace/mnist/fpga/data/golden_%0d.hex", img_idx);
            $readmemh(img_path, img_mem);
            $readmemh(golden_path, golden_mem);
            
            // Reset
            rst_n = 0; valid_in = 0; pixel_in = 0;
            #100 rst_n = 1;
            @(posedge clk);
            
            $display("[%t] Testing Image %0d...", $time, img_idx);
            start_time = $time;
            
            // Feed 28x28 Image
            for (i = 0; i < 28*28; i = i + 1) begin
                while (!ready_out) @(posedge clk);
                valid_in <= 1;
                pixel_in <= img_mem[i];
                @(posedge clk);
                valid_in <= 0;
                if (i % 100 == 0) $display("[%t]   Sent %d pixels", $time, i);
            end
            
            // Wait for 10 scores to be collected (score_idx 9)
            wait(valid_out && score_idx == 9);
            @(posedge clk);
            end_time = $time;
            
            // Performance Calculation
            total_cycles = (end_time - start_time) / 10;
            $display("Image %0d Latency: %0d cycles (%0d us @ 100MHz)", img_idx, total_cycles, total_cycles/100);
            
            // Accuracy Check
            begin
                integer hw_max_idx, golden_max_idx;
                integer signed hw_max_val, golden_max_val;
                hw_max_idx = 0; golden_max_idx = 0;
                hw_max_val = hw_scores[0]; golden_max_val = golden_mem[0];
                
                for (integer k=1; k<10; k=k+1) begin
                    if (hw_scores[k] > hw_max_val) begin
                        hw_max_val = hw_scores[k];
                        hw_max_idx = k;
                    end
                    if (golden_mem[k] > golden_max_val) begin
                        golden_max_val = golden_mem[k];
                        golden_max_idx = k;
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
        
        $display("All 5 tests finished successfully.");
        $finish;
    end

endmodule
