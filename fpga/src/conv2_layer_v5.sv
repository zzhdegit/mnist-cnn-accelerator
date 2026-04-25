`timescale 1ns / 1ps

// Zynq-7020 Conv2 (v8.3 - Synchronous 16-MAC Pipelined)
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

    reg signed [DATA_WIDTH-1:0] w_mem_all [0:18431];
    reg signed [DATA_WIDTH-1:0] b_mem_all [0:63];
    
    // Using 16 individual ROMs to force BRAM inference and improve timing
    (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] w_rom_0 [0:1151];
    (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] w_rom_1 [0:1151];
    (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] w_rom_2 [0:1151];
    (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] w_rom_3 [0:1151];
    (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] w_rom_4 [0:1151];
    (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] w_rom_5 [0:1151];
    (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] w_rom_6 [0:1151];
    (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] w_rom_7 [0:1151];
    (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] w_rom_8 [0:1151];
    (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] w_rom_9 [0:1151];
    (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] w_rom_10 [0:1151];
    (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] w_rom_11 [0:1151];
    (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] w_rom_12 [0:1151];
    (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] w_rom_13 [0:1151];
    (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] w_rom_14 [0:1151];
    (* ram_style = "block" *) reg signed [DATA_WIDTH-1:0] w_rom_15 [0:1151];

    initial begin
        $readmemh("D:/IC_Workspace/mnist/fpga/data/conv2_w.hex", w_mem_all);
        $readmemh("D:/IC_Workspace/mnist/fpga/data/conv2_b.hex", b_mem_all);
        for (integer b=0; b<4; b=b+1) begin
            for (integer ic=0; ic<32; ic=ic+1) begin
                for (integer k=0; k<9; k=k+1) begin
                    w_rom_0[b*288 + ic*9 + k] = w_mem_all[(b*16 + 0)*288 + ic*9 + k];
                    w_rom_1[b*288 + ic*9 + k] = w_mem_all[(b*16 + 1)*288 + ic*9 + k];
                    w_rom_2[b*288 + ic*9 + k] = w_mem_all[(b*16 + 2)*288 + ic*9 + k];
                    w_rom_3[b*288 + ic*9 + k] = w_mem_all[(b*16 + 3)*288 + ic*9 + k];
                    w_rom_4[b*288 + ic*9 + k] = w_mem_all[(b*16 + 4)*288 + ic*9 + k];
                    w_rom_5[b*288 + ic*9 + k] = w_mem_all[(b*16 + 5)*288 + ic*9 + k];
                    w_rom_6[b*288 + ic*9 + k] = w_mem_all[(b*16 + 6)*288 + ic*9 + k];
                    w_rom_7[b*288 + ic*9 + k] = w_mem_all[(b*16 + 7)*288 + ic*9 + k];
                    w_rom_8[b*288 + ic*9 + k] = w_mem_all[(b*16 + 8)*288 + ic*9 + k];
                    w_rom_9[b*288 + ic*9 + k] = w_mem_all[(b*16 + 9)*288 + ic*9 + k];
                    w_rom_10[b*288 + ic*9 + k] = w_mem_all[(b*16 + 10)*288 + ic*9 + k];
                    w_rom_11[b*288 + ic*9 + k] = w_mem_all[(b*16 + 11)*288 + ic*9 + k];
                    w_rom_12[b*288 + ic*9 + k] = w_mem_all[(b*16 + 12)*288 + ic*9 + k];
                    w_rom_13[b*288 + ic*9 + k] = w_mem_all[(b*16 + 13)*288 + ic*9 + k];
                    w_rom_14[b*288 + ic*9 + k] = w_mem_all[(b*16 + 14)*288 + ic*9 + k];
                    w_rom_15[b*288 + ic*9 + k] = w_mem_all[(b*16 + 15)*288 + ic*9 + k];
                end
            end
        end
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
    
    reg [2:0] batch_idx; reg [5:0] ic_idx; reg [3:0] k_idx; reg [5:0] serial_oc;
    wire lb_ready = (state == SERIAL_OUT && serial_oc == 63 && valid_out && ready_in);

    line_buffer #(512, 26) lb_inst (
        .clk(clk), .rst_n(rst_n), .valid_in(lb_valid_in_pulse), .ready_out(lb_ready_internal),
        .pixel_in(lb_pixel_in), .valid_out(lb_valid), .ready_in(lb_ready),
        .pixel_out(lb_out)
    );

    reg signed [39:0] acc [0:15];
    reg signed [DATA_WIDTH-1:0] results [0:63];
    reg signed [15:0] w_read [0:15];
    reg signed [15:0] px_read;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE; batch_idx <= 0; ic_idx <= 0; k_idx <= 0;
            valid_out <= 0; pixel_out <= 0; serial_oc <= 0;
            for(integer i=0; i<64; i++) results[i] <= 0;
            for(integer m=0; m<16; m++) acc[m] <= 0;
        end else begin
            case (state)
                IDLE: begin
                    valid_out <= 0;
                    if (lb_valid) begin
                        state <= COMPUTE;
                        batch_idx <= 0; ic_idx <= 0; k_idx <= 0;
                        for(integer m=0; m<16; m++) acc[m] <= (b_mem_all[0*16 + m] <<< 8);
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
                    px_read <= lb_out[k_idx][ic_idx*16 +: 16];

                    // Pipeline Stage 2: Multiply & Accumulate (Delayed by 1 cycle)
                    for (integer m=0; m<16; m=m+1) begin
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
                    for (integer m=0; m<16; m=m+1) begin
                        automatic logic signed [39:0] res = acc[m] + ($signed(px_read) * $signed(w_read[m]));
                        results[batch_idx*16 + m] <= (res >>> 8 > 32767) ? 16'h7FFF : (res >>> 8 < 0) ? 16'd0 : res[23:8];
                    end
                    
                    if (batch_idx == 3) begin
                        state <= SERIAL_OUT;
                        serial_oc <= 0; valid_out <= 1;
                        // Pre-calculate results[0] immediately for simulation
                        begin
                            automatic logic signed [39:0] first_res = acc[0] + ($signed(px_read) * $signed(w_read[0]));
                            pixel_out <= (first_res >>> 8 > 32767) ? 16'h7FFF : (first_res >>> 8 < 0) ? 16'd0 : first_res[23:8];
                        end
                    end else begin
                        batch_idx <= batch_idx + 1;
                        for(integer m=0; m<16; m++) acc[m] <= (b_mem_all[(batch_idx+1)*16 + m] <<< 8);
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
