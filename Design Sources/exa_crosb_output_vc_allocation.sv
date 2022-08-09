`timescale 1ns / 1ps

import exanet_pkg::*;
import exanet_crosb_pkg::*;
`include "ceiling_up_log2.vh"

module exa_crosb_output_vc_allocation #(
      parameter prio_num             = 2,
      parameter vc_num               = 2,
      parameter logVcPrio    = `log2(prio_num*vc_num),
      parameter logPrio      = `log2(prio_num),
      parameter logVc        = `log2(vc_num)

    )
(
  input                                    clk,
  input                                    resetn,
  input  [logVcPrio-1:0]                   i_input_vc,
  input                                    i_hdr_valid,
  input [ 21:0]                            i_src_coord,
  
  exanet_header                            exa_hdr,
  
  output [logVcPrio-1:0]                   o_output_vc [vc_num*prio_num-1:0]
  
      
);
  reg  [logVcPrio-1:0] input_vc_q                                    ;
  wire [logVcPrio-1:0] input_vc                                      ;
  reg [logVcPrio-1:0]  output_vc [vc_num*prio_num-1:0]               ;
  always@(posedge clk) begin
    if(!resetn)begin
      input_vc_q <= 0;
      output_vc  <= '{default:0};
    end
    else begin
      if(i_hdr_valid)
        input_vc_q <= i_input_vc;
        
      output_vc[input_vc] <= input_vc;
      
    end
  end
  
  assign input_vc              = i_hdr_valid ? i_input_vc : input_vc_q;
  
  genvar i;
  /*output_vc for input_vc ([i]) is input_vc*/
  /*
  for(i=0;i<prio_num*vc_num;i=i+1)begin
    // assign o_output_vc[i] = (input_vc == i) ? input_vc : 0;
     assign output_vc[i] = (input_vc == i) ? input_vc :((output_vc[i] != 0) ? output_vc[i] :0);
  end
  */
  assign o_output_vc = output_vc;
 
 


  



endmodule
