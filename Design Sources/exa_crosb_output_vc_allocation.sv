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
  input  [ 21:0]                           i_src_coord,
  input  [TDEST_WIDTH-1:0] 	               i_tdest,
  exanet_header                            exa_hdr,
  input  cntrl_info_t                      i_cntrl_info,
  
  output [logVcPrio-1:0]                   o_output_vc [vc_num*prio_num-1:0]
  
      
);
  reg   [logVcPrio-1:0]  input_vc_q                                    ;
  wire  [logVcPrio-1:0]  input_vc                                      ;
  logic [logVcPrio-1:0]  output_vc [vc_num*prio_num-1:0]               ;
  always@(posedge clk) begin
    if(!resetn)begin
      input_vc_q <= 0;
     // output_vc  <= '{default:0};
    end
    else begin
      if(i_hdr_valid)
        input_vc_q <= i_input_vc;
        
      //output_vc[input_vc] <= input_vc;
      
    end
  end
  
  assign input_vc              = i_hdr_valid ? i_input_vc : input_vc_q;
  //assign o_output_vc = output_vc;

  
  /*output_vc for input_vc ([i]) is input_vc*/
  /*
  genvar i;
  for(i=0;i<prio_num*vc_num;i=i+1)begin
    // assign o_output_vc[i] = (input_vc == i) ? input_vc : 0;
     assign output_vc[i] = (input_vc == i) ? input_vc :((output_vc[i] != 0) ? output_vc[i] :0);
  end
  */
  
  
  
  
  
  
  /*supposing that input and output ports are the same(in input x-=0 x+=1, and in output x-=0, x+=1)*/
  
  wire input_port_x;
  wire input_port_y;
  wire input_port_z;
  
    
  wire output_port_x;
  wire output_port_y;
  wire output_port_z;
  
  /*supposing that input and output ports are the same(in input x-=0 x+=1, and in output x-=0, x+=1)*/
  
  assign input_port_x  = (INPUT_PORT_NUMBER == i_cntrl_info.dest_x_minus) | (INPUT_PORT_NUMBER == i_cntrl_info.dest_x_plus);
  assign input_port_y  = (INPUT_PORT_NUMBER == i_cntrl_info.dest_y_minus) | (INPUT_PORT_NUMBER == i_cntrl_info.dest_y_plus);
  assign input_port_z  = (INPUT_PORT_NUMBER == i_cntrl_info.dest_z_minus) | (INPUT_PORT_NUMBER == i_cntrl_info.dest_z_plus);
  
  assign output_port_x = (i_tdest == i_cntrl_info.dest_x_minus) | (i_tdest == i_cntrl_info.dest_x_plus);
  assign output_port_y = (i_tdest == i_cntrl_info.dest_y_minus) | (i_tdest == i_cntrl_info.dest_y_plus);
  assign output_port_z = (i_tdest == i_cntrl_info.dest_z_minus) | (i_tdest == i_cntrl_info.dest_z_plus);
  
  wire input_port_dimension;
  wire output_port_dimension;
  
                                 
   
  assign input_port_dimension  = (INPUT_PORT_NUMBER == i_cntrl_info.dest_z_minus) | (INPUT_PORT_NUMBER == i_cntrl_info.dest_z_plus) ? 0 :
                                 (INPUT_PORT_NUMBER == i_cntrl_info.dest_y_minus) | (INPUT_PORT_NUMBER == i_cntrl_info.dest_y_plus) ? 1 :
                                 (INPUT_PORT_NUMBER == i_cntrl_info.dest_x_minus) | (INPUT_PORT_NUMBER == i_cntrl_info.dest_x_plus) ? 2 : 3;

  
  assign output_port_dimension = (i_tdest == i_cntrl_info.dest_z_minus) | (i_tdest == i_cntrl_info.dest_z_plus) ? 0 :
                                 (i_tdest == i_cntrl_info.dest_y_minus) | (i_tdest == i_cntrl_info.dest_y_plus) ? 1 :
                                 (i_tdest == i_cntrl_info.dest_x_minus) | (i_tdest == i_cntrl_info.dest_x_plus) ? 2 : 3;
                                
 
  always_comb begin
  
    output_vc = '{default:0};
    
    if(i_hdr_valid)begin
      if(input_port_dimension != output_port_dimension)begin
        if(input_vc > vc_num - 1)begin//if it is a high prio vc..
          if(input_vc == (prio_num * vc_num) - 1)//it is needed because,  I can't use %
            output_vc[input_vc] = vc_num;
          else
            output_vc[input_vc] = input_vc + 1;
        end
        else begin
          output_vc[input_vc] = (input_vc + 1) % vc_num;
        end
      end
      else begin
        output_vc[input_vc] = input_vc;
      end
    end
    
  
  end
  assign o_output_vc = output_vc;
  
  
  
 
 


  



endmodule
