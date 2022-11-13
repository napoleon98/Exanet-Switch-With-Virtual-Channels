`timescale 1ns / 1ps

import exanet_pkg::*;
import exanet_crosb_pkg::*;
`include "ceiling_up_log2.vh"

module exa_crosb_output_vc_allocation #(
      parameter INPUT_PORT_NUMBER    = 0,
      parameter output_num           = 2,
      parameter prio_num             = 2,
      parameter vc_num               = 2,
      parameter TDEST_WIDTH          = `log2(output_num),
      parameter logVcPrio            = `log2(prio_num*vc_num),
      parameter logPrio              = `log2(prio_num),
      parameter logVc                = `log2(vc_num)

    )
(
  input                                    clk,
  input                                    resetn,
  input  [logVcPrio-1:0]                   i_input_vc,
  input                                    i_hdr_valid,
  input  [127:0]                           i_header,
  input  [ 21:0]                           i_src_coord,
  input  [TDEST_WIDTH-1:0] 	               i_tdest,
  input  cntrl_info_t                      i_cntrl_info,
  output [127:0]                           o_header
  
      
);
  reg   [logVcPrio-1:0]  input_vc_q                                    ;
  wire  [logVcPrio-1:0]  input_vc                                      ;
  logic [4:0]            output_vc_single                              ;
  exanet_header          exa_hdr                                       ;
  
  exanet_header          exa_hdr_o                                     ;
  
  assign exa_hdr                = i_header;
  
 
  always@(posedge clk) begin
    if(!resetn)begin
      input_vc_q  <= 0;

    end
    else begin
      if(i_hdr_valid)begin
        input_vc_q  <= exa_hdr.vc;
   
      end  
     
      
    end
  end
  
  assign input_vc              = i_hdr_valid ? exa_hdr.vc : input_vc_q;



  
  /*supposing that input and output ports are the same(in input x-=0 x+=1, and in output x-=0, x+=1)*/
  
  
  wire                  input_port_dimension ;
  wire                  output_port_dimension;
  wire [logPrio - 1 :0] num_of_prio          ;
  
                                 
   
  assign input_port_dimension  = (INPUT_PORT_NUMBER == i_cntrl_info.dest_z_minus) | (INPUT_PORT_NUMBER == i_cntrl_info.dest_z_plus) ? 0 :
                                 (INPUT_PORT_NUMBER == i_cntrl_info.dest_y_minus) | (INPUT_PORT_NUMBER == i_cntrl_info.dest_y_plus) ? 1 :
                                 (INPUT_PORT_NUMBER == i_cntrl_info.dest_x_minus) | (INPUT_PORT_NUMBER == i_cntrl_info.dest_x_plus) ? 2 : 3;

  
  assign output_port_dimension = (i_tdest == i_cntrl_info.dest_z_minus) | (i_tdest == i_cntrl_info.dest_z_plus) ? 0 :
                                 (i_tdest == i_cntrl_info.dest_y_minus) | (i_tdest == i_cntrl_info.dest_y_plus) ? 1 :
                                 (i_tdest == i_cntrl_info.dest_x_minus) | (i_tdest == i_cntrl_info.dest_x_plus) ? 2 : 3;
                                 
  assign num_of_prio           = (i_hdr_valid) ? input_vc/vc_num : 0 ;
  
                                

  always_comb begin
  
    output_vc_single = 0;
    
    if(i_hdr_valid)begin
      if(input_port_dimension != output_port_dimension)begin

        output_vc_single    = ((input_vc - num_of_prio*vc_num + 1) % vc_num) + num_of_prio*vc_num;
      end
      else begin

        output_vc_single    = input_vc;
      end
      
    end
    
  
  end
                                              
  assign o_header        = i_hdr_valid ? {i_header[127:5],output_vc_single} : i_header   ;
  assign exa_hdr_o       = o_header;
  
  
  
  
 
 


  



endmodule
