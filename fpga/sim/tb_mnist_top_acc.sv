`timescale 1ns / 1ps

module tb_mnist_top_acc;
    parameter DATA_WIDTH = 16;
    parameter N_IMAGES = 30;
    parameter MAX_IMAGES = 1000;
    parameter MAX_WAIT_CYCLES = 2000000;

    reg clk;
    reg rst_n;
    reg valid_in;
    reg signed [DATA_WIDTH-1:0] pixel_in;

    wire ready_out;
    wire valid_out;
    wire [3:0] score_idx;
    wire signed [DATA_WIDTH-1:0] score_out;

    top_mnist #(DATA_WIDTH) dut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .ready_out(ready_out),
        .pixel_in(pixel_in),
        .valid_out(valid_out),
        .score_idx(score_idx),
        .score_out(score_out)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    reg signed [DATA_WIDTH-1:0] hw_scores [0:9];
    integer out_count;
    always @(posedge clk) begin
        if (!rst_n) begin
            out_count <= 0;
        end else if (valid_out && score_idx < 10) begin
            hw_scores[score_idx] <= score_out;
            out_count <= out_count + 1;
        end
    end

    function automatic integer argmax10(input reg signed [DATA_WIDTH-1:0] values [0:9]);
        integer k;
        integer best_idx;
        reg signed [DATA_WIDTH-1:0] best_val;
        begin
            best_idx = 0;
            best_val = values[0];
            for (k = 1; k < 10; k = k + 1) begin
                if (values[k] > best_val) begin
                    best_val = values[k];
                    best_idx = k;
                end
            end
            argmax10 = best_idx;
        end
    endfunction

    integer img_idx;
    integer px_idx;
    integer wait_cycles;
    integer hw_pred;
    integer golden_pred;
    integer hw_correct;
    integer golden_correct;
    integer golden_match;
    integer total_cycles;
    integer start_cycle;
    integer end_cycle;
    integer cycle_count;
    reg signed [DATA_WIDTH-1:0] img_mem [0:28*28-1];
    reg signed [DATA_WIDTH-1:0] golden_scores [0:9];
    integer n_images;
    reg [3:0] labels [0:MAX_IMAGES-1];
    string img_path;
    string golden_path;
    string label_path;
    string data_dir;

    initial begin
        data_dir = "D:/IC_Workspace/mnist/fpga/data";
        if ($value$plusargs("DATA_DIR=%s", data_dir)) begin
            data_dir = data_dir;
        end
        n_images = N_IMAGES;
        if ($value$plusargs("N_IMAGES=%d", n_images)) begin
            n_images = n_images;
        end
        if (n_images > MAX_IMAGES) begin
            $display("ACCURACY_CONFIG_ERROR n_images=%0d exceeds MAX_IMAGES=%0d", n_images, MAX_IMAGES);
            $finish;
        end
        if (!$value$plusargs("LABEL_FILE=%s", label_path)) begin
            $sformat(label_path, "%s/labels_%0d.hex", data_dir, n_images);
        end
        $readmemh(label_path, labels);

        hw_correct = 0;
        golden_correct = 0;
        golden_match = 0;
        total_cycles = 0;
        cycle_count = 0;
        valid_in = 0;
        pixel_in = 0;
        rst_n = 0;

        repeat (10) @(posedge clk);

        for (img_idx = 0; img_idx < n_images; img_idx = img_idx + 1) begin
            $sformat(img_path, "%s/image_%0d.hex", data_dir, img_idx);
            $sformat(golden_path, "%s/golden_%0d.hex", data_dir, img_idx);
            $readmemh(img_path, img_mem);
            $readmemh(golden_path, golden_scores);

            rst_n = 0;
            valid_in = 0;
            pixel_in = 0;
            out_count = 0;
            for (integer s = 0; s < 10; s = s + 1) hw_scores[s] = 0;
            repeat (10) @(posedge clk);
            rst_n = 1;
            @(posedge clk);

            start_cycle = cycle_count;
            for (px_idx = 0; px_idx < 28*28; px_idx = px_idx + 1) begin
                valid_in = 1;
                pixel_in = img_mem[px_idx];
                do begin
                    @(posedge clk);
                end while (ready_out !== 1'b1);
            end
            valid_in = 0;

            wait_cycles = 0;
            while (out_count < 10 && wait_cycles < MAX_WAIT_CYCLES) begin
                @(posedge clk);
                wait_cycles = wait_cycles + 1;
            end
            if (out_count < 10) begin
                $display("ACCURACY_TIMEOUT image=%0d out_count=%0d", img_idx, out_count);
                $finish;
            end

            end_cycle = cycle_count;
            total_cycles = total_cycles + (end_cycle - start_cycle);
            hw_pred = argmax10(hw_scores);
            golden_pred = argmax10(golden_scores);

            if (hw_pred == labels[img_idx]) hw_correct = hw_correct + 1;
            if (golden_pred == labels[img_idx]) golden_correct = golden_correct + 1;
            if (hw_pred == golden_pred) golden_match = golden_match + 1;

            $display("ACCURACY_IMAGE idx=%0d label=%0d hw=%0d golden=%0d cycles=%0d",
                     img_idx, labels[img_idx], hw_pred, golden_pred, end_cycle - start_cycle);
            if (hw_pred != golden_pred) begin
                $write("  HW_SCORES");
                for (integer hs = 0; hs < 10; hs = hs + 1) $write(" %0d", $signed(hw_scores[hs]));
                $write("\n  GOLDEN_SCORES");
                for (integer gs = 0; gs < 10; gs = gs + 1) $write(" %0d", $signed(golden_scores[gs]));
                $write("\n");
            end
            repeat (20) @(posedge clk);
        end

        $display("ACCURACY_SUMMARY images=%0d hw_correct=%0d hw_acc_pct=%0d golden_correct=%0d golden_acc_pct=%0d golden_match=%0d match_pct=%0d avg_cycles=%0d",
                 n_images,
                 hw_correct,
                 (hw_correct * 100) / n_images,
                 golden_correct,
                 (golden_correct * 100) / n_images,
                 golden_match,
                 (golden_match * 100) / n_images,
                 total_cycles / n_images);
        $finish;
    end

    always @(posedge clk) begin
        if (rst_n) cycle_count <= cycle_count + 1;
        else cycle_count <= 0;
    end
endmodule
