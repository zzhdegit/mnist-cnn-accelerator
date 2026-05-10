`timescale 1ns / 1ps

module fc1_layer #(
    parameter DATA_WIDTH = 16,
    parameter IN_CHANNELS = 64,
    parameter OUT_CHANNELS = 128,
    parameter IN_PIXELS = 4,
    parameter W_FILE = "D:/IC_Workspace/mnist/fpga/data/fc1_w.hex",
    parameter B_FILE = "D:/IC_Workspace/mnist/fpga/data/fc1_b.hex"
)(
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    output wire [$clog2(IN_CHANNELS*IN_PIXELS)-1:0] feature_addr,
    input wire signed [DATA_WIDTH-1:0] feature_data,

    output reg valid_out,
    output reg signed [DATA_WIDTH-1:0] out_pixels [0:OUT_CHANNELS-1]
);

    localparam TOTAL_INPUTS = IN_CHANNELS * IN_PIXELS;
    localparam TOTAL_WEIGHTS = OUT_CHANNELS * TOTAL_INPUTS;
    localparam W_ADDR_WIDTH = (TOTAL_WEIGHTS <= 1) ? 1 : $clog2(TOTAL_WEIGHTS);
    localparam ISSUE_WIDTH = $clog2(TOTAL_INPUTS + 3);

    wire signed [DATA_WIDTH-1:0] rom_w_out;
    reg [W_ADDR_WIDTH-1:0] w_addr;
    weight_rom #(
        .DEPTH(TOTAL_WEIGHTS),
        .DATA_FILE(W_FILE),
        .ADDR_WIDTH(W_ADDR_WIDTH)
    ) w_rom_inst (
        .clk(clk),
        .addr(w_addr),
        .data_out(rom_w_out)
    );

    (* ram_style = "distributed" *) reg signed [DATA_WIDTH-1:0] b_mem [0:OUT_CHANNELS-1];
    initial $readmemh(B_FILE, b_mem);

    typedef enum logic [1:0] {IDLE, RUN, STORE, FINISH} state_t;
    state_t state;

    reg [$clog2(OUT_CHANNELS)-1:0] oc_idx;
    reg [ISSUE_WIDTH-1:0] issue_count;
    reg [ISSUE_WIDTH-1:0] mac_count;
    reg signed [39:0] acc;
    reg signed [DATA_WIDTH-1:0] px_d0;
    reg signed [DATA_WIDTH-1:0] px_d1;
    reg signed [DATA_WIDTH-1:0] px_d2;
    assign feature_addr = (issue_count < TOTAL_INPUTS) ? issue_count[$clog2(TOTAL_INPUTS)-1:0] : '0;

    function automatic signed [DATA_WIDTH-1:0] sat_relu(input signed [39:0] value);
        begin
            if ((value >>> 8) > 32767) sat_relu = 16'sh7fff;
            else if ((value >>> 8) < 0) sat_relu = 16'sh0000;
            else sat_relu = value[23:8];
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            oc_idx <= 0;
            issue_count <= 0;
            mac_count <= 0;
            valid_out <= 0;
            w_addr <= 0;
            acc <= 0;
            px_d0 <= 0;
            px_d1 <= 0;
            px_d2 <= 0;
            for (integer i = 0; i < OUT_CHANNELS; i = i + 1) out_pixels[i] <= 0;
        end else begin
            case (state)
                IDLE: begin
                    valid_out <= 0;
                    if (valid_in) begin
                        state <= RUN;
                        oc_idx <= 0;
                        issue_count <= 0;
                        mac_count <= 0;
                        acc <= (b_mem[0] <<< 8);
                        w_addr <= 0;
                        px_d0 <= 0;
                        px_d1 <= 0;
                        px_d2 <= 0;
                    end
                end

                RUN: begin
                    automatic logic signed [39:0] next_acc;
                    next_acc = acc;

                    if (issue_count >= 3 && mac_count < TOTAL_INPUTS) begin
                        next_acc = acc + ($signed(px_d2) * $signed(rom_w_out));
                        acc <= next_acc;
                        mac_count <= mac_count + 1;
                        if (mac_count == TOTAL_INPUTS - 1) begin
                            out_pixels[oc_idx] <= sat_relu(next_acc);
                            state <= STORE;
                        end
                    end

                    if (issue_count < TOTAL_INPUTS) begin
                        automatic logic [W_ADDR_WIDTH-1:0] issue_addr;
                        issue_addr = (oc_idx * TOTAL_INPUTS) + issue_count;
                        w_addr <= issue_addr;
                        px_d0 <= feature_data;
                    end else begin
                        px_d0 <= 0;
                    end
                    px_d2 <= px_d1;
                    px_d1 <= px_d0;
                    if (issue_count < TOTAL_INPUTS + 3) issue_count <= issue_count + 1;
                end

                STORE: begin
                    if (oc_idx == OUT_CHANNELS - 1) begin
                        state <= FINISH;
                    end else begin
                        oc_idx <= oc_idx + 1;
                        issue_count <= 0;
                        mac_count <= 0;
                        acc <= (b_mem[oc_idx + 1] <<< 8);
                        px_d0 <= 0;
                        px_d1 <= 0;
                        px_d2 <= 0;
                        state <= RUN;
                    end
                end

                FINISH: begin
                    valid_out <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule
