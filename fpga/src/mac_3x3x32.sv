module mac_3x3x32 #(
    parameter IN_CHANNELS = 32,
    parameter DATA_WIDTH = 16
)(
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    
    // Each p_xx is IN_CHANNELS * DATA_WIDTH bits
    input wire [IN_CHANNELS*DATA_WIDTH-1:0] p00, p01, p02,
    input wire [IN_CHANNELS*DATA_WIDTH-1:0] p10, p11, p12,
    input wire [IN_CHANNELS*DATA_WIDTH-1:0] p20, p21, p22,
    
    // Weights: flattened [3*3*IN_CHANNELS-1:0] 
    // Actually, it's easier to pass an array of weights.
    input wire signed [DATA_WIDTH-1:0] weights [0:IN_CHANNELS-1][0:8],
    input wire signed [DATA_WIDTH-1:0] bias,
    
    output reg valid_out,
    output reg signed [DATA_WIDTH-1:0] mac_out
);

    // 288 multipliers
    reg signed [31:0] mults [0:IN_CHANNELS-1][0:8];
    reg signed [31:0] b_ext;
    reg v1;

    // Accumulation tree
    reg signed [39:0] channel_sums [0:IN_CHANNELS-1];
    reg v2;

    reg signed [39:0] total_sum;
    reg v3;

    integer c, j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (c = 0; c < IN_CHANNELS; c = c + 1) begin
                for (j = 0; j < 9; j = j + 1) begin
                    mults[c][j] <= 0;
                end
                channel_sums[c] <= 0;
            end
            b_ext <= 0;
            total_sum <= 0;
            valid_out <= 0;
            mac_out <= 0;
            v1 <= 0; v2 <= 0; v3 <= 0;
        end else begin
            // Stage 1: 288 Multiplications
            for (c = 0; c < IN_CHANNELS; c = c + 1) begin
                mults[c][0] <= $signed(p00[c*DATA_WIDTH +: DATA_WIDTH]) * weights[c][0];
                mults[c][1] <= $signed(p01[c*DATA_WIDTH +: DATA_WIDTH]) * weights[c][1];
                mults[c][2] <= $signed(p02[c*DATA_WIDTH +: DATA_WIDTH]) * weights[c][2];
                mults[c][3] <= $signed(p10[c*DATA_WIDTH +: DATA_WIDTH]) * weights[c][3];
                mults[c][4] <= $signed(p11[c*DATA_WIDTH +: DATA_WIDTH]) * weights[c][4];
                mults[c][5] <= $signed(p12[c*DATA_WIDTH +: DATA_WIDTH]) * weights[c][5];
                mults[c][6] <= $signed(p20[c*DATA_WIDTH +: DATA_WIDTH]) * weights[c][6];
                mults[c][7] <= $signed(p21[c*DATA_WIDTH +: DATA_WIDTH]) * weights[c][7];
                mults[c][8] <= $signed(p22[c*DATA_WIDTH +: DATA_WIDTH]) * weights[c][8];
            end
            b_ext <= bias <<< 8;
            v1 <= valid_in;

            // Stage 2: Channel sums (9 values per channel)
            for (c = 0; c < IN_CHANNELS; c = c + 1) begin
                channel_sums[c] <= mults[c][0] + mults[c][1] + mults[c][2] + 
                                   mults[c][3] + mults[c][4] + mults[c][5] + 
                                   mults[c][6] + mults[c][7] + mults[c][8];
            end
            v2 <= v1;

            // Stage 3: Total sum across all channels + bias
            total_sum <= b_ext
                + channel_sums[0] + channel_sums[1] + channel_sums[2] + channel_sums[3]
                + channel_sums[4] + channel_sums[5] + channel_sums[6] + channel_sums[7]
                + channel_sums[8] + channel_sums[9] + channel_sums[10] + channel_sums[11]
                + channel_sums[12] + channel_sums[13] + channel_sums[14] + channel_sums[15]
                + channel_sums[16] + channel_sums[17] + channel_sums[18] + channel_sums[19]
                + channel_sums[20] + channel_sums[21] + channel_sums[22] + channel_sums[23]
                + channel_sums[24] + channel_sums[25] + channel_sums[26] + channel_sums[27]
                + channel_sums[28] + channel_sums[29] + channel_sums[30] + channel_sums[31];
            v3 <= v2;

            // Stage 4: Output Output Scaling (Q16.16 -> Q8.8)
            if (v3) begin
                valid_out <= 1;
                if ((total_sum >>> 8) > 32767) mac_out <= 32767;
                else if ((total_sum >>> 8) < -32768) mac_out <= -32768;
                else mac_out <= total_sum[23:8];
            end else begin
                valid_out <= 0;
            end
        end
    end
endmodule