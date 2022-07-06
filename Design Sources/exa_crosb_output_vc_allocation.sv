`timescale 1ns / 1ps

import exanet_pkg::*;
import exanet_crosb_pkg::*;


module exa_crosb_output_vc_allocation #(
      parameter prio_num             = 2,
      parameter vc_num               = 2

    )
(
  input                                    clk,
  input                                    resetn,
  input  [$clog2(vc_num*prio_num)-1:0]     i_input_vc,
  input                                    i_hdr_valid,
  output [$clog2(vc_num*prio_num)-1:0]     o_output_vc [vc_num*prio_num-1:0]
      
);
  reg [$clog2(vc_num*prio_num)-1:0] input_vc_q;
  wire [$clog2(vc_num*prio_num)-1:0] input_vc;
  
  always@(posedge clk) begin
    if(!resetn)
      input_vc_q <= 0;
    else begin
      if(i_hdr_valid)
        input_vc_q <= i_input_vc;
    end
  end
  
  assign input_vc              = i_hdr_valid ? i_input_vc : input_vc_q;
  
  genvar i;
  /*output_vc for input_vc ([i]) is inpur_vc*/
  for(i=0;i<prio_num*vc_num;i=i+1)begin
     assign o_output_vc[i] = (input_vc == i) ? input_vc : 0;
  end
  
  
 


  



endmodule
