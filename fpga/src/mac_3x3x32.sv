`timescale 1ns / 1ps

module mac_3x3x32 #(
    parameter IN_CHANNELS = 32,
    parameter DATA_WIDTH = 16
)(
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    output wire ready_out,
    
    input wire [IN_CHANNELS*DATA_WIDTH-1:0] p00, p01, p02,
    input wire [IN_CHANNELS*DATA_WIDTH-1:0] p10, p11, p12,
    input wire [IN_CHANNELS*DATA_WIDTH-1:0] p20, p21, p22,
    
    input wire signed [DATA_WIDTH-1:0] weights [0:IN_CHANNELS-1][0:8],
    input wire signed [DATA_WIDTH-1:0] bias,
    
    output reg valid_out,
    output reg signed [DATA_WIDTH-1:0] mac_out
);

    typedef enum logic [1:0] {IDLE=2'b00, BUSY=2'b01, FINAL=2'b10} state_t;
    state_t state;
    reg [3:0] count;
    reg signed [39:0] acc;

    reg [IN_CHANNELS*DATA_WIDTH-1:0] p_reg [0:8];
    reg signed [DATA_WIDTH-1:0] b_reg;

    // IMPORTANT: Only ready in IDLE
    assign ready_out = (state == IDLE);

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE; count <= 0; acc <= 0; valid_out <= 0; mac_out <= 0;
            for(i=0; i<9; i=i+1) p_reg[i] <= 0;
            b_reg <= 0;
        end else begin
            case (state)
                IDLE: begin
                    valid_out <= 0;
                    // Only start on the RISING edge of a valid handshake
                    if (valid_in) begin
                        p_reg[0] <= p00; p_reg[1] <= p01; p_reg[2] <= p02;
                        p_reg[3] <= p10; p_reg[4] <= p11; p_reg[5] <= p12;
                        p_reg[6] <= p20; p_reg[7] <= p21; p_reg[8] <= p22;
                        b_reg <= bias;
                        acc <= 0;
                        count <= 0;
                        state <= BUSY;
                    end
                end
                
                BUSY: begin
                    automatic logic signed [39:0] cycle_sum = 0;
                    for (i=0; i<32; i=i+1) begin
                        cycle_sum = cycle_sum + $signed(p_reg[count][i*DATA_WIDTH +: DATA_WIDTH]) * weights[i][count];
                    end
                    acc <= acc + cycle_sum;
                    
                    if (count == 8) state <= FINAL;
                    else count <= count + 1;
                end
                
                FINAL: begin
                    automatic logic signed [39:0] total = acc + ($signed(b_reg) <<< 8);
                    if ((total >>> 8) > 32767) mac_out <= 16'h7FFF;
                    else if ((total >>> 8) < -32768) mac_out <= 16'h8000;
                    else mac_out <= total[23:8];
                    
                    valid_out <= 1;
                    state <= IDLE; // Back to IDLE, ready_out will be 1 on next cycle
                end
            endcase
        end
    end
endmodule
