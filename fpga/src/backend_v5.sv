`timescale 1ns / 1ps

// Backend: Conv2 pair-max stream -> direct 12x12 tile max -> FC1 -> FC2.
// The original 2x2 MaxPool followed by 6x6 MaxPool is equivalent to a
// max over each 12x12 quadrant of the 24x24 Conv2 output.
module backend_v5 #(
    parameter DATA_WIDTH = 16
)(
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    output reg ready_out,
    input wire signed [DATA_WIDTH-1:0] pixel_in,

    output wire valid_out,
    output wire [3:0] score_idx,
    output wire signed [DATA_WIDTH-1:0] score_out
);

    reg [5:0] ic_idx;
    reg [3:0] col_idx;
    reg [4:0] row_idx;

    reg signed [15:0] pool2_max [0:255];

    initial begin
        for (integer i = 0; i < 256; i = i + 1) pool2_max[i] = 0;
    end

    reg v_pool_pre;
    reg v_pool_pipelined;
    reg ready_out_reg;
    reg [3:0] out_cnt;
    reg fc_inflight;
    reg finish_pending;

    reg pool_req;
    reg signed [15:0] pool_px;
    reg [7:0] pool_addr;
    reg pool_init;

    wire release_stall = fc_inflight && out_cnt == 10 && v_pool_pre == 0 && v_pool_pipelined == 0;
    wire input_fire = valid_in && ready_out_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ic_idx <= 0;
            col_idx <= 0;
            row_idx <= 0;
            v_pool_pre <= 0;
            ready_out_reg <= 1;
            ready_out <= 1;
            fc_inflight <= 0;
            finish_pending <= 0;
            pool_req <= 0;
            pool_px <= 0;
            pool_addr <= 0;
            pool_init <= 0;
        end else begin
            automatic logic tile_r;
            automatic logic tile_c;

            v_pool_pre <= 0;
            ready_out <= ready_out_reg;

            if (pool_req) begin
                pool2_max[pool_addr] <= (pool_init || pool_px > pool2_max[pool_addr]) ?
                                        pool_px : pool2_max[pool_addr];
            end
            pool_req <= 0;

            if (release_stall) begin
                ready_out_reg <= 1;
                fc_inflight <= 0;
            end

            if (finish_pending && !pool_req) begin
                finish_pending <= 0;
                v_pool_pre <= 1;
                fc_inflight <= 1;
            end

            if (input_fire) begin
                tile_r = (row_idx >= 12);
                tile_c = (col_idx >= 6);

                pool_req <= 1;
                pool_px <= pixel_in;
                pool_addr <= {tile_r, tile_c, ic_idx};
                pool_init <= ((row_idx == 0 || row_idx == 12) &&
                              (col_idx == 0 || col_idx == 6));

                if (ic_idx == 63) begin
                    ic_idx <= 0;
                    if (col_idx == 11) begin
                        col_idx <= 0;
                        if (row_idx == 23) begin
                            row_idx <= 0;
                            ready_out_reg <= 0;
                            finish_pending <= 1;
                        end else begin
                            row_idx <= row_idx + 1;
                        end
                    end else begin
                        col_idx <= col_idx + 1;
                    end
                end else begin
                    ic_idx <= ic_idx + 1;
                end
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) v_pool_pipelined <= 0;
        else v_pool_pipelined <= v_pool_pre;
    end

    wire v_f1;
    wire v_f2;
    wire signed [DATA_WIDTH-1:0] p_f1 [0:127];
    wire signed [DATA_WIDTH-1:0] p_f2 [0:9];
    wire [7:0] fc1_feature_addr;
    wire signed [DATA_WIDTH-1:0] fc1_feature_data = pool2_max[fc1_feature_addr];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_cnt <= 10;
        end else begin
            if (v_f2) out_cnt <= 0;
            else if (out_cnt < 10) out_cnt <= out_cnt + 1;
        end
    end

    fc1_layer #(
        .IN_PIXELS(4)
    ) fc1_inst (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(v_pool_pipelined),
        .feature_addr(fc1_feature_addr),
        .feature_data(fc1_feature_data),
        .valid_out(v_f1),
        .out_pixels(p_f1)
    );

    fc2_layer fc2_inst (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(v_f1),
        .pixel_in(p_f1),
        .valid_out(v_f2),
        .out_pixels(p_f2)
    );

    assign valid_out = (out_cnt < 10);
    assign score_idx = out_cnt;
    assign score_out = (out_cnt < 10) ? p_f2[out_cnt] : '0;

endmodule
