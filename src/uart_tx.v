`timescale 1ns/1ps
module uart_tx #(
    parameter CLKS_PER_BIT = 234
)
(
    input wire CLK,
    input wire Tx_DV_in,
    input wire [7:0] Tx_Byte_in,
    output wire Tx_Active_out,
    output reg Tx_out,
    output wire Tx_Done_out
);

    localparam s_IDLE = 3'b000;
    localparam s_TX_START_BIT = 3'b001;
    localparam s_TX_DATA_BITS = 3'b010;
    localparam s_TX_STOP_BIT = 3'b011;
    localparam s_CLEANUP = 3'b100;

    reg [2:0] current_state_r = s_IDLE;
    reg [2:0] next_state_r;

    reg [7:0] clock_count_r = 8'd0;
    reg [2:0] bit_index_r = 3'd0;
    reg [7:0] tx_data_r = 8'd0;
    reg tx_done_r = 1'b0;
    reg tx_active_r = 1'b0;

    always @(*) begin
        case (current_state_r)
            s_IDLE: begin
                if(Tx_DV_in == 1'b1) begin
                    next_state_r = s_TX_START_BIT;
                end
                else begin
                    next_state_r = s_IDLE;
                end
            end 

            s_TX_START_BIT: begin
                if(clock_count_r < CLKS_PER_BIT - 1) begin
                    next_state_r = s_TX_START_BIT;
                end
                else begin
                    next_state_r = s_TX_DATA_BITS;
                end
            end

            s_TX_DATA_BITS: begin
                if(clock_count_r < CLKS_PER_BIT - 1) begin
                    next_state_r = s_TX_DATA_BITS;
                end
                else if(bit_index_r < 3'd7) begin
                    next_state_r = s_TX_DATA_BITS;
                end
                else begin
                    next_state_r = s_TX_STOP_BIT;
                end
            end

            s_TX_STOP_BIT: begin
                if(clock_count_r < CLKS_PER_BIT - 1) begin
                    next_state_r = s_TX_STOP_BIT;
                end
                else begin
                    next_state_r = s_CLEANUP;
                end
            end

            s_CLEANUP: begin
                next_state_r = s_IDLE;
            end

            default: begin
                next_state_r  = s_IDLE;
            end 
        endcase
    end

    always @(posedge CLK) begin
        current_state_r <= next_state_r;
    end

    always @(posedge CLK) begin
        case (current_state_r)
            s_IDLE: begin
                Tx_out <= 1'b1;
                tx_done_r <= 1'b0;
                clock_count_r <= 1'b0;
                bit_index_r <= 3'd0;

                if(Tx_DV_in == 1'b1) begin
                    tx_active_r <= 1'b1;
                    tx_data_r <= Tx_Byte_in;
                end
                else begin
                    tx_active_r <= 1'b0;
                end
            end 

            s_TX_START_BIT: begin
                Tx_out <= 1'b0;
                if(clock_count_r < CLKS_PER_BIT - 1) begin
                    clock_count_r <= clock_count_r + 1'b1;
                end
                else begin
                    clock_count_r <= 8'd0;
                end
            end

            s_TX_DATA_BITS: begin
                Tx_out <= tx_data_r[bit_index_r];
                if(clock_count_r < CLKS_PER_BIT - 1) begin
                    clock_count_r <= clock_count_r + 1'b1;
                end
                else begin
                    clock_count_r <= 8'd0;
                    if(bit_index_r < 3'd7) begin
                        bit_index_r <= bit_index_r + 1'b1;
                    end
                    else begin
                        bit_index_r <= 3'd0;
                    end
                end
            end

            s_TX_STOP_BIT: begin
                Tx_out <= 1'b1;
                if(clock_count_r < CLKS_PER_BIT - 1) begin
                    clock_count_r <= clock_count_r + 1'b1;
                end
                else begin
                    clock_count_r <= 8'd0;
                    tx_active_r <= 1'b0;
                end
            end

            s_CLEANUP: begin
                tx_done_r <= 1'b1;
            end

            default: begin
                Tx_out <= 1'b1;
                tx_done_r <= 1'b0;
                clock_count_r <= 8'd0;
                bit_index_r <= 3'd0;
                tx_active_r <= 1'b0;
            end 
        endcase
    end

    assign Tx_Active_out = tx_active_r;
    assign Tx_Done_out = tx_done_r;

endmodule