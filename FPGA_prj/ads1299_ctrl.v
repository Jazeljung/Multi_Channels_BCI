`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: SUES & Lattice Shanghai
// Engineer: Jazel ZHANG
// Mail: Jazel.Zhang@latticesemi.com
// Create Date: 09/12/2022 03:09:28 PM
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


module ads1299_ctrl
# (parameter freq = 200_000_000, CPOL = 0, CPHA = 1)
(
    input clk,
	input rst_n,
    input [7:0] SPI_MISO,
    input [7:0] SPI_nDRDY,
	input enable,
	input [7:0] op_reg,
	input [1:0] op_type,
	input [7:0] op_data_i,
	
		// output ads1299_init_done,
		output finish_samp,
		output [1727:0] bci_data,
		output [7:0] SPI_MOSI,
		output reg [7:0] SPI_nCS,
		output reg SPI_nRST,
		output SPI_CLK,
		output reg SPI_nPWDN,
		output reg SPI_START,
		output [7:0] op_data_o,
		output op_done_o
    );

wire [215:0] eeg_data[0:7];
reg config_sig0, config_sig1, config_sig2, config_sig3, config_sig4, config_sig5, config_sig6;
reg config_sig7, config_sig8, config_sig9, config_sig10, config_sig11, config_sig12, config_sig13;
wire finish_wr, finish_rd, finish_rd6, finish_wr6;
wire drdy_neg;
reg finish_samp_r;
reg wr_enable;
reg rd_enable;
reg [4:0] state;
reg [4:0] next_state;
reg [31:0] counter;
reg [3:0] wr_byte;
reg [4:0] rd_reg_cnt;
reg wkup_done;
reg reset_done;
reg stopsend_done;
reg [23 : 0] wr_data;
reg read_done;
reg wait_cs;
reg [2:0] wr_num;
reg delay_sig, rd_sig;
reg start_done,startsend_done,read_done;
reg [31:0] test_cnt;
reg [7:0] drdy_cnt;
reg drdy_d0, drdy_d1;
reg timout_sig;
reg op_write_done;
reg op_read_done;
reg [7:0] op_data_r;

//state_machine parameter definition
parameter  t_por  = freq >> 2;  //250ms is enough for 2.048MHz
parameter t_rd_reg_delay = freq >> 6;//15.625ms
parameter t_rst0 = freq >> 18; //about 4us;
parameter t_rst1 = freq >> 15; //about 30.5us;
parameter t_start = freq >> 10;// about 1ms;

parameter idle_state = 0;
parameter wkup_state = 1;
parameter reset_state = 2;
parameter stopsend_state = 3;
parameter config_state0 = 4;
parameter config_state1 = 5;
parameter config_state2 = 6;
parameter config_state3 = 7;
parameter config_state4 = 8;
parameter config_state5 = 9;
parameter config_state6 = 10;
parameter config_state7 = 11;
parameter config_state8 = 12;
parameter config_state9 = 13;
parameter config_state10 = 14;
parameter config_state11 = 15;
parameter config_state12 = 16;
parameter config_state13 = 17;
parameter start_state = 18;
parameter startsend_state = 19;
parameter read_state =20;
parameter op_write_state = 21;
parameter op_read_state = 22;

parameter config_bit0 = 0;
parameter config_bit1 = 1;
parameter config_bit2 = 2;
parameter config_bit3 = 3;
assign bci_data = {eeg_data[0], eeg_data[1], eeg_data[2], eeg_data[3], eeg_data[4], eeg_data[5], eeg_data[6], eeg_data[7]};
assign finish_samp = finish_samp_r;
assign op_done_o = op_read_done | op_write_done;
assign op_data_o = op_data_r;
//Intergrated logic analyzer
// ila_1  ila_1_inst
// (
// .clk 								(clk),
// .probe0						(rst_n),
// .probe1							(state),//[4:0]
// .probe2							(SPI_START),//
// .probe3							(SPI_nRST),//
// .probe4							(SPI_MOSI),//[7:0]
// .probe5							(SPI_MISO),//[7:0]
// .probe6							(SPI_nCS),//[7:0]
// .probe7							(SPI_CLK),
// .probe8							(SPI_nDRDY),//[7:0]
// .probe9								(eeg_data0),//[215:0]
// .probe10								(eeg_data1),//[215:0]
// .probe11								(eeg_data2),//[215:0]
// .probe12						(config_sig13),
// .probe13						(wr_num),//[2:0]
// .probe14						(counter),//[31:0] 
// .probe15						(startsend_done),
// .probe16						(finish_wr),
// .probe17						(rd_enable),
// .probe18						(read_done),
// .probe19						(wr_data),
// .probe20						(wr_enable),
// .probe21						(finish_rd),
// .probe22						(finish_wr6),
// .probe23						(finish_samp),
// .probe24						(finish_rd6),
// .probe25						(rd_sig),
// .probe26						(drdy_cnt),//[7:0]
// .probe27						(timout_sig),
// .probe28						(drdy_neg),
// .probe29						(op_reg),//[7:0]
// .probe30						(op_type),//[1:0]
// .probe31						(op_data_i),//[7:0]
// .probe32						(op_done_o),
// .probe33						(op_write_done),
// .probe34						(op_read_done),
// .probe35						(op_data_o)

// );

assign drdy_neg = (!drdy_d0) & drdy_d1;

//edge detector
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		begin
			drdy_d0 <= 0;
			drdy_d1 <= 0;
		end
	else
		begin
			drdy_d0 <= SPI_nDRDY[0];
			drdy_d1 <= drdy_d0;
		end
end

always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		begin
			test_cnt <= 0;
			drdy_cnt <= 0;
			timout_sig <= 0;
		end
	else
		begin
			if(drdy_neg)
				drdy_cnt <= drdy_cnt + 1;
			if(test_cnt == 200_000_000)
				begin
					timout_sig <= 1;
					test_cnt <= 0;
					drdy_cnt <= 0;
				end
			else	
				begin
					timout_sig <= 0;
					test_cnt <= test_cnt + 1;
				end
		end
	
end

//The first stage of state machine
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
	begin
		state <= idle_state;
	end
	else
	begin
		state <= next_state;
	end
end
//The second stage of state machine
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
						if(enable)
							next_state <= wkup_state;
						else
							next_state <= next_state;
					end
			
				wkup_state:
					begin
						if(wkup_done)
							next_state <= reset_state;
						else
							next_state <= next_state;
					end
				
				reset_state:
					begin
						if(reset_done)
							next_state <= stopsend_state;
						else
							next_state <= next_state;
					end
				
				stopsend_state:
					begin
						if(stopsend_done && op_type == 2'h01)
							next_state <= op_write_state;
						else if(stopsend_done && op_type == 2'h02)
							next_state <= op_read_state;
						else if(stopsend_done)
							next_state <= config_state0;
						else
							next_state <= next_state;
					end
				
				config_state0:
					begin
						if(config_sig0)
							next_state <= config_state1;
						else
							next_state <= next_state;
					end

				config_state1:
					begin
						if(config_sig1)
							next_state <= config_state2;
						else
							next_state <= next_state;
					end
				
				config_state2:
					begin
						if(config_sig2)
							next_state <= config_state3;
						else
							next_state <= next_state;
					end		
				//Channels setting state
				config_state3:
					begin
						if(config_sig3)
							next_state <= config_state4;
						else
							next_state <= next_state;
					end			
				config_state4:
					begin
						if(config_sig4)
							next_state <= config_state5;
						else
							next_state <= next_state;
					end
				config_state5:
					begin
						if(config_sig5)
							next_state <= config_state6;
						else
							next_state <= next_state;
					end
				config_state6:
					begin
						if(config_sig6)
							next_state <= config_state7;
						else
							next_state <= next_state;
					end
				config_state7:
					begin
						if(config_sig7)
							next_state <= config_state8;
						else
							next_state <= next_state;
					end
				config_state8:
					begin
						if(config_sig8)
							next_state <= config_state9;
						else
							next_state <= next_state;
					end
				config_state9:
					begin
						if(config_sig9)
							next_state <= config_state10;
						else
							next_state <= next_state;
					end	
				config_state10:
					begin
						if(config_sig10)
							next_state <= config_state11;
						else
							next_state <= next_state;
					end	
				config_state11:
					begin
						if(config_sig11)
							next_state <= config_state12;
						else
							next_state <= next_state;
					end	
				config_state12:
					begin
						if(config_sig12)
							next_state <= config_state13;
						else
							next_state <= next_state;
					end
				config_state13:
					begin
						if(config_sig13)
							next_state <= start_state;
						else
							next_state <= next_state;
					end
				start_state:	
					begin
						if(start_done)
							next_state <= startsend_state;
						else
							next_state <= next_state;
					end
					
				startsend_state:
					begin
						if(startsend_done && enable)
							next_state <= read_state;
						else
							next_state <= next_state;
					end
				
				read_state:
					begin
						if((op_type == 2'h01 && read_done) || (op_type == 2'h02 && read_done))
							next_state <= stopsend_state;
						else
							next_state <= next_state;
					end
				
				op_write_state:
					begin
						if(op_write_done)
							next_state <= start_state;
						else
							next_state <= next_state;
					end
				
				op_read_state:
					begin
						if(op_read_done)
							next_state <= start_state;
						else
							next_state <= next_state;
					end
					
				default:
					begin
						next_state <= idle_state;
					end		
			endcase
			
		end
end
//The third stage of state machine
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		begin
			wkup_done <= 1'b0;
			counter <= 32'd0;
			reset_done <= 1'b0;
			stopsend_done <= 1'b0;
			wr_enable <= 1'b0;
			rd_enable <= 1'b0;
			finish_samp_r <= 1'b0;
			config_sig0 <= 1'b0;
			config_sig1 <= 1'b0;
			config_sig2 <= 1'b0;
			config_sig3 <= 1'b0; 
			config_sig4 <= 1'b0; 
			config_sig5 <= 1'b0; 
			config_sig6 <= 1'b0;
			config_sig7 <= 1'b0;
			config_sig8 <= 1'b0;
			config_sig9 <= 1'b0; 
			config_sig10 <= 1'b0; 
			config_sig11 <= 1'b0; 
			config_sig12 <= 1'b0;
			config_sig13 <= 1'b0;
			wr_byte <= 0;
			wr_data <= 0;
			SPI_nPWDN <= 0;
			wait_cs <= 1'b0;
			wr_num <= 0;
			delay_sig <= 0;
			rd_reg_cnt <= 0;
			start_done <= 0;
			startsend_done <= 0;
			read_done <=0;
			rd_sig <= 0;
			op_data_r <= 0;
			op_write_done <= 0;
			op_read_done <= 0;
		end
	
	else
		begin
			case(state)
				idle_state:
					begin
						counter <= 32'd0;
						SPI_nPWDN <= 1'b1;
						SPI_START <= 1'b0;
						SPI_nCS <= 8'hFF;
						SPI_nRST <= 1'b1;
						wkup_done <= 1'b0;
						reset_done <= 1'b0;
						finish_samp_r <= 1'b0;
						stopsend_done <= 1'b0;
						config_sig0 <= 1'b0;
						config_sig1 <= 1'b0;
						config_sig2 <= 1'b0;
						config_sig3 <= 1'b0; 
						config_sig4 <= 1'b0; 
						config_sig5 <= 1'b0; 
						config_sig6 <= 1'b0;
						config_sig7 <= 1'b0;
						config_sig8 <= 1'b0;
						config_sig9 <= 1'b0; 
						config_sig10 <= 1'b0; 
						config_sig11 <= 1'b0; 
						config_sig12 <= 1'b0;
						config_sig13 <= 1'b0;
						wr_enable <= 1'b0;
						wait_cs <= 1'b0;
						wr_num <= 0;
						delay_sig <= 0;
						rd_reg_cnt <= 0;
						start_done <= 0;
						startsend_done <= 0;
						read_done <=0;
						rd_sig <= 0;
					end
				
				wkup_state:
				begin
					if(counter < t_por) //(t_por>>16 for simulation only)
						begin
							counter <= counter + 1;
							wkup_done <= 1'b0;
						end
					else
						begin
							SPI_nRST <= 1'b0;
							counter <= 32'd0;
							wkup_done <= 1'b1;
						end
				end
			
				reset_state:
					begin
						if(counter < t_rst0)
							begin
								counter <= counter + 1;
								reset_done <= 1'b0;
							end
						else if(counter < t_rst1)
							begin
								SPI_nRST <= 1'b1;
								counter <= counter + 1;
								reset_done <= 1'b0;
							end
						else
							begin
								counter <= 32'd0;
								reset_done <= 1'b1;
								SPI_nCS <= 8'h0;
							end
					end
				
				stopsend_state: //SDATAC
					begin
						read_done <= 0;
						if(counter < t_rst0)
							begin
								stopsend_done <= 0;
								counter <= counter + 1;
							end
						else if(counter == t_rst0)
							begin
								// wait_cs <= 1;
								SPI_nCS <= 8'hFF;
								counter <= counter + 1;
							end
						else if(counter < 2*t_rst0)	
							begin
								counter <= counter + 1;
							end
						else if(counter == 2*t_rst0)
							begin
								counter <= counter + 1;
								SPI_nCS <= 0;
							end
						else if(counter < 3*t_rst0)	
							begin
								counter <= counter + 1;
							end					
						else if(finish_wr)
							begin
								stopsend_done <= 1;
								counter <= 0;
								wr_enable <= 0;
								wr_byte <= 0;
								wr_data <= 0;
							end
						else
							begin
								stopsend_done <= 0;
								wr_enable <= 1;
								wr_byte <= 1;
								wr_data <= 8'h11;
							end						
					end
				
				config_state0: // WR_REG: CONFIG1		(8'h01)  WR_DATA: 8'h96/250Hz sampling
					begin		
					stopsend_done <= 0;
						if(delay_sig && counter < 4*t_rst0)
							begin
								counter <= counter + 1;
							end
						else if(delay_sig)
							begin
								delay_sig <= 0;
							end
						else if(counter < t_rst0)
							begin
								counter <= counter + 1;
							end
						else if(counter == t_rst0)
							begin
								// wait_cs <= 1;
								SPI_nCS <= 8'hFF;
								counter <= counter + 1;
							end
						else if(counter < 2*t_rst0)	
							begin
								counter <= counter + 1;
							end
						else if(counter == 2*t_rst0)
							begin
								counter <= counter + 1;
								SPI_nCS <= 0;
							end
						else if(counter < 3*t_rst0)	
							begin
								counter <= counter + 1;
							end
						else if(wr_num == 4)
							begin
								config_sig0 <= 1;
								// config_sig0 <= 0;
								wr_enable <= 0;
								wr_byte <= 0;
								wr_data <= 0;
								SPI_nCS <= 8'h0;//
								counter <= 0;
								wr_num <= 0;
								delay_sig <= 0;
							end
						
						else if(finish_wr)
							begin
								counter <= 3*t_rst0 + 1;
								wr_num <= wr_num + 1;
								delay_sig <= 1;
								wr_enable <= 0;
								wr_byte <= 0;
								// wr_byte <= 3;
								wr_data <= 0;
							end
						else
							begin
								case(wr_num)
									config_bit0:
										begin
											SPI_nCS <= 8'h0;
											wr_enable <= 1'b1;
											// wr_byte <= 3;
											wr_byte <= 1;
											wr_data <= WR_REG_ADDR(8'h01) ;
											// wr_data <= 24'h120000;
											rd_enable <= 0;
										end
									config_bit1:
										begin
											wr_enable <= 1'b1;
											// wr_byte <= 3;
											wr_byte <= 1;
											wr_data <= 8'h00 ;
										end
									config_bit2:
										begin
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= 8'h96;
										end
									config_bit3:
										begin
											wr_enable <= 1'b1;
											wr_byte <= 1;
											// wr_byte <= 3;
											
											wr_data <= 0;
										end
									default:
										begin
											wr_enable <= 0;
										end
									endcase
							end
							

					end
				
				config_state1: // WR_REG: CONFIG2		(8'h02)  WR_DATA: 8'hD0
					begin		
						if(delay_sig && counter < 4*t_rst0)
							begin
								counter <= counter + 1;
							end
						else if(delay_sig)
							begin
								delay_sig <= 0;
							end
							
						else if(counter < t_rst0)
							begin
								counter <= counter + 1;
							end
						else if(counter == t_rst0)
							begin
								// wait_cs <= 1;
								SPI_nCS <= 8'hFF;
								counter <= counter + 1;
							end
						else if(counter < 2*t_rst0)	
							begin
								counter <= counter + 1;
							end
						else if(counter == 2*t_rst0)
							begin
								counter <= counter + 1;
								SPI_nCS <= 0;
							end
						else if(counter < 3*t_rst0)	
							begin
								counter <= counter + 1;
							end
						else if(wr_num == 4)
							begin
								config_sig1 <= 1;
								wr_enable <= 0;
								wr_byte <= 0;
								wr_data <= 0;
								SPI_nCS <= 8'h0;//
								counter <= 0;
								wr_num <= 0;
								delay_sig <= 0;
								// counter <= 1;
							end
						
						else if(finish_wr)
							begin
								counter <= 3*t_rst0 + 1;
								wr_num <= wr_num + 1;
								delay_sig <= 1;
								wr_enable <= 0;
								wr_byte <= 0;
								wr_data <= 0;
							end
						else
							begin
								case(wr_num)
									config_bit0:
										begin
											SPI_nCS <= 8'h0;
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= WR_REG_ADDR(8'h02) ;
											rd_enable <= 0;
										end
									config_bit1:
										begin
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= 8'h00 ;
										end
									config_bit2:
										begin
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= 8'hD0;
										end
									config_bit3:
										begin
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= 0;
										end
									default:
										begin
											wr_enable <= 0;
										end
									endcase
							end
					end
				
				config_state2: // WR_REG: CONFIG3		(8'h03)  WR_DATA: 8'hEC
					begin		
						if(delay_sig && counter < 4*t_rst0)
							begin
								counter <= counter + 1;
							end
						else if(delay_sig)
							begin
								delay_sig <= 0;
							end
						
						else if(counter < t_rst0)
							begin
								counter <= counter + 1;
							end
						else if(counter == t_rst0)
							begin
								// wait_cs <= 1;
								SPI_nCS <= 8'hFF;
								counter <= counter + 1;
							end
						else if(counter < 2*t_rst0)	
							begin
								counter <= counter + 1;
							end
						else if(counter == 2*t_rst0)
							begin
								counter <= counter + 1;
								SPI_nCS <= 0;
							end
						else if(counter < 3*t_rst0)	
							begin
								counter <= counter + 1;
							end
						else if(wr_num == 4)
							begin
								config_sig2 <= 1;
								wr_enable <= 0;
								wr_byte <= 0;
								wr_data <= 0;
								SPI_nCS <= 8'h0;//
								counter <= 0;
								wr_num <= 0;
								delay_sig <= 0;
								// counter <= 1;
							end
						
						else if(finish_wr)
							begin
								counter <= 3*t_rst0 + 1;
								wr_num <= wr_num + 1;
								delay_sig <= 1;
								wr_enable <= 0;
								wr_byte <= 0;
								wr_data <= 0;
							end
						else
							begin
								case(wr_num)
									config_bit0:
										begin
											SPI_nCS <= 8'h0;
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= WR_REG_ADDR(8'h03) ;
											rd_enable <= 0;
										end
									config_bit1:
										begin
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= 8'h00 ;
										end
									config_bit2:
										begin
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= 8'hEC;
										end
									config_bit3:
										begin
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= 0;
										end
										
									default:
										begin
											wr_enable <= 0;
										end
									endcase
							end
					end
				//Channels settings
				config_state3: // WR_REG: CH1SET				(8'h05)  WR_DATA: 8'h08//test signal
					begin		
						if(delay_sig && counter < 4*t_rst0)
							begin
								counter <= counter + 1;
							end
						else if(delay_sig)
							begin
								delay_sig <= 0;
							end
						else if(counter < t_rst0)
							begin
								counter <= counter + 1;
							end
						else if(counter == t_rst0)
							begin
								// wait_cs <= 1;
								SPI_nCS <= 8'hFF;
								counter <= counter + 1;
							end
						else if(counter < 2*t_rst0)	
							begin
								counter <= counter + 1;
							end
						else if(counter == 2*t_rst0)
							begin
								counter <= counter + 1;
								SPI_nCS <= 0;
							end
						else if(counter < 3*t_rst0)	
							begin
								counter <= counter + 1;
							end
						else if(wr_num == 4)
							begin
								config_sig3 <= 1;
								wr_enable <= 0;
								wr_byte <= 0;
								wr_data <= 0;
								SPI_nCS <= 8'h0;//
								counter <= 0;
								wr_num <= 0;
								delay_sig <= 0;
								// counter <= 1;
							end
						else if(finish_wr)
							begin
								counter <= 3*t_rst0 + 1;
								wr_num <= wr_num + 1;
								delay_sig <= 1;
								wr_enable <= 0;
								wr_byte <= 0;
								wr_data <= 0;
							end
						else
							begin
								case(wr_num)
									config_bit0:
										begin
											SPI_nCS <= 8'h0;
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= WR_REG_ADDR(8'h05) ;//05
											rd_enable <= 0;
										end
									config_bit1:
										begin
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= 8'h01 ;
										end
									config_bit2:
										begin
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= 8'h08;//normal electrode:8'h00; Test signal is 8'h05;
										end
									config_bit3:
										begin
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= 0;
										end
									default:
										begin
											wr_enable <= 0;
										end
									endcase
							end
					end
				config_state4: // WR_REG: CH2SET			(8'h06)  WR_DATA: 8'h08// MVDD = AVDD/2
					begin		
						if(delay_sig && counter < 4*t_rst0)
							begin
								counter <= counter + 1;
							end
						else if(delay_sig)
							begin
								delay_sig <= 0;
							end
						
						else if(counter < t_rst0)
							begin
								counter <= counter + 1;
							end
						else if(counter == t_rst0)
							begin
								// wait_cs <= 1;
								SPI_nCS <= 8'hFF;
								counter <= counter + 1;
							end
						else if(counter < 2*t_rst0)	
							begin
								counter <= counter + 1;
							end
						else if(counter == 2*t_rst0)
							begin
								counter <= counter + 1;
								SPI_nCS <= 0;
							end
						else if(counter < 3*t_rst0)	
							begin
								counter <= counter + 1;
							end
						else if(wr_num == 4)
							begin
								config_sig4 <= 1;
								wr_enable <= 0;
								wr_byte <= 0;
								wr_data <= 0;
								SPI_nCS <= 8'h0;//
								counter <= 0;
								wr_num <= 0;
								delay_sig <= 0;
								// counter <= 1;
							end
						
						else if(finish_wr)
							begin
								counter <= 3*t_rst0 + 1;
								wr_num <= wr_num + 1;
								delay_sig <= 1;
								wr_enable <= 0;
								wr_byte <= 0;
								wr_data <= 0;
							end
						else
							begin
								case(wr_num)
									config_bit0:
										begin
											SPI_nCS <= 8'h0;
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= WR_REG_ADDR(8'h06) ;
											rd_enable <= 0;
										end
									config_bit1:
										begin
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= 8'h01 ;
										end
									config_bit2:
										begin
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= 8'h08 ;//normal electrode:8'h00; Test signal is 8'h05;
										end
									config_bit3:
										begin
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= 0;
										end
									default:
										begin
											wr_enable <= 0;
										end
									endcase
							end
					end
				config_state5: // WR_REG: CH3SET			(8'h07)  WR_DATA: 8'h08
					begin		
						if(delay_sig && counter < 4*t_rst0)
							begin
								counter <= counter + 1;
							end
						else if(delay_sig)
							begin
								delay_sig <= 0;
							end
						
						else if(counter < t_rst0)
							begin
								counter <= counter + 1;
							end
						else if(counter == t_rst0)
							begin
								// wait_cs <= 1;
								SPI_nCS <= 8'hFF;
								counter <= counter + 1;
							end
						else if(counter < 2*t_rst0)	
							begin
								counter <= counter + 1;
							end
						else if(counter == 2*t_rst0)
							begin
								counter <= counter + 1;
								SPI_nCS <= 0;
							end
						else if(counter < 3*t_rst0)	
							begin
								counter <= counter + 1;
							end
						else if(wr_num == 4)
							begin
								config_sig5 <= 1;
								wr_enable <= 0;
								wr_byte <= 0;
								wr_data <= 0;
								SPI_nCS <= 8'h0;//
								counter <= 0;
								wr_num <= 0;
								delay_sig <= 0;
								// counter <= 1;
							end
						
						else if(finish_wr)
							begin
								counter <= 3*t_rst0 + 1;
								wr_num <= wr_num + 1;
								delay_sig <= 1;
								wr_enable <= 0;
								wr_byte <= 0;
								wr_data <= 0;
							end
						else
							begin
								case(wr_num)
									config_bit0:
										begin
											SPI_nCS <= 8'h0;
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= WR_REG_ADDR(8'h07) ;
											rd_enable <= 0;
										end
									config_bit1:
										begin
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= 8'h01 ;
										end
									config_bit2:
										begin
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= 8'h08;//normal electrode:8'h00; Test signal is 8'h05;
										end
									config_bit3:
										begin
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= 0;
										end
									default:
										begin
											wr_enable <= 0;
										end
									endcase
							end
					end
				config_state6: // WR_REG: CH4SET			(8'h08)  WR_DATA: 8'h08
					begin
						if(delay_sig && counter < 4*t_rst0)
							begin
								counter <= counter + 1;
							end
						else if(delay_sig)
							begin
								delay_sig <= 0;
							end
						
						else if(counter < t_rst0)
							begin
								counter <= counter + 1;
							end
						else if(counter == t_rst0)
							begin
								// wait_cs <= 1;
								SPI_nCS <= 8'hFF;
								counter <= counter + 1;
							end
						else if(counter < 2*t_rst0)	
							begin
								counter <= counter + 1;
							end
						else if(counter == 2*t_rst0)
							begin
								counter <= counter + 1;
								SPI_nCS <= 0;
							end
						else if(counter < 3*t_rst0)	
							begin
								counter <= counter + 1;
							end
						else if(wr_num == 4)
							begin
								config_sig6 <= 1;
								wr_enable <= 0;
								wr_byte <= 0;
								wr_data <= 0;
								SPI_nCS <= 8'h0;//
								counter <= 0;
								wr_num <= 0;
								delay_sig <= 0;
								// counter <= 1;
							end
						
						else if(finish_wr)
							begin
								counter <= 3*t_rst0 + 1;
								wr_num <= wr_num + 1;
								delay_sig <= 1;
								wr_enable <= 0;
								wr_byte <= 0;
								wr_data <= 0;
							end
						else
							begin
								case(wr_num)
									config_bit0:
										begin
											SPI_nCS <= 8'h0;
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= WR_REG_ADDR(8'h08) ;
											rd_enable <= 0;
										end
									config_bit1:
										begin
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= 8'h01 ;
										end
									config_bit2:
										begin
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= 8'h08;//normal electrode:8'h00; Test signal is 8'h05;
										end
									config_bit3:
										begin
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= 0;
										end
									default:
										begin
											wr_enable <= 0;
										end
									endcase
							end						
					end
				config_state7: // WR_REG: CH5SET			(8'h09)  WR_DATA: 8'h08
					begin
						if(delay_sig && counter < 4*t_rst0)
							begin
								counter <= counter + 1;
							end
						else if(delay_sig)
							begin
								delay_sig <= 0;
							end
						else if(counter < t_rst0)
							begin
								counter <= counter + 1;
							end
						else if(counter == t_rst0)
							begin
								// wait_cs <= 1;
								SPI_nCS <= 8'hFF;
								counter <= counter + 1;
							end
						else if(counter < 2*t_rst0)	
							begin
								counter <= counter + 1;
							end
						else if(counter == 2*t_rst0)
							begin
								counter <= counter + 1;
								SPI_nCS <= 0;
							end
						else if(counter < 3*t_rst0)	
							begin
								counter <= counter + 1;
							end
						else if(wr_num == 4)
							begin
								config_sig7 <= 1;
								wr_enable <= 0;
								wr_byte <= 0;
								wr_data <= 0;
								SPI_nCS <= 8'h0;//
								counter <= 0;
								wr_num <= 0;
								delay_sig <= 0;
								// counter <= 1;
							end
						else if(finish_wr)
							begin
								counter <= 3*t_rst0 + 1;
								wr_num <= wr_num + 1;
								delay_sig <= 1;
								wr_enable <= 0;
								wr_byte <= 0;
								wr_data <= 0;
							end
						else
							begin
								case(wr_num)
									config_bit0:
										begin
											SPI_nCS <= 8'h0;
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= WR_REG_ADDR(8'h09) ;
											rd_enable <= 0;
										end
									config_bit1:
										begin
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= 8'h01 ;
										end
									config_bit2:
										begin
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= 8'h08;//normal electrode:8'h00; Test signal is 8'h05;
										end
									config_bit3:
										begin
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= 0;
										end
									default:
										begin
											wr_enable <= 0;
										end
									endcase
							end
					end	
				config_state8: // WR_REG: CH6SET			(8'h0A)  WR_DATA: 8'h08
					begin
						if(delay_sig && counter < 4*t_rst0)
							begin
								counter <= counter + 1;
							end
						else if(delay_sig)
							begin
								delay_sig <= 0;
							end
						else if(counter < t_rst0)
							begin
								counter <= counter + 1;
							end
						else if(counter == t_rst0)
							begin
								// wait_cs <= 1;
								SPI_nCS <= 8'hFF;
								counter <= counter + 1;
							end
						else if(counter < 2*t_rst0)	
							begin
								counter <= counter + 1;
							end
						else if(counter == 2*t_rst0)
							begin
								counter <= counter + 1;
								SPI_nCS <= 0;
							end
						else if(counter < 3*t_rst0)	
							begin
								counter <= counter + 1;
							end
						else if(wr_num == 4)
							begin
								config_sig8 <= 1;
								wr_enable <= 0;
								wr_byte <= 0;
								wr_data <= 0;
								SPI_nCS <= 8'h0;//
								counter <= 0;
								wr_num <= 0;
								delay_sig <= 0;
								// counter <= 1;
							end
						else if(finish_wr)
							begin
								counter <= 3*t_rst0 + 1;
								wr_num <= wr_num + 1;
								delay_sig <= 1;
								wr_enable <= 0;
								wr_byte <= 0;
								wr_data <= 0;
							end
						else
							begin
								case(wr_num)
									config_bit0:
										begin
											SPI_nCS <= 8'h0;
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= WR_REG_ADDR(8'h0A) ;
											rd_enable <= 0;
										end
									config_bit1:
										begin
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= 8'h01 ;
										end
									config_bit2:
										begin
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= 8'h08;//normal electrode:8'h00; Test signal is 8'h05;
										end
									config_bit3:
										begin
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= 0;
										end
									default:
										begin
											wr_enable <= 0;
										end
									endcase
							end
					end
				config_state9: // WR_REG: CH7SET			(8'h0B)  WR_DATA: 8'h08
					begin
						if(delay_sig && counter < 4*t_rst0)
							begin
								counter <= counter + 1;
							end
						else if(delay_sig)
							begin
								delay_sig <= 0;
							end
						else if(counter < t_rst0)
							begin
								counter <= counter + 1;
							end
						else if(counter == t_rst0)
							begin
								// wait_cs <= 1;
								SPI_nCS <= 8'hFF;
								counter <= counter + 1;
							end
						else if(counter < 2*t_rst0)	
							begin
								counter <= counter + 1;
							end
						else if(counter == 2*t_rst0)
							begin
								counter <= counter + 1;
								SPI_nCS <= 0;
							end
						else if(counter < 3*t_rst0)	
							begin
								counter <= counter + 1;
							end
						else if(wr_num == 4)
							begin
								config_sig9 <= 1;
								wr_enable <= 0;
								wr_byte <= 0;
								wr_data <= 0;
								SPI_nCS <= 8'h0;//
								counter <= 0;
								wr_num <= 0;
								delay_sig <= 0;
								// counter <= 1;
							end
						else if(finish_wr)
							begin
								counter <= 3*t_rst0 + 1;
								wr_num <= wr_num + 1;
								delay_sig <= 1;
								wr_enable <= 0;
								wr_byte <= 0;
								wr_data <= 0;
							end
						else
							begin
								case(wr_num)
									config_bit0:
										begin
											SPI_nCS <= 8'h0;
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= WR_REG_ADDR(8'h0B) ;
											rd_enable <= 0;
										end
									config_bit1:
										begin
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= 8'h01 ;
										end
									config_bit2:
										begin
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= 8'h08;//normal electrode:8'h00; Test signal is 8'h05;
										end
									config_bit3:
										begin
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= 0;
										end
									default:
										begin
											wr_enable <= 0;
										end
									endcase
							end
					end
				config_state10:// WR_REG: CH8SET			(8'h0C)  WR_DATA: 8'h08
					begin
						if(delay_sig && counter < 4*t_rst0)
							begin
								counter <= counter + 1;
							end
						else if(delay_sig)
							begin
								delay_sig <= 0;
							end
						else if(counter < t_rst0)
							begin
								counter <= counter + 1;
							end
						else if(counter == t_rst0)
							begin
								// wait_cs <= 1;
								SPI_nCS <= 8'hFF;
								counter <= counter + 1;
							end
						else if(counter < 2*t_rst0)	
							begin
								counter <= counter + 1;
							end
						else if(counter == 2*t_rst0)
							begin
								counter <= counter + 1;
								SPI_nCS <= 0;
							end
						else if(counter < 3*t_rst0)	
							begin
								counter <= counter + 1;
							end
						else if(wr_num == 4)
							begin
								config_sig10 <= 1;
								wr_enable <= 0;
								wr_byte <= 0;
								wr_data <= 0;
								SPI_nCS <= 8'h0;//
								counter <= 0;
								wr_num <= 0;
								delay_sig <= 0;
								// counter <= 1;
							end
						else if(finish_wr)
							begin
								counter <= 3*t_rst0 + 1;
								wr_num <= wr_num + 1;
								delay_sig <= 1;
								wr_enable <= 0;
								wr_byte <= 0;
								wr_data <= 0;
							end
						else
							begin
								case(wr_num)
									config_bit0:
										begin
											SPI_nCS <= 8'h0;
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= WR_REG_ADDR(8'h0C) ;
											rd_enable <= 0;
										end
									config_bit1:
										begin
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= 8'h01 ;
										end
									config_bit2:
										begin
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= 8'h08;//normal electrode:8'h00; Test signal is 8'h05;
										end
									config_bit3:
									begin
										wr_enable <= 1'b1;
										wr_byte <= 1;
										wr_data <= 8'h0;
									end
									default:
										begin
											wr_enable <= 0;
										end
									endcase
							end
					end
				//Special register config
				config_state11:// WR_REG: BIAS_SENSN	(8'h0E)  WR_DATA: 8'hFF
					begin
						if(delay_sig && counter < 4*t_rst0)
							begin
								counter <= counter + 1;
							end
						else if(delay_sig)
							begin
								delay_sig <= 0;
							end
						else if(counter < t_rst0)
							begin
								counter <= counter + 1;
							end
						else if(counter == t_rst0)
							begin
								// wait_cs <= 1;
								SPI_nCS <= 8'hFF;
								counter <= counter + 1;
							end
						else if(counter < 2*t_rst0)	
							begin
								counter <= counter + 1;
							end
						else if(counter == 2*t_rst0)
							begin
								counter <= counter + 1;
								SPI_nCS <= 0;
							end
						else if(counter < 3*t_rst0)	
							begin
								counter <= counter + 1;
							end
						else if(wr_num == 4)
							begin
								config_sig11 <= 1;
								wr_enable <= 0;
								wr_byte <= 0;
								wr_data <= 0;
								SPI_nCS <= 8'h0;//
								counter <= 0;
								wr_num <= 0;
								delay_sig <= 0;
								// counter <= 1;
							end
						else if(finish_wr)
							begin
								counter <= 3*t_rst0 + 1;
								wr_num <= wr_num + 1;
								delay_sig <= 1;
								wr_enable <= 0;
								wr_byte <= 0;
								wr_data <= 0;
							end
						else
							begin
								case(wr_num)
									config_bit0:
										begin
											SPI_nCS <= 8'h0;
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= WR_REG_ADDR(8'h0E) ;
											rd_enable <= 0;
										end
									config_bit1:
										begin
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= 8'h01 ;
										end
									config_bit2:
										begin
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= 8'hFF;
										end
									config_bit3:
										begin
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= 8'h0;
										end
									default:
										begin
											wr_enable <= 0;
										end
									endcase
							end
					end
				config_state12:// WR_REG: BIAS_SENSP  	(8'h0D)  WR_DATA: 8'hFF
					begin
					
						if(delay_sig && counter < 4*t_rst0)
							begin
								counter <= counter + 1;
							end
						else if(delay_sig)
							begin
								delay_sig <= 0;
							end
						
						else if(counter < t_rst0)
							begin
								counter <= counter + 1;
							end
						else if(counter == t_rst0)
							begin
								// wait_cs <= 1;
								SPI_nCS <= 8'hFF;
								counter <= counter + 1;
							end
						else if(counter < 2*t_rst0)	
							begin
								counter <= counter + 1;
							end
						else if(counter == 2*t_rst0)
							begin
								counter <= counter + 1;
								SPI_nCS <= 0;
							end
						else if(counter < 3*t_rst0)	
							begin
								counter <= counter + 1;
							end
						else if(wr_num == 4)
							begin
								config_sig12 <= 1;
								wr_enable <= 0;
								wr_byte <= 0;
								wr_data <= 0;
								SPI_nCS <= 8'h0;//
								counter <= 0;
								wr_num <= 0;
								delay_sig <= 0;
								// counter <= 1;
							end
						
						else if(finish_wr)
							begin
								counter <= 3*t_rst0 + 1;
								wr_num <= wr_num + 1;
								delay_sig <= 1;
								wr_enable <= 0;
								wr_byte <= 0;
								wr_data <= 0;
							end
						else
							begin
								case(wr_num)
									config_bit0:
										begin
											SPI_nCS <= 8'h0;
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= WR_REG_ADDR(8'h0D) ;
											rd_enable <= 0;
										end
									config_bit1:
										begin
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= 8'h01 ;
										end
									config_bit2:
										begin
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= 8'hFF ;
										end
									config_bit3:
										begin
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= 8'h0;
										end
									default:
										begin
											wr_enable <= 0;
										end
									endcase
							end
							
					end
				config_state13://	WR_REG: MISC1 				(8'h15)   WR_DATA: 8'h0
					begin
						if(delay_sig && counter < 4*t_rst0)
							begin
								counter <= counter + 1;
							end
						else if(delay_sig)
							begin
								delay_sig <= 0;
							end
						else if(counter < t_rst0)
							begin
								counter <= counter + 1;
							end
						else if(counter == t_rst0)
							begin
								SPI_nCS <= 8'hFF;
								counter <= counter + 1;
							end
						else if(counter < 2*t_rst0)	
							begin
								counter <= counter + 1;
							end
						else if(counter == 2*t_rst0)
							begin
								counter <= counter + 1;
								SPI_nCS <= 0;
							end
						else if(counter < 3*t_rst0)	
							begin
								counter <= counter + 1;
							end
						else if(wr_num == 4)
							begin
								config_sig13 <= 1;
								wr_enable <= 0;
								wr_byte <= 0;
								wr_data <= 0;
								SPI_nCS <= 8'h0;//
								counter <= 0;
								wr_num <= 0;
								delay_sig <= 0;
							end
						else if(finish_wr)
							begin
								counter <= 3*t_rst0 + 1;
								wr_num <= wr_num + 1;
								delay_sig <= 1;
								wr_enable <= 0;
								wr_byte <= 0;
								wr_data <= 0;
							end
						else
							begin
								case(wr_num)
									config_bit0:
										begin
											SPI_nCS <= 8'h0;
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= WR_REG_ADDR(8'h15) ;
											rd_enable <= 0;
										end
									config_bit1:
										begin
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= 8'h01 ;
										end
									config_bit2:
										begin
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= 8'h00;
										end
									config_bit3:
										begin
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= 8'h0;
										end
									default:
										begin
											wr_enable <= 0;
										end
									endcase
							end
						// config_sig13 <= 1;
					end
				start_state:
					begin
						if(counter <= t_start)
							begin
								SPI_nCS <= 8'hFF;
								counter <= counter + 1;
								SPI_START <= 0;
								start_done <= 0;
							end
						else
							begin
								counter <= 0;
								SPI_START <= 1;
								start_done <= 1;
							end
					end
				
				startsend_state://send RDATA command
					begin
						
						if(counter < t_rst0)
							begin
								counter <= counter + 1;
							end
						else if(counter == t_rst0)
							begin
								// wait_cs <= 1;
								op_write_done <= 0;
								op_read_done  <= 0;
								SPI_nCS <= 8'hFF;
								SPI_START <= 1;
								counter <= counter + 1;
							end
						else if(counter < 2*t_rst0)	
							begin
								counter <= counter + 1;
							end
						else if(counter == 2*t_rst0)
							begin
								counter <= counter + 1;
								SPI_nCS <= 0;
							end
						else if(counter < 3*t_rst0)	
							begin
								counter <= counter + 1;
							end
						
						else if(finish_wr)
							begin
								// rd_sig <= 1;
								SPI_START <= 1;
								startsend_done <= 1;
								// SPI_nCS <= 8'hFF;
								wr_enable <= 0;
								wr_byte <= 0;
								wr_data <= 0;
								rd_enable <= 0;
								counter <= 0;
								// finish_samp_r <= 0;
							end
						else	
							begin
								SPI_START <= 1;
								SPI_nCS <= 8'h00;
								wr_enable <= 1;
								wr_byte <= 1;
								// wr_data <= 8'h12;//RDATA
								wr_data <= 8'h10;
								rd_enable <= 0;
							end
						
						// else
							// begin
								// SPI_START <= 1;
								// wr_enable <= 0;
								// rd_enable <= 1;
							// end
					end
				
				read_state:
					begin
						startsend_done <= 0;
						
							if(counter < t_rst0)
							begin
								counter <= counter + 1;
							end
						else if(counter == t_rst0)
							begin
								// wait_cs <= 1;
								SPI_nCS <= 8'hFF;
								SPI_START <= 1;
								counter <= counter + 1;
							end
						else if(counter < 2*t_rst0)	
							begin
								counter <= counter + 1;
							end
						else if(counter == 2*t_rst0 && rd_sig)
							begin
								counter <= counter + 1;
								SPI_nCS <= 0;
							end
						else if(counter < 3*t_rst0 && rd_sig)	
							begin
								counter <= counter + 1;
								rd_enable <= 1;
							end
						else if((op_type == 2'h01 && finish_rd) || (op_type ==2'h02 && finish_rd))
							begin
								rd_enable <= 0;
								finish_samp_r <= 1'b1;
								read_done <= 1;
								counter <= 0;
								rd_sig <= 0;
								SPI_nCS <= 8'hFF;
							end
						else if(finish_rd)
							begin
								rd_enable <= 0;
								finish_samp_r <= 1'b1;
								read_done <= 1;//need to be edited
								// SPI_nCS <= 8'hFF;
								counter <= 2*t_rst0;
								rd_sig <= 0;
							end
						// else if(SPI_nDRDY[0] == 0)
						else if(drdy_neg)
							begin
								SPI_nCS <= 8'h00;
								// rd_enable <= 1;
								rd_enable <= 0;
								// counter <= 0;
								rd_sig <= 1;
								read_done <= 0;
							end
						else
							begin
								// rd_sig <= 0;
								// counter <= 0;
								finish_samp_r <= 0;
								// rd_enable <= 1;
								read_done <= 0;
							end
					end
				
				op_write_state:
					begin
						stopsend_done <= 0;
						if(delay_sig && counter < 4*t_rst0)
							begin
								counter <= counter + 1;
							end
						else if(delay_sig)
							begin
								delay_sig <= 0;
							end
						else if(counter < t_rst0)
							begin
								counter <= counter + 1;
							end
						else if(counter == t_rst0)
							begin
								SPI_nCS <= 8'hFF;
								counter <= counter + 1;
							end
						else if(counter < 2*t_rst0)	
							begin
								counter <= counter + 1;
							end
						else if(counter == 2*t_rst0)
							begin
								counter <= counter + 1;
								SPI_nCS <= 0;
							end
						else if(counter < 3*t_rst0)	
							begin
								counter <= counter + 1;
							end
						else if(wr_num == 4)
							begin
								op_write_done <= 1;
								wr_enable <= 0;
								wr_byte <= 0;
								wr_data <= 0;
								SPI_nCS <= 8'h0;//
								counter <= 0;
								wr_num <= 0;
								delay_sig <= 0;
							end
						else if(finish_wr)
							begin
								counter <= 3*t_rst0 + 1;
								wr_num <= wr_num + 1;
								delay_sig <= 1;
								wr_enable <= 0;
								wr_byte <= 0;
								wr_data <= 0;
							end
						else
							begin
								case(wr_num)
									config_bit0:
										begin
											SPI_nCS <= 8'h0;
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= WR_REG_ADDR(op_reg) ;
											rd_enable <= 0;
										end
									config_bit1:
										begin
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= 8'h01 ;
										end
									config_bit2:
										begin
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= op_data_i;
										end
									config_bit3:
										begin
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= 8'h0;
										end
									default:
										begin
											wr_enable <= 0;
										end
									endcase
							end
					end
				
				op_read_state:
					begin
					stopsend_done <= 0;
						if(delay_sig && counter < 4*t_rst0)
							begin
								counter <= counter + 1;
							end
						else if(delay_sig)
							begin
								delay_sig <= 0;
							end
						else if(counter < t_rst0)
							begin
								counter <= counter + 1;
							end
						else if(counter == t_rst0)
							begin
								SPI_nCS <= 8'hFF;
								counter <= counter + 1;
							end
						else if(counter < 2*t_rst0)	
							begin
								counter <= counter + 1;
							end
						else if(counter == 2*t_rst0)
							begin
								counter <= counter + 1;
								SPI_nCS <= 0;
							end
						else if(counter < 3*t_rst0)	
							begin
								counter <= counter + 1;
							end
						else if(finish_rd)
							begin
								op_read_done <= 1;
								wr_enable <= 0;
								wr_byte <= 0;
								wr_data <= 0;
								SPI_nCS <= 8'h0;//
								counter <= 0;
								wr_num <= 0;
								delay_sig <= 0;
								rd_enable <= 0;
								op_data_r <= bci_data[1727:1720];
							end
						// else if(wr_num == 3)
							// begin
								//
								// wr_enable <= 0;
								// wr_byte <= 0;
								// wr_data <= 0;
								// SPI_nCS <= 8'h0;//
								// counter <= 0;
								// wr_num <= 0;
								// delay_sig <= 0;
								// rd_enable <= 0;
							// end
						else if(finish_wr)
							begin
								counter <= 3*t_rst0 + 1;
								wr_num <= wr_num + 1;
								delay_sig <= 1;
								wr_enable <= 0;
								wr_byte <= 0;
								wr_data <= 0;
							end
						else
							begin
								case(wr_num)
									config_bit0:
										begin
											SPI_nCS <= 8'h0;
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= RD_REG_ADDR(op_reg) ;
											rd_enable <= 0;
										end
									config_bit1:
										begin
											wr_enable <= 1'b1;
											wr_byte <= 1;
											wr_data <= 8'h01 ;
											rd_enable <= 0;
										end
									config_bit2:
										begin
											wr_enable <= 1'b0;
											wr_byte <= 0;
											rd_enable <= 1;
										end
									// config_bit3:
										// begin
											// wr_enable <= 1'b1;
											// wr_byte <= 1;
											// wr_data <= 8'h0;
										// end
									default:
										begin
											wr_enable <= 0;
										end
									endcase
							end
					end
				
				default:
					begin
					
					end
					
			endcase
		end
end

function [7:0] WR_REG_ADDR;
input [7:0] addr;
	begin
		WR_REG_ADDR = {addr | 8'h40};
	end
endfunction

function [7:0] RD_REG_ADDR;
input [7:0] addr;
	begin
		RD_REG_ADDR = {addr | 8'h20};
	end
endfunction
// endfunction

ads1299_driver 
#( .spi_clk_freq(5_000_000))
ADS1299_0
(
	.clk						(clk),
	.rst_n					(rst_n),
    .SPI_MISO			(SPI_MISO[0]),
    .SPI_nDRDY			(SPI_nDRDY[0]),
	.wr_enable			(wr_enable),
	.wr_byte				(wr_byte),
	.wr_data				(wr_data),
	.rd_enable			(rd_enable),
	
    .SPI_MOSI					(SPI_MOSI[0]),
   // .SPI_nCS						(SPI_nCS[0]),
	.finish_wr					(finish_wr),
	.finish_rd						(finish_rd),
	.SPI_CLK						(SPI_CLK),
	.eeg_data						(eeg_data[0])
    );

genvar i;
generate 
	for(i=1;i<8;i=i+1)
		begin: ads1299_inst
			ads1299_driver
			#( .spi_clk_freq(5_000_000))
			ADS1299_inst
			(
				.clk						(clk),
				.rst_n					(rst_n),
				.SPI_MISO			(SPI_MISO[i]),
				.SPI_nDRDY			(SPI_nDRDY[i]),
				.wr_enable			(wr_enable),
				.wr_byte				(wr_byte),
				.wr_data				(wr_data),
				.rd_enable			(rd_enable),
				
				.SPI_MOSI					(SPI_MOSI[i]),
			   // .SPI_nCS						(SPI_nCS[0]),
				.finish_wr					(),
				.finish_rd						(),
				.eeg_data						(eeg_data[i])
				);
		end
endgenerate

endmodule
