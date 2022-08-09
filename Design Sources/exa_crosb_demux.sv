`timescale 1ns/1ns
`include "ceiling_up_log2.vh"

module exa_crosb_demux #(
	parameter integer data_width        = 128,
	parameter integer output_num        = 16,
	parameter integer sel_width         = `log2(output_num)
	)
(
	input [data_width-1 :0]                DATA_i,
	input                                  VALID_i,
	input                                  LAST_i,
	input                                  PRIO_i,
	input                                  CTS_FROM_INPUT_ARBITER_i,
	input [sel_width-1 :0]                 SEL_i,
	output reg[data_width-1 : 0]           DATA_o [output_num-1:0],
	output reg[output_num-1 : 0]           VALID_o,
	output reg[output_num-1 : 0]           LAST_o,
	output reg[output_num-1 : 0]           PRIO_o,
	output reg[output_num-1 : 0]           CTS_FROM_INPUT_ARBITER_o
	);
	
	
	integer i;
	
	always_comb begin
	   for (i = 0 ; i < output_num ; i = i+1 ) begin
	       if (SEL_i == i) begin
	           DATA_o[i] = DATA_i;
	           VALID_o[i]= VALID_i;
	           LAST_o[i] = LAST_i;
	           PRIO_o[i] = PRIO_i;
	           CTS_FROM_INPUT_ARBITER_o[i] = CTS_FROM_INPUT_ARBITER_i;
	       end
	       else begin
	           DATA_o[i] = 0;
	           VALID_o[i]= 0; 
	           LAST_o[i] = 0;
	           PRIO_o[i] = 0;
	           CTS_FROM_INPUT_ARBITER_o[i] = 0;
	       end    
	   end
	end
	
	endmodule