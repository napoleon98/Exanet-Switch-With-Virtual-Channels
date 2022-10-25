`timescale 1ns/1ns
`include "ceiling_up_log2.vh"
module exa_crosb_mux #(
	parameter integer data_width        = 128,
	parameter integer input_num         = 16,
	parameter integer sel_width         = `log2(input_num)
)(
  input                                  clk,
  input                                  resetn,
  input [data_width-1 :0]                DATA_i[input_num-1:0],
  input [input_num-1 : 0]                VALID_i,
  input [input_num-1 : 0]                LAST_i,
  //input [input_num-1 : 0]                PRIO_i,
  input [input_num-1 : 0]                CTS_FROM_INPUT_ARBITER_i,

  input [sel_width-1 :0]                 SEL_i,

  output reg[data_width-1 : 0]           DATA_o,
  output reg                             VALID_o,
  output reg                             LAST_o,
  //output reg                             PRIO_o,
  output reg                             CTS_FROM_INPUT_ARBITER_o
);

	
  wire [127:0] channel_selected [input_num-1 : 0];   
  genvar i; 

  generate  
    for(i=0; i<input_num; i=i+1) begin: fifo_channels       
      assign  channel_selected[i] = DATA_i[i];   
    end    
  endgenerate   

  assign DATA_o     = channel_selected[SEL_i]; 
  assign VALID_o    = VALID_i[SEL_i];
  assign LAST_o     = LAST_i[SEL_i];
  //assign PRIO_o     = PRIO_i[SEL_i];
  assign CTS_FROM_INPUT_ARBITER_o = CTS_FROM_INPUT_ARBITER_i[SEL_i];
	
	
	
	
endmodule