`timescale 1ns / 1ps

module exa_crosb_crosb_with_VCs#(
  parameter integer data_width        = 128,
  parameter integer prio_num          = 2,
  parameter integer input_num         = 2,
  parameter integer vc_num            = 2,
  parameter integer in_sel_width      = $clog2(input_num),
  parameter integer output_num        = 2,
  parameter integer out_sel_width     = $clog2(output_num),
  parameter DEBUG                     = "false"

)(
  
  input                                 clk,
  input                                resetn,
    
  AXIS.slave                           S_AXIS[input_num-1:0],
  AXIS.master                          M_AXIS[output_num-1:0],
  input [vc_num*prio_num-1:0]          i_output_fifo_credits [output_num-1:0],
  input [$clog2(vc_num*prio_num)-1:0]  i_output_vc[input_num-1:0][vc_num*prio_num-1:0],/**each axi stream should have an output vc in which the stream will get in at output*/
                                                                 
  //input [$clog2(vc_num*prio_num)-1:0]  i_input_vc[input_num-1:0],//each axi stream should get in on input vc
                                                                 /*using this input vc, has packet will be created*/
  input [prio_num*vc_num-1:0]          i_has_packet[input_num-1:0],
  input [$clog2(output_num)-1 :0]      i_dests[input_num-1:0][prio_num*vc_num-1 :0],
  
  output [$clog2(vc_num*prio_num)-1:0] o_selected_vc_from_input_arbiter[input_num-1:0],
  output                               o_cts_from_input_arbiter[input_num-1:0],
  /* below signals will be used by top_module, in choosing the correct output_vc*/
  output [$clog2(output_num)-1 :0]     o_dest_output_of_each_input[input_num-1:0],
  output [$clog2(vc_num*prio_num)-1:0] o_dest_output_vc_of_each_input[input_num-1:0],
  output [$clog2(input_num)-1 :0]      o_selected_input_for_each_output[output_num-1:0]
  
 );
  var [data_width-1:0]                   data_to_mux[output_num][input_num-1:0] ; // why var???
  wire [output_num-1:0]                  grants_from_output_arbiter [input_num-1:0];//out of for loop for inputs or change the dimension
  wire [vc_num*prio_num-1:0]             output_fifo_credits [output_num-1:0];
  
  wire [vc_num*prio_num-1:0]             requests_from_in_to_out[output_num-1:0][input_num-1:0];
  wire [input_num-1:0]                   lasts_from_demux [output_num-1:0];
  wire [input_num-1:0]                   ctses_from_demux [output_num-1:0];
  wire [input_num-1:0]                   valids_from_demux [output_num-1:0];
  
  
  wire [$clog2(output_num)-1 :0]         dest_output[input_num-1:0];
  wire [$clog2(vc_num*prio_num)-1:0]     dest_output_vc[input_num-1:0];
  
  genvar i;
  genvar j;
     
   /* ---------------------------------------------------------------------*/        
   /* INPUT STAGE. 
    * This includes the input demux, the input arbiter .
    * and every other wire we want to be generatable*/
   /* ---------------------------------------------------------------------*/    
  generate 
    for (i=0; i<input_num; i=i+1)begin :INPUTS
     /* Input arbiter's signals */
      wire                                   cts;
      //wire                                   last;
      wire [$clog2(output_num)-1 :0]         dest_output;
      wire [$clog2(vc_num*prio_num)-1:0]     dest_output_vc;
     // wire [$clog2(vc_num*prio_num)-1:0]     selected_vc;
      wire [vc_num*prio_num-1:0]             request_to_output_arbiter;
      
      /* demux signals*/
      wire [data_width-1:0]                  demux_dout [output_num-1:0];
      wire [output_num-1 : 0]                last_from_demux;
      wire [output_num-1 : 0]                cts_from_demux;
      //wire [output_num-1 : 0]                prio_from_demux;
      wire [output_num-1 : 0]                valid_from_demux;
      wire [$clog2(output_num)-1 :0]               dest_o [prio_num*vc_num-1 :0];
     // wire [vc_num*prio_num-1:0]             has_packet;// check S_AXIS[I].TVALID & input_vc to fill each place with 1 or 0
      //logic [$clog2(vc_num*prio_num)-1:0]    output_vc [vc_num*prio_num-1:0];
      wire [$clog2(vc_num*prio_num)-1:0]     output_vc_o [vc_num*prio_num-1:0];
      //wire [(output_num)-1 :0]               dests [prio_num*vc_num-1 :0];
      
	  exa_crosb_demux # (
       .data_width(data_width),
       .output_num ( output_num )
      ) demux (
       .DATA_i(S_AXIS[i].TDATA),
       .VALID_i(S_AXIS[i].TVALID),
       .LAST_i(S_AXIS[i].TLAST),
       .PRIO_i(S_AXIS[i].prio),
       .SEL_i(dest_output),
       .CTS_FROM_INPUT_ARBITER_i(cts),
       .DATA_o(demux_dout),
       .LAST_o(last_from_demux),
       //.PRIO_o(prio_from_demux),
       .VALID_o(valid_from_demux),
       .CTS_FROM_INPUT_ARBITER_o(cts_from_demux)
      );   
   
    
      exa_crosb_input_arbiter_with_VCs # (
        .prio_num(prio_num),
        .vc_num(vc_num),
        .output_num(output_num)
      )input_arbiter_with_VCs (
        .clk(clk),
        .resetn(resetn),
        .i_has_packet(i_has_packet[i]),//
        .i_dest(i_dests[i]),
        .i_grant_from_output_arbiter(grants_from_output_arbiter[i]),//needs to be changed in input arbiter
        .i_last(S_AXIS[i].TLAST),//
        .output_fifo_credits(i_output_fifo_credits),// For every input, credits are the same 
        .i_output_vc(i_output_vc[i]),//***check that [i] is right
        .o_output_vc(output_vc_o),
        //.o_selected_request(selected_request), // maybe useless input,
        .o_request_to_output_arbiter(request_to_output_arbiter),
        .o_dest(dest_o),// it is the num of destination output of each  vc's packets
        .o_cts(cts),
        .o_selected_vc(o_selected_vc_from_input_arbiter[i]),
       // .o_request_array(request_array), // maybe useless input
        .o_dest_output(dest_output),
        .o_dest_vc(dest_output_vc)
   
       );
      
      assign o_dest_output_of_each_input[i] = dest_output;
      assign o_dest_output_vc_of_each_input[i] = dest_output_vc;
      assign o_cts_from_input_arbiter[i] = cts;
      assign S_AXIS[i].TREADY = cts;// not sure about it
     
    end
  endgenerate
  
  /* end of for loop*/
  
  
  /* ---------------------------------------------------------------------	
   Now generate all the wire busses connecting the Demuxe's to the Muxes    
   ---------------------------------------------------------------------*/

  generate
    for(i= 0 ; i <output_num ; i = i + 1)begin
      for(j= 0 ; j <input_num ; j = j + 1)begin
      /* - request_to_output_arbiter[vc_num*prio_num-1:0] has 1 in one position-vc and in all others 0
         - requests_from_in_to_out is a 2-d array [output_num-1:0][input_num-1:0], that each of its elements is [vc_num*prio_num-1:0]
         - for every input j, if destination output of its request is i, store request_to_output_arbiter in requests_from_in_to_out[i][j] */
        assign requests_from_in_to_out[i][j] = (INPUTS[j].dest_output == i) ? INPUTS[j].request_to_output_arbiter : 0;
        assign data_to_mux[i][j]             = INPUTS[j].demux_dout[i];
        assign valids_from_demux[i][j]       = INPUTS[j].valid_from_demux[i];
        assign lasts_from_demux[i][j]        = INPUTS[j].last_from_demux[i];
        assign ctses_from_demux[i][j]        = INPUTS[j].cts_from_demux[i];
      
      end
    end
  endgenerate
  
  
   /* ---------------------------------------------------------------------*/    
   /* OUTPUT STAGE. 
    * This includes the output mux, the output arbiter .
    * and every other wire we want to be generatable*/
   /* ---------------------------------------------------------------------*/
  
  
  generate
    for (i= 0 ; i<output_num ; i = i + 1) begin :OUTPUTS
      
      wire [input_num-1:0]                   grant;
      wire                                   cts;
      wire [$clog2(input_num)-1:0]           input_sel; 
      wire                                   valid_from_mux;
      wire                                   last_from_mux;
      wire                                   cts_from_input_arbiter_from_mux;
      //wire [$clog2(vc_num*prio_num)-1:0]     output_vc [vc_num*prio_num-1:0];
       //wire                                  prio_from_mux;
       
      exa_crosb_mux # (
        .data_width(data_width),
        .input_num ( input_num )
      ) mux (
        .DATA_i(data_to_mux[i]),
        .VALID_i(valids_from_demux[i]),
        .LAST_i(lasts_from_demux[i]), 
        //.PRIO_i(prios_from_demux[i]),      
        .SEL_i(input_sel),
        .CTS_FROM_INPUT_ARBITER_i(ctses_from_demux[i]),
              
        .DATA_o(M_AXIS[i].TDATA),
        .VALID_o(valid_from_mux),
        .LAST_o(last_from_mux),
        .CTS_FROM_INPUT_ARBITER_o(cts_from_input_arbiter_from_mux)
        //.PRIO_o(prio_from_mux)
      );       
      
      
      
      exa_crosb_output_arbiter_with_VCs #(
        .input_num(input_num),
        .output_num(output_num),
        .vc_num(vc_num)
     
      )output_arbiter_with_VCs(
        .clk(clk),
        .resetn(resetn),
        .i_request(requests_from_in_to_out[i]),
        //.i_output_vc(output_vc),// it is not used inside output arbiter
        .i_last(last_from_mux),//it was lasts_from_demux[i][input_sel]  ?
        
       // .o_request_array(request_array),// useless
        //.o_prio_sel(prio_sel),//useless
       
        .o_grant(grant),
        .o_input_sel(input_sel),
        .o_cts(cts),
        .cts_from_input_arbiter(cts_from_input_arbiter_from_mux)// it could be be ctses_from_demux[i][input_sel] ?
      );
      
      assign o_selected_input_for_each_output[i] = input_sel;
      assign M_AXIS[i].TVALID = valid_from_mux & cts_from_input_arbiter_from_mux;
      assign M_AXIS[i].TLAST  = last_from_mux  & cts_from_input_arbiter_from_mux;
      assign M_AXIS[i].TDEST  = 0;//I used TDEST, output has been chosen, so store 0 in TDEST
     // assign M_AXIS[i].prio   = prio_from_mux & cts;

      
      
    end
  endgenerate
  
  generate
    for (i= 0 ; i <output_num ; i = i + 1) begin   //4
      for (j= 0 ; j <input_num ; j = j + 1) begin  
        assign grants_from_output_arbiter[j][i] = OUTPUTS[i].grant[j];
      end
    end
  endgenerate
  
  
 
   
 
 
endmodule
