`timescale 1ns / 1ps

// Zynq-7020 Conv2 (v8.4 - Synchronous 32-MAC Pipelined)
module conv2_layer_v5 #(
    parameter DATA_WIDTH = 16,
    parameter IN_CHANNELS = 32,
    parameter OUT_CHANNELS = 64,
    parameter IMG_WIDTH = 26
)(
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    output wire ready_out,
    input wire signed [DATA_WIDTH-1:0] pixel_in,
    
    output reg valid_out,
    input wire ready_in,
    output reg signed [DATA_WIDTH-1:0] pixel_out
);

    reg signed [DATA_WIDTH-1:0] b_mem_all [0:63];
    
    // One initialized ROM per parallel output channel.  Each bank stores two
    // output-channel groups: group 0 => oc 0..31, group 1 => oc 32..63.
    (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] w_rom_0 [0:575];
    (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] w_rom_1 [0:575];
    (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] w_rom_2 [0:575];
    (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] w_rom_3 [0:575];
    (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] w_rom_4 [0:575];
    (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] w_rom_5 [0:575];
    (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] w_rom_6 [0:575];
    (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] w_rom_7 [0:575];
    (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] w_rom_8 [0:575];
    (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] w_rom_9 [0:575];
    (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] w_rom_10 [0:575];
    (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] w_rom_11 [0:575];
    (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] w_rom_12 [0:575];
    (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] w_rom_13 [0:575];
    (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] w_rom_14 [0:575];
    (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] w_rom_15 [0:575];
    (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] w_rom_16 [0:575];
    (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] w_rom_17 [0:575];
    (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] w_rom_18 [0:575];
    (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] w_rom_19 [0:575];
    (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] w_rom_20 [0:575];
    (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] w_rom_21 [0:575];
    (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] w_rom_22 [0:575];
    (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] w_rom_23 [0:575];
    (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] w_rom_24 [0:575];
    (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] w_rom_25 [0:575];
    (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] w_rom_26 [0:575];
    (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] w_rom_27 [0:575];
    (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] w_rom_28 [0:575];
    (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] w_rom_29 [0:575];
    (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] w_rom_30 [0:575];
    (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] w_rom_31 [0:575];

    initial begin
        $readmemh("D:/IC_Workspace/mnist/fpga/data/conv2_b.hex", b_mem_all);
        $readmemh("D:/IC_Workspace/mnist/fpga/data/conv2_w_bank0.hex", w_rom_0);
        $readmemh("D:/IC_Workspace/mnist/fpga/data/conv2_w_bank1.hex", w_rom_1);
        $readmemh("D:/IC_Workspace/mnist/fpga/data/conv2_w_bank2.hex", w_rom_2);
        $readmemh("D:/IC_Workspace/mnist/fpga/data/conv2_w_bank3.hex", w_rom_3);
        $readmemh("D:/IC_Workspace/mnist/fpga/data/conv2_w_bank4.hex", w_rom_4);
        $readmemh("D:/IC_Workspace/mnist/fpga/data/conv2_w_bank5.hex", w_rom_5);
        $readmemh("D:/IC_Workspace/mnist/fpga/data/conv2_w_bank6.hex", w_rom_6);
        $readmemh("D:/IC_Workspace/mnist/fpga/data/conv2_w_bank7.hex", w_rom_7);
        $readmemh("D:/IC_Workspace/mnist/fpga/data/conv2_w_bank8.hex", w_rom_8);
        $readmemh("D:/IC_Workspace/mnist/fpga/data/conv2_w_bank9.hex", w_rom_9);
        $readmemh("D:/IC_Workspace/mnist/fpga/data/conv2_w_bank10.hex", w_rom_10);
        $readmemh("D:/IC_Workspace/mnist/fpga/data/conv2_w_bank11.hex", w_rom_11);
        $readmemh("D:/IC_Workspace/mnist/fpga/data/conv2_w_bank12.hex", w_rom_12);
        $readmemh("D:/IC_Workspace/mnist/fpga/data/conv2_w_bank13.hex", w_rom_13);
        $readmemh("D:/IC_Workspace/mnist/fpga/data/conv2_w_bank14.hex", w_rom_14);
        $readmemh("D:/IC_Workspace/mnist/fpga/data/conv2_w_bank15.hex", w_rom_15);
        $readmemh("D:/IC_Workspace/mnist/fpga/data/conv2_w_bank16.hex", w_rom_16);
        $readmemh("D:/IC_Workspace/mnist/fpga/data/conv2_w_bank17.hex", w_rom_17);
        $readmemh("D:/IC_Workspace/mnist/fpga/data/conv2_w_bank18.hex", w_rom_18);
        $readmemh("D:/IC_Workspace/mnist/fpga/data/conv2_w_bank19.hex", w_rom_19);
        $readmemh("D:/IC_Workspace/mnist/fpga/data/conv2_w_bank20.hex", w_rom_20);
        $readmemh("D:/IC_Workspace/mnist/fpga/data/conv2_w_bank21.hex", w_rom_21);
        $readmemh("D:/IC_Workspace/mnist/fpga/data/conv2_w_bank22.hex", w_rom_22);
        $readmemh("D:/IC_Workspace/mnist/fpga/data/conv2_w_bank23.hex", w_rom_23);
        $readmemh("D:/IC_Workspace/mnist/fpga/data/conv2_w_bank24.hex", w_rom_24);
        $readmemh("D:/IC_Workspace/mnist/fpga/data/conv2_w_bank25.hex", w_rom_25);
        $readmemh("D:/IC_Workspace/mnist/fpga/data/conv2_w_bank26.hex", w_rom_26);
        $readmemh("D:/IC_Workspace/mnist/fpga/data/conv2_w_bank27.hex", w_rom_27);
        $readmemh("D:/IC_Workspace/mnist/fpga/data/conv2_w_bank28.hex", w_rom_28);
        $readmemh("D:/IC_Workspace/mnist/fpga/data/conv2_w_bank29.hex", w_rom_29);
        $readmemh("D:/IC_Workspace/mnist/fpga/data/conv2_w_bank30.hex", w_rom_30);
        $readmemh("D:/IC_Workspace/mnist/fpga/data/conv2_w_bank31.hex", w_rom_31);
    end

    wire lb_ready_internal;
    assign ready_out = lb_ready_internal;

    reg signed [DATA_WIDTH-1:0] lb_in_array [0:31];
    reg [5:0] ic_fill_cnt;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ic_fill_cnt <= 0;
            for(integer i=0; i<32; i++) lb_in_array[i] <= 0;
        end else if (valid_in && ready_out) begin
            lb_in_array[ic_fill_cnt[4:0]] <= pixel_in;
            if (ic_fill_cnt == 31) ic_fill_cnt <= 0;
            else ic_fill_cnt <= ic_fill_cnt + 1;
        end
    end

    wire [511:0] lb_pixel_in;
    genvar pack_i;
    generate
        for (pack_i=0; pack_i<32; pack_i=pack_i+1) assign lb_pixel_in[pack_i*16 +: 16] = lb_in_array[pack_i];
    endgenerate

    wire lb_valid_in_pulse = (valid_in && ready_out && ic_fill_cnt == 31);
    wire signed [511:0] lb_out [0:8];
    wire lb_valid;

    typedef enum {IDLE, COMPUTE, WAIT_PIPE, SERIAL_OUT} state_t;
    state_t state;
    
    reg batch_idx; reg [5:0] ic_idx; reg [3:0] k_idx; reg [5:0] serial_oc;
    wire lb_ready = (state == SERIAL_OUT && serial_oc == 63 && valid_out && ready_in);

    line_buffer #(512, 26) lb_inst (
        .clk(clk), .rst_n(rst_n), .valid_in(lb_valid_in_pulse), .ready_out(lb_ready_internal),
        .pixel_in(lb_pixel_in), .valid_out(lb_valid), .ready_in(lb_ready),
        .pixel_out(lb_out)
    );

    reg signed [39:0] acc [0:31];
    reg signed [DATA_WIDTH-1:0] results [0:63];
    reg signed [15:0] w_read [0:31];
    reg signed [15:0] px_read;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE; batch_idx <= 0; ic_idx <= 0; k_idx <= 0;
            valid_out <= 0; pixel_out <= 0; serial_oc <= 0;
            for(integer i=0; i<64; i++) results[i] <= 0;
            for(integer m=0; m<32; m++) acc[m] <= 0;
            for(integer m=0; m<32; m++) w_read[m] <= 0;
            px_read <= 0;
        end else begin
            case (state)
                IDLE: begin
                    valid_out <= 0;
                    if (lb_valid) begin
                        state <= COMPUTE;
                        batch_idx <= 0; ic_idx <= 0; k_idx <= 0;
                        for(integer m=0; m<32; m++) acc[m] <= (b_mem_all[m] <<< 8);
                    end
                end

                COMPUTE: begin
                    // Pipeline Stage 1: Read weights & pixels
                    // (Index logic simplified for BRAM inference)
                    w_read[0] <= w_rom_0[batch_idx*288 + ic_idx*9 + k_idx];
                    w_read[1] <= w_rom_1[batch_idx*288 + ic_idx*9 + k_idx];
                    w_read[2] <= w_rom_2[batch_idx*288 + ic_idx*9 + k_idx];
                    w_read[3] <= w_rom_3[batch_idx*288 + ic_idx*9 + k_idx];
                    w_read[4] <= w_rom_4[batch_idx*288 + ic_idx*9 + k_idx];
                    w_read[5] <= w_rom_5[batch_idx*288 + ic_idx*9 + k_idx];
                    w_read[6] <= w_rom_6[batch_idx*288 + ic_idx*9 + k_idx];
                    w_read[7] <= w_rom_7[batch_idx*288 + ic_idx*9 + k_idx];
                    w_read[8] <= w_rom_8[batch_idx*288 + ic_idx*9 + k_idx];
                    w_read[9] <= w_rom_9[batch_idx*288 + ic_idx*9 + k_idx];
                    w_read[10] <= w_rom_10[batch_idx*288 + ic_idx*9 + k_idx];
                    w_read[11] <= w_rom_11[batch_idx*288 + ic_idx*9 + k_idx];
                    w_read[12] <= w_rom_12[batch_idx*288 + ic_idx*9 + k_idx];
                    w_read[13] <= w_rom_13[batch_idx*288 + ic_idx*9 + k_idx];
                    w_read[14] <= w_rom_14[batch_idx*288 + ic_idx*9 + k_idx];
                    w_read[15] <= w_rom_15[batch_idx*288 + ic_idx*9 + k_idx];
                    w_read[16] <= w_rom_16[batch_idx*288 + ic_idx*9 + k_idx];
                    w_read[17] <= w_rom_17[batch_idx*288 + ic_idx*9 + k_idx];
                    w_read[18] <= w_rom_18[batch_idx*288 + ic_idx*9 + k_idx];
                    w_read[19] <= w_rom_19[batch_idx*288 + ic_idx*9 + k_idx];
                    w_read[20] <= w_rom_20[batch_idx*288 + ic_idx*9 + k_idx];
                    w_read[21] <= w_rom_21[batch_idx*288 + ic_idx*9 + k_idx];
                    w_read[22] <= w_rom_22[batch_idx*288 + ic_idx*9 + k_idx];
                    w_read[23] <= w_rom_23[batch_idx*288 + ic_idx*9 + k_idx];
                    w_read[24] <= w_rom_24[batch_idx*288 + ic_idx*9 + k_idx];
                    w_read[25] <= w_rom_25[batch_idx*288 + ic_idx*9 + k_idx];
                    w_read[26] <= w_rom_26[batch_idx*288 + ic_idx*9 + k_idx];
                    w_read[27] <= w_rom_27[batch_idx*288 + ic_idx*9 + k_idx];
                    w_read[28] <= w_rom_28[batch_idx*288 + ic_idx*9 + k_idx];
                    w_read[29] <= w_rom_29[batch_idx*288 + ic_idx*9 + k_idx];
                    w_read[30] <= w_rom_30[batch_idx*288 + ic_idx*9 + k_idx];
                    w_read[31] <= w_rom_31[batch_idx*288 + ic_idx*9 + k_idx];
                    px_read <= lb_out[k_idx][ic_idx*16 +: 16];

                    // Pipeline Stage 2: Multiply & Accumulate (Delayed by 1 cycle)
                    for (integer m=0; m<32; m=m+1) begin
                        acc[m] <= acc[m] + ($signed(px_read) * $signed(w_read[m]));
                    end

                    // Loop logic
                    if (k_idx == 8) begin
                        k_idx <= 0;
                        if (ic_idx == 31) begin
                            ic_idx <= 0;
                            state <= WAIT_PIPE; // Extra cycle to catch last MAC
                        end else ic_idx <= ic_idx + 1;
                    end else k_idx <= k_idx + 1;
                end

                WAIT_PIPE: begin
                    // Final Accumulation cycle for the last product
                    for (integer m=0; m<32; m=m+1) begin
                        automatic logic signed [39:0] res = acc[m] + ($signed(px_read) * $signed(w_read[m]));
                        results[batch_idx*32 + m] <= (res >>> 8 > 32767) ? 16'h7FFF : (res >>> 8 < 0) ? 16'd0 : res[23:8];
                    end
                    
                    if (batch_idx == 1) begin
                        state <= SERIAL_OUT;
                        serial_oc <= 0; valid_out <= 1;
                        // Pre-calculate results[0] immediately for simulation
                        begin
                            automatic logic signed [39:0] first_res = acc[0] + ($signed(px_read) * $signed(w_read[0]));
                            pixel_out <= (first_res >>> 8 > 32767) ? 16'h7FFF : (first_res >>> 8 < 0) ? 16'd0 : first_res[23:8];
                        end
                    end else begin
                        batch_idx <= batch_idx + 1;
                        for(integer m=0; m<32; m++) acc[m] <= (b_mem_all[32 + m] <<< 8);
                        state <= COMPUTE;
                    end
                end

                SERIAL_OUT: begin
                    if (valid_out && ready_in) begin
                        if (serial_oc == 63) begin
                            valid_out <= 0; state <= IDLE;
                        end else begin
                            serial_oc <= serial_oc + 1;
                            pixel_out <= results[serial_oc + 1];
                        end
                    end
                end
            endcase
        end
    end
endmodule
