`timescale 1ns/1ps
module top#(
    parameter CLKS_PER_BIT = 234,
    parameter integer SIZE = 32
)
(
    input wire clk,
    input wire rst_n,
    input wire uart_rx,
    output wire uart_tx
);

    //uart Rx
    wire rx_dv;
    wire [7:0] rx_byte_r;
    reg [2:0] rx_index_r;

    //uart tx
    wire tx_active;
    wire tx_done;
    reg tx_dv_r;
    reg [7:0]tx_byte_r;
    reg [2:0]tx_index_r;
    reg tx_start_r;
    reg [31:0] sum_latched_r;
    reg cout_latched_r;

    //ripple carry adder 
    reg [31:0] a_r, b_r;
    reg packet_done_r;

    uart_rx #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) dut_rx(
        .CLK(clk),
        .Rx_in(uart_rx),
        .Rx_DV_out(rx_dv),
        .Rx_Byte_out(rx_byte_r)
    );

    always @(posedge clk ) begin
        if(!rst_n) begin
            a_r <= 32'h0;
            b_r <= 32'h0;
            rx_index_r <= 3'd0;
            packet_done_r <= 1'b0;
        end
        else begin
            packet_done_r <= 1'b0;
            if(rx_dv) begin
                case (rx_index_r)
                    3'b000: a_r[7:0]    <= rx_byte_r;
                    3'b001: a_r[15:8]   <= rx_byte_r;
                    3'b010: a_r[23:16]  <= rx_byte_r;
                    3'b011: a_r[31:24]  <= rx_byte_r;
                    3'b100: b_r[7:0]    <= rx_byte_r;
                    3'b101: b_r[15:8]   <= rx_byte_r;
                    3'b110: b_r[23:16]  <= rx_byte_r;
                    3'b111: begin
                        b_r[31:24] <= rx_byte_r;
                        packet_done_r <= 1'b1;
                    end
                endcase
                rx_index_r <= (rx_index_r == 3'd7) ? 3'd0 : (rx_index_r + 3'd1);
            end
        end
    end

    wire [SIZE - 1:0] sum_w;
    wire cout_w;

    rippleCarryAdder32bit #(
        .SIZE(SIZE)
    ) dut_ripple (
        .a   (a_r),
        .b   (b_r),
        .cin (1'b0),
        .sum (sum_w),
        .cout(cout_w)
    );

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            sum_latched_r <= 32'h0;
            cout_latched_r <= 1'b0;
            tx_start_r <= 1'b0;
        end
        else begin
            tx_start_r <= 1'b0;
            if(packet_done_r) begin
                sum_latched_r <= sum_w;
                cout_latched_r <= cout_w;
                tx_start_r <= 1'b1;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            tx_dv_r <= 1'b0;
            tx_byte_r <= 8'h00;
            tx_index_r <= 3'd0;
        end
        else begin
            tx_dv_r <= 1'b0;
            if(tx_start_r && !tx_active) begin
                tx_index_r <= 3'd0;
                tx_byte_r <= sum_latched_r[7:0];
                tx_dv_r <= 1'b1;
            end
            else if(tx_done) begin
                case (tx_index_r)
                    3'd0: begin
                        tx_index_r <= 3'd1;
                        tx_byte_r <= sum_latched_r[15:8];
                        tx_dv_r <= 1'b1;
                    end 
                    3'd1: begin
                        tx_index_r <= 3'd2;
                        tx_byte_r <= sum_latched_r[23:16];
                        tx_dv_r <= 1'b1;
                    end
                    3'd2: begin
                        tx_index_r <= 3'd3;
                        tx_byte_r <= sum_latched_r[31:24];
                        tx_dv_r <= 1'b1;
                    end
                    3'd3: begin
                        tx_index_r <= 3'd4;
                        tx_byte_r  <= {7'b0, cout_latched_r}; 
                        tx_dv_r    <= 1'b1;
                    end
                    default:  begin
                        tx_index_r <= 3'd0;
                    end
                endcase
            end
        end
    end

    uart_tx #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) dut_tx(
        .CLK(clk),
        .Tx_DV_in(tx_dv_r),
        .Tx_Byte_in(tx_byte_r),
        .Tx_Active_out(tx_active),
        .Tx_out(uart_tx),
        .Tx_Done_out(tx_done)
    );

endmodule

