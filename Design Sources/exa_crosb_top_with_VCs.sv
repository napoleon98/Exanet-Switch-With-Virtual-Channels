`timescale 1ns / 1ps

import exanet_pkg::*;
import exanet_crosb_pkg::*;


module exa_crosb_top_with_VCs #(
  parameter integer input_num             = 4,
  parameter integer output_num            = 4,
  parameter integer vc_num                = 2,
  parameter integer max_ports             = 32,
  parameter integer prio_num              = 2,
  parameter integer in_fifo_depth         = 40,
  parameter integer out_fifo_depth        = 40,
  parameter integer S_AXI_ID_WIDTH        = 12,
  parameter integer conf_reg_num          = 256,
  parameter integer S_AXI_DATA_WIDTH      = 64,
  parameter integer S_AXI_ADDR_WIDTH      = $clog2(conf_reg_num*16),
	/*address mapping of the local ports. 0-3 dont need, since
	 *they are routed by dest coords. the same goes for 12-15*/
  parameter [41:0] PORTx_LOW_ADDR  [max_ports] = '{default:0} ,                
  parameter [41:0] PORTx_HIGH_ADDR [max_ports] = '{default:0} ,
  
 
  parameter net_route_reg_enable   = 4'b0000,
  parameter DEBUG                = "false"
 

)(
  
	
  input                           ACLK,
  input                           ARESETN,
	//
  exanet.master                   exanet_tx[output_num - 1 : 0],      
  exanet.slave                    exanet_rx[input_num - 1 : 0],
  input  [ 21:0]                  i_src_coord,
  output [ input_num-1:0]         o_dec_error
);


  localparam TDEST_WIDTH = 5;
  AXIS   S_AXIS[input_num-1  : 0]();   //from exa2axi
  AXIS   M_AXIS[output_num-1 : 0]();  //from crossbar to axi2exa
  cntrl_info_t  cntrl_info;
  
  /*****************exa_crosb_crosb signals************/
    
  wire [vc_num*prio_num-1:0]                output_fifo_credits [output_num-1:0];
  wire [$clog2(vc_num*prio_num)-1:0]        output_vc[input_num-1:0][vc_num*prio_num-1:0];
  wire [$clog2(vc_num*prio_num)-1:0]        input_vc [input_num-1:0];
  wire [prio_num*vc_num-1:0]                has_packet_of_each_input[input_num-1:0];
  wire [$clog2(output_num)-1 :0]                  dests_of_each_input[input_num-1:0][prio_num*vc_num-1 :0];
  
  wire [$clog2(vc_num*prio_num)-1:0]        selected_vc_from_input_arbiter[input_num-1:0];
  wire                                      cts_from_input_arbiter[input_num-1:0];
  wire [$clog2(output_num)-1 :0]            dest_output_of_each_input[input_num-1:0];
  wire [$clog2(vc_num*prio_num)-1:0]        dest_output_vc_of_each_input[input_num-1:0];
  
  wire [$clog2(input_num)-1 :0]             selected_input_for_each_output[output_num-1:0];
  
  wire [$clog2(vc_num*prio_num)-1:0]        output_vc_for_each_input[input_num-1:0][vc_num*prio_num-1:0];  /*'{default:0}*/
  
  /******************************************************/
  
  
  genvar i;
  generate 
    for (i = 0 ; i<input_num ; i = i + 1) begin :E2S
      exanet egza();
    /*create a helper interface to connect the interfaces to the submodule via it*/
     
      assign egza.data                  = exanet_rx[i].data;
      assign egza.header_valid          = exanet_rx[i].header_valid;
      assign egza.payload_valid         = exanet_rx[i].payload_valid;
      assign egza.footer_valid          = exanet_rx[i].footer_valid;
      assign exanet_rx[i].header_ready  = egza.header_ready;
      assign exanet_rx[i].payload_ready = egza.payload_ready;
      assign exanet_rx[i].footer_ready  = egza.footer_ready;
      
      
      wire [prio_num*vc_num-1 : 0]    has_packet; 
      wire [prio_num*vc_num-1 : 0]    fifo_full;
      wire [$clog2(output_num)-1 :0]  dests[prio_num*vc_num-1 : 0] ;
      //wire [prio_num*vc_num- 1: 0]    selected_vc_from_input_arbiter;  
      //wire                            cts_from_input_arbiter;
      
      exa_crosb_e2s_with_VCs # (
              .INPUT_PORT_NUMBER    (i),
              .fifo_enable          (1),
              .prio_num             (prio_num),
              .vc_num               (vc_num),
              .net_route_reg_enable (net_route_reg_enable[i]),
              .in_fifo_depth        (in_fifo_depth),
              .TDEST_WIDTH          (TDEST_WIDTH),
              .output_num           (output_num),
              .max_ports            (max_ports),
              .PORTx_LOW_ADDR   (PORTx_LOW_ADDR/*{42'h38000000000,42'h38000000010,42'h38000000020,42'h38000000030,42'h38000000040,42'h38000000050,42'h38000000060,42'h38000000070}*/ ),
              .PORTx_HIGH_ADDR  (PORTx_HIGH_ADDR/*{42'h3800000000f,42'h3800000001f,42'h3800000002f,42'h3800000003f,42'h3800000004f,42'h3800000005f,42'h3800000006f,42'h3800000007f} */)
          ) e2s_with_VCs   (
                 // AXI STREAM IF
              .M_ACLK(ACLK),
              .M_ARESETN(ARESETN),
              .i_src_coord(0),//i_src_coord
              .M_AXIS(S_AXIS[i]),    
              .exanet_rx(egza),
              .i_cntrl_info('b0),// cntrl_info
              .i_cts_from_input_arbiter(cts_from_input_arbiter[i]),//added
              .i_selected_vc_from_input_arbiter(selected_vc_from_input_arbiter[i]),//added
              .o_dec_error(o_dec_error[i]),
              .o_pkt_counter(),
              .o_has_packet(has_packet),
              .o_fifo_full(fifo_full),
              .o_dests(dests), // added
              .o_output_vc(output_vc_for_each_input[i])
      ); 
       
      assign has_packet_of_each_input[i] = has_packet;
      assign dests_of_each_input[i]      = dests;
    end
  endgenerate
  
  
  //assign output_vc = input_vc;/**simulating that input_vc and output_vc are the same*/ 
  
  exa_crosb_crosb_with_VCs#(
    .data_width(128),
    .prio_num(prio_num),
    .input_num(input_num),
    .vc_num(vc_num),
    .output_num(output_num)
  )exa_crosb_crosb_with_VCs( 

    .clk(ACLK),
    .resetn(ARESETN), 
    .S_AXIS(S_AXIS),
    .M_AXIS(M_AXIS),
    .i_output_fifo_credits(output_fifo_credits),
    .i_output_vc(output_vc_for_each_input),/**simulating that input_vc and output_vc are the same*/ 
    .i_has_packet(has_packet_of_each_input),
    .i_dests(dests_of_each_input),
    .o_selected_vc_from_input_arbiter(selected_vc_from_input_arbiter),
    .o_cts_from_input_arbiter(cts_from_input_arbiter),
    /*the below signals will be used for choosing the correct output_vc for s2e
      i.e. output_vc[dest_output_of_each_input][dest_output_vc_of_each_input]*/
    .o_dest_output_of_each_input(dest_output_of_each_input),
    .o_dest_output_vc_of_each_input(dest_output_vc_of_each_input),
    
    .o_selected_input_for_each_output(selected_input_for_each_output)
    
  );
  
  
  wire [$clog2(vc_num*prio_num)-1:0]  output_vc_i[output_num-1:0];
  genvar j;

  generate
    for (i = 0 ; i <output_num ; i =  i + 1) begin: S2E
    
      exanet egza(); 
      
      assign exanet_tx[i].data          = egza.data;
      assign exanet_tx[i].header_valid  = egza.header_valid;
      assign exanet_tx[i].payload_valid = egza.payload_valid;
      assign exanet_tx[i].footer_valid  = egza.footer_valid;
      /*******ready signals should be driven by the next tranceiver, for now they are always high******/
      /*
      assign exanet_tx[i].header_ready  = 1;
      assign exanet_tx[i].payload_ready  = 1;
      assign exanet_tx[i].footer_ready  = 1;
      */
      /*************************************************************************************************/
      assign egza.header_ready          = exanet_tx[i].header_ready;
      assign egza.payload_ready         = exanet_tx[i].payload_ready;
      assign egza.footer_ready          = exanet_tx[i].footer_ready;
      
      wire [prio_num*vc_num-1 : 0]        fifo_full;
      
      
      wire [$clog2(input_num)-1:0]selected_input;
      //wire [$clog2(vc_num*prio_num)-1:0]  output_vc_i;
      
      	
      exa_crosb_s2e_with_VCs #(
           .prio_num(prio_num),
           .vc_num(vc_num),
           .output_num(output_num), // maybe useless
           .input_num(input_num), // maybe useless 
           .out_fifo_depth(out_fifo_depth)// it was 40
      )s2e_with_VCs (
           .S_ACLK(ACLK),
           .S_ARESETN(ARESETN),
           .i_output_vc(output_vc_i[i]),
           .o_fifo_full(fifo_full),
           .S_AXIS(M_AXIS[i]),
          // ExaNet IF
           .exanet_tx(egza)
      );
      /*if fifo_full is low, output_fifo_credits[i] is high, so there is space to accomodate packets*/
      assign output_fifo_credits[i] = ~fifo_full;
      assign selected_input    = selected_input_for_each_output[i];
      assign output_vc_i[i] = dest_output_vc_of_each_input[selected_input];
      
    end
  endgenerate








endmodule
