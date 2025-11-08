`timescale 1ns/1ps
module uart_rx #(
	parameter CLKS_PER_BIT = 234
)
(
	input wire CLK,
	input wire Rx_in,
	output wire Rx_DV_out,
	output wire [7:0] Rx_Byte_out
);

	localparam  s_IDLE = 3'b000;
	localparam s_RX_START_BIT = 3'b001;
	localparam s_RX_DATA_BITS = 3'b010;
	localparam s_RX_STOP_BIT = 3'b011;
	localparam s_CLEANUP = 3'b100;

	reg [2:0] current_state_r = s_IDLE;
	reg [2:0] next_state_r;

	reg rx_data_temp_r = 1'b1;
	reg rx_data_r = 1'b1;
	reg [7:0]clock_count_r = 8'd0;
	reg [2:0]bit_index_r = 3'd0;
	reg [7:0]rx_byte_r = 8'd0;
	reg rx_dv_r = 1'b0;
	
	always @(posedge CLK) begin
		rx_data_temp_r <= Rx_in;
		rx_data_r <= rx_data_temp_r; 
	end


	always @(*) begin
		case (current_state_r)
			s_IDLE: begin
				if(rx_data_r == 1'b0) begin
					next_state_r = s_RX_START_BIT;
				end
				else begin
					next_state_r = s_IDLE;
				end
			end 

			s_RX_START_BIT: begin
				if(clock_count_r == (CLKS_PER_BIT - 1) / 2) begin
					if(rx_data_r == 1'b0) begin
						next_state_r = s_RX_DATA_BITS;
					end
					else begin
						next_state_r = s_IDLE;
					end
				end
				else begin
					next_state_r = s_RX_DATA_BITS;
				end
			end

			s_RX_DATA_BITS: begin
				if(clock_count_r < CLKS_PER_BIT - 1) begin
					next_state_r = s_RX_DATA_BITS;
				end
				else if(bit_index_r < 3'd7) begin
					next_state_r = s_RX_DATA_BITS;
				end
				else begin
					next_state_r = s_RX_STOP_BIT;
				end
			end

			s_RX_STOP_BIT: begin
				if(clock_count_r < CLKS_PER_BIT - 1) begin
					next_state_r = s_RX_STOP_BIT;
				end
				else begin
					next_state_r = s_CLEANUP;
				end
			end

			s_CLEANUP: begin
				next_state_r = s_IDLE;
			end

			default: begin
				next_state_r = s_IDLE;
			end 
		endcase
	end

	always @(posedge CLK) begin
		current_state_r <= next_state_r;
	end

	always @(posedge CLK) begin
		case (current_state_r) 
			s_IDLE: begin
				rx_dv_r <= 1'b0;
				clock_count_r <= 8'd0;
				bit_index_r <= 3'd0;
			end 

			s_RX_START_BIT: begin
				if(clock_count_r == (CLKS_PER_BIT - 1) / 2) begin
					if(rx_data_r == 1'b0) begin
						clock_count_r <= 8'd0;
					end
				end
				else begin
					clock_count_r <= clock_count_r + 1'b1;
				end
			end

			s_RX_DATA_BITS: begin
				if(clock_count_r < CLKS_PER_BIT - 1) begin
					clock_count_r <= clock_count_r + 1'b1;
				end
				else begin
					clock_count_r <= 8'd0;
                    rx_byte_r[bit_index_r] <= rx_data_r;
					if(bit_index_r < 3'd7) begin
						bit_index_r <= bit_index_r + 1'b1; 
					end
					else begin
						bit_index_r <= 3'd0;
					end
				end
			end

			s_RX_STOP_BIT: begin
				if(clock_count_r < CLKS_PER_BIT - 1) begin
					clock_count_r <= clock_count_r + 1'b1;
				end
				else begin
					rx_dv_r <= 1'b1;
					clock_count_r <= 8'd0;
				end
			end

			s_CLEANUP: begin
				rx_dv_r <= 1'b0;
			end

			default: begin
				rx_dv_r <= 1'b0;
				clock_count_r <= 8'd0;
				bit_index_r <= 3'd0;
			end 
		endcase
	end

	assign Rx_DV_out = rx_dv_r;
	assign Rx_Byte_out = rx_byte_r;

endmodule