`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: SUES
// Engineer: Jazel Zhang
// 
// Create Date: 09/12/2022 03:31:46 PM
// Design Name: 
// Module Name: ads1299_driver
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module ads1299_driver

# (parameter freq_i = 200_000_000, spi_clk_freq = 20_000_000, CPOL = 0, CPHA = 1)
(
	input clk,//200MHz
	input rst_n,
    input SPI_MISO,
    input SPI_nDRDY,
	input wr_enable,
	input [3:0] wr_byte,
	input [23:0] wr_data,
	input rd_enable,
	
		output reg SPI_MOSI,
		// output reg SPI_nCS,
		output reg finish_wr,
		output reg finish_rd,
		output reg SPI_CLK,//
		output [215: 0] eeg_data
    );

// /* ILA
// ila_0  ila_0_inst
// (
// .clk 								(clk),
// .probe0							(rst_n),
// .probe1							(wr_enable),
// .probe2							(wr_byte),//[3:0]
// .probe3							(wr_data),//[23:0]
// .probe4							(rd_enable),
// .probe5							(finish_wr),
// .probe6								(finish_rd),
// .probe7								(eeg_data),//[215:0]
// .probe8								(state),//[3:0]
// .probe9								(next_state),//[3:0]
// .probe10							(SPI_MISO),
// .probe11							(SPI_MOSI),
// .probe12							(SPI_CLK)
// );

// */

//parameter definition
parameter idle_state = 0;
parameter start_state = 1; //used to deal with CPHA;
parameter trans_state = 2;
parameter end_state = 3;
parameter read_state =4;
parameter SPI_half_period = freq_i / spi_clk_freq / 2;
//reg definition
reg [31:0] counter;
reg [7:0] wr_cnt;
reg [7:0] rd_cnt;
reg [15:0] last_bit_cnt;
reg [215:0] eeg_data_r;
reg last_bit_sig;
reg [23:0] send_bit;
reg [3:0] state;
reg [3:0] next_state;
reg start_done;
reg tx_done;
reg rd_done;
//wire definition

assign eeg_data = eeg_data_r;

//first state of FSM
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		state <= idle_state;
	else
		state <= next_state;
end
//Second state of FSM
always@(negedge clk or negedge rst_n)
begin
	if(!rst_n)
		begin
		next_state <= idle_state;		
		end
	else
		begin
		case(state)
			idle_state:
				begin	
				if(wr_enable)
						next_state <= start_state;
				else if(rd_enable)
						next_state <= read_state;
				else
						next_state <= idle_state;
				end
				
			start_state: //Use this state state to realize different value of CPHA;
				begin
					if(start_done )
							next_state <= trans_state;
					else
						next_state <= start_state;
				end
			
			trans_state:
				begin
					if(!tx_done)
						next_state <= trans_state;
					else if(tx_done && rd_enable)
						next_state <= read_state;
					else
						next_state <= idle_state;
				end
			read_state:
				begin
					if(rd_done)
						next_state <= idle_state;
					else
						next_state <= read_state;
				end
			default:
				next_state <= next_state;
			endcase
		end
end


always@(posedge clk or negedge rst_n)
	begin
		if(!rst_n)
			begin
				SPI_MOSI <= 0;
				SPI_CLK <= CPOL;
				counter <= 0;
				send_bit <= 0;
				eeg_data_r <= 216'h0; 
				finish_rd <= 0;
				finish_wr <= 0;
				start_done <= 0;
				tx_done <= 0;
				wr_cnt <= 0;
				rd_done <= 0;
				rd_cnt <= 0;
				finish_rd <= 0;
				last_bit_cnt <= 0;
				last_bit_sig <= 0;
			end
		else 
			begin
				case(state)
					idle_state:
						begin
							SPI_MOSI <= 0;
							SPI_CLK <= CPOL;
							counter <= 0;
							send_bit <= 0;
							eeg_data_r <= 216'h0; 
							finish_rd <= 0;
							finish_wr <= 0;
							start_done <= 0;
							tx_done <= 0;
							wr_cnt <= 0;
							rd_done <= 0;
							rd_cnt <= 0;
							finish_rd <= 0;
							last_bit_cnt <= 0;
							last_bit_sig <= 0;
						end
					start_state:
						begin
							if(CPHA)
								begin
									if(counter == SPI_half_period)
										begin
											SPI_CLK <= !SPI_CLK;
											SPI_MOSI <= wr_data[(wr_byte << 3) - 1];
											counter <= counter + 1;
										end
									else if(counter == 2*SPI_half_period)
										begin
											SPI_CLK <= !SPI_CLK;
											start_done <= 1;
											counter = 0;
										end
									else
										begin
											SPI_CLK <= SPI_CLK;
											start_done <= 0;
											counter <= counter + 1;
										end
								end
							else
								begin
									if(counter < SPI_half_period)
										begin
											SPI_MOSI <= wr_data[(wr_byte << 3) -1];
											start_done <= 0;
											counter <= counter + 1;
										end
									else if(counter == SPI_half_period)
										begin
											SPI_CLK <= !SPI_CLK;
											start_done <= 0;
											counter <= counter + 1;
										end
									else if(counter == 2*SPI_half_period)
										begin
											SPI_CLK <= !SPI_CLK;
											start_done <= 1;
											counter <= 0;
										end
									else
										begin
											counter <= counter + 1;
										end
								end
						end
					trans_state:
						begin
							if(CPHA)
								begin
									if(last_bit_sig && (last_bit_cnt == SPI_half_period))
										begin
											tx_done <= 1;
											last_bit_cnt <= 0;
											finish_wr <= 1;
											SPI_MOSI <= CPOL;
										end
									else if(last_bit_sig)
										begin
											tx_done <= 0;
											last_bit_cnt <= last_bit_cnt + 1;
											SPI_CLK <= CPOL;
											SPI_MOSI <= SPI_MOSI;
										end
									else if(counter == SPI_half_period)
										begin
											SPI_MOSI <= wr_data[(wr_byte << 3) - wr_cnt - 2];
											SPI_CLK <= !SPI_CLK;
											counter <= counter + 1;
											wr_cnt <= wr_cnt + 1;
											tx_done <= 0;
										end
									else if((counter == 2*SPI_half_period) && (wr_cnt == (wr_byte << 3) - 1))
										begin
											last_bit_sig <= 1;
											counter <= 0;
											wr_cnt <= 0;
											SPI_CLK <= CPOL;
											SPI_MOSI <= SPI_MOSI;
											finish_wr <= 0;
										end
									else if(counter == 2*SPI_half_period)
										begin
											tx_done <= 0;
											SPI_CLK <= !SPI_CLK;
											counter <= 0;
										end
									else
										begin
										counter <= counter + 1;
										end
								end
								
							else
								begin
									if(counter < SPI_half_period)
										begin
											SPI_MOSI <= wr_data[(wr_byte << 3) - wr_cnt - 2];
											counter <= counter + 1;
										end
									else if(counter == SPI_half_period)
										begin
											wr_cnt <= wr_cnt +1;
											SPI_CLK <= !SPI_CLK;
											counter <= counter + 1;
										end
									else if(counter == 2*SPI_half_period && (wr_cnt == (wr_byte << 3) - 1))
										begin
											tx_done <= 1;
											SPI_CLK <= CPOL;
											counter <= 0;
											wr_cnt <= 0;
										end
									else if(counter == 2*SPI_half_period) 
										begin
											tx_done <= 0;
											SPI_CLK <= !SPI_CLK;
											counter <= 0;
										end
									else
										begin
											counter <= counter + 1;
										end
								end

						end
					read_state:
						begin
							finish_wr <= 0;
							last_bit_sig <= 0;
							if(CPHA)
								begin
									if(counter == SPI_half_period)
										begin
											SPI_CLK <= !SPI_CLK;
											counter <= counter + 1;
										end
									else if(counter == 2*SPI_half_period && rd_cnt == 216)
										begin
											SPI_CLK <= CPOL;
											rd_done <= 1;
											finish_rd <= 1;
											rd_cnt <= 0;
											counter <= 0;
										end
									else if(counter == 2*SPI_half_period)	
										begin
											SPI_CLK <= !SPI_CLK;
											eeg_data_r[215-rd_cnt] = SPI_MISO;
											rd_cnt <= rd_cnt + 1;
											counter <= 0;
										end
									else
										begin
											counter <= counter + 1;
										end
								end
							else
								begin
									if(counter == SPI_half_period)
										begin
											SPI_CLK <= !SPI_CLK;
											eeg_data_r[215-rd_cnt] = SPI_MISO;
											rd_cnt <= rd_cnt + 1;
											counter <= counter + 1;
										end
									else if(counter == 2*SPI_half_period && rd_cnt == 216)
										begin
											SPI_CLK <= CPOL;
											rd_done <= 1;
											finish_rd <= 1;
											rd_cnt <= 0;
											counter <= 0;
										end
									else if(counter == 2*SPI_half_period)
										begin
											SPI_CLK <= !SPI_CLK;
											rd_done <= 0;
											counter <= 0;
										end
									else
										begin
											counter <= counter + 1;
										end				
								end
							
						end
					
					default:
						begin
							SPI_MOSI <= 0;
							SPI_CLK <= CPOL;
							counter <= 0;
							send_bit <= 0;
							eeg_data_r <= 216'h0; 
							finish_rd <= 0;
							finish_wr <= 0;
							start_done <= 0;
							tx_done <= 0;
							wr_cnt <= 0;
							rd_done <= 0;
							rd_cnt <= 0;
							finish_rd <= 0;
						end
				endcase
			/*
				if(!CPHA)
					begin
						if(counter < (wr_byte << 4))
							begin	
							SPI_CLK = ~SPI_CLK;
								if(!CPOL)
									begin
									SPI_MOSI = wr_data[send_bit - 1];
									send_bit = send_bit - 1;
									end
								else
									begin
									SPI_MOSI = SPI_MOSI;
									send_bit = send_bit;
									end
							counter = counter + 1;
							end
						else
							begin
							SPI_CLK = 0;
							counter = 0;
							end
					end
				else
					begin
						
					end
					*/
			end
	end

endmodule
