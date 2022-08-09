`timescale 1ns / 1ps

import exanet_pkg::*;
import exanet_crosb_pkg::*;
`include "ceiling_up_log2.vh"

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
  parameter integer S_AXI_ADDR_WIDTH      = `log2(conf_reg_num*16),
	/*address mapping of the local ports. 0-3 dont need, since
	 *they are routed by dest coords. the same goes for 12-15*/
  parameter [41:0] PORTx_LOW_ADDR  [max_ports] = '{default:0} ,                
  parameter [41:0] PORTx_HIGH_ADDR [max_ports] = '{default:0} ,
  
 
  parameter net_route_reg_enable = 4'b0000,
  parameter DEBUG                = "false",
  parameter dimension_x          = 4,
  parameter dimension_y          = 2,
  parameter dimension_z          = 2,
  parameter logVcPrio            = `log2(prio_num*vc_num),
  parameter logOutput            = `log2(output_num),
  parameter logPrio              = `log2(prio_num),
  parameter logVc                = `log2(vc_num),
  parameter logInput             = `log2(input_num) 
 

)(
  
	
  input                           ACLK,
  input                           ARESETN,
	//
  exanet.master                   exanet_tx[output_num - 1 : 0],      
  exanet.slave                    exanet_rx[input_num - 1 : 0],
  input  [ 21:0]                  i_src_coord ,
  output [ input_num-1:0]         o_dec_error,
  output cntrl_info_t             o_cntrl_info,
  output [(logOutput-1) :0]o_dests_of_each_input[input_num-1:0][prio_num*vc_num-1 :0],
  
  

  // AXI Clock and Reset
  input                           S_AXI_ACLK,
  input                           S_AXI_ARESETN,
  // Memory Read Address Channel
  input [S_AXI_ID_WIDTH-1:0]      S_AXI_ARID,
  input [S_AXI_ADDR_WIDTH-1:0]    S_AXI_ARADDR,
  input [7:0]                     S_AXI_ARLEN,
  input [2:0]                     S_AXI_ARSIZE,
  input [1:0]                     S_AXI_ARBURST,
  input [1:0]                     S_AXI_ARLOCK,
  input [3:0]                     S_AXI_ARCACHE,
  input [2:0]                     S_AXI_ARPROT,
  input                           S_AXI_ARVALID,
  output                          S_AXI_ARREADY,
  // Memory Read Data Channel
  output [S_AXI_ID_WIDTH-1:0]     S_AXI_RID,
  output [S_AXI_DATA_WIDTH-1:0]   S_AXI_RDATA,
  output [1:0]                    S_AXI_RRESP,
  output                          S_AXI_RLAST,
  output                          S_AXI_RVALID,
  input                           S_AXI_RREADY,
  // Memory Write Address Channel
  input [S_AXI_ID_WIDTH-1:0]      S_AXI_AWID,
  input [S_AXI_ADDR_WIDTH-1:0]    S_AXI_AWADDR,
  input [7:0]                     S_AXI_AWLEN,
  input [2:0]                     S_AXI_AWSIZE,
  input [1:0]                     S_AXI_AWBURST,
  input [1:0]                     S_AXI_AWLOCK,
  input [3:0]                     S_AXI_AWCACHE,
  input [2:0]                     S_AXI_AWPROT,
  input                           S_AXI_AWVALID,
  output                          S_AXI_AWREADY,
  // Memory Write Data Channel
  input [S_AXI_DATA_WIDTH-1:0]    S_AXI_WDATA,
  input [(S_AXI_DATA_WIDTH/8)-1:0]S_AXI_WSTRB,
  input                           S_AXI_WLAST,
  input                           S_AXI_WVALID,
  output                          S_AXI_WREADY,
      //
      // Memory Write Responce Channel
  output [S_AXI_ID_WIDTH-1:0]     S_AXI_BID,
  output [1:0]                    S_AXI_BRESP,
  output                          S_AXI_BVALID,
  input                           S_AXI_BREADY
  

);


  localparam TDEST_WIDTH = 5;//logOutput;
  AXIS   S_AXIS[input_num-1  : 0]();   //from exa2axi
  AXIS   M_AXIS[output_num-1 : 0]();  //from crossbar to axi2exa
  cntrl_info_t  cntrl_info;
  
  /*****************exa_crosb_crosb signals************/
    
  wire [vc_num*prio_num-1:0]               output_fifo_credits [output_num-1:0]                        ;
  wire [logVcPrio-1:0]                     output_vc[input_num-1:0][vc_num*prio_num-1:0]               ;
  wire [logVcPrio-1:0]                     input_vc [input_num-1:0]                                    ;
  wire [prio_num*vc_num-1:0]               has_packet_of_each_input[input_num-1:0]                     ;
  wire [logOutput-1 :0]                    dests_of_each_input[input_num-1:0][prio_num*vc_num-1 :0]    ;
  
  wire [logVcPrio-1:0]                     selected_vc_from_input_arbiter[input_num-1:0]               ;
  wire                                     cts_from_input_arbiter[input_num-1:0]                       ;
  wire [logOutput-1 :0]                    dest_output_of_each_input[input_num-1:0]                    ;
  wire [logVcPrio-1:0]                     dest_output_vc_of_each_input[input_num-1:0]                 ;
  
  wire [logInput-1 :0]                     selected_input_for_each_output[output_num-1:0]              ; 
  
  wire [logVcPrio-1:0]                    output_vc_for_each_input[input_num-1:0][vc_num*prio_num-1:0] ;  /*'{default:0}*/
  
    
  counter_t pkt_counter_from_e2s[input_num-1:0];  
  counter_t pkt_counter_from_s2e[output_num-1:0];
  
  /******************************************************/
  assign o_dests_of_each_input = dests_of_each_input;
  
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
      wire [logOutput-1 :0]  dests[prio_num*vc_num-1 : 0] ;
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
              .PORTx_HIGH_ADDR  (PORTx_HIGH_ADDR/*{42'h3800000000f,42'h3800000001f,42'h3800000002f,42'h3800000003f,42'h3800000004f,42'h3800000005f,42'h3800000006f,42'h3800000007f} */),
              .dimension_x(dimension_x),
              .dimension_y(dimension_y),
              .dimension_z(dimension_z)
          ) e2s_with_VCs   (
                 // AXI STREAM IF
              .M_ACLK(ACLK),
              .M_ARESETN(ARESETN),
              .i_src_coord(i_src_coord),//i_src_coord
              .M_AXIS(S_AXIS[i]),    
              .exanet_rx(egza),
              .i_cntrl_info(cntrl_info),// cntrl_info
              .i_cts_from_input_arbiter(cts_from_input_arbiter[i]),//added
              .i_selected_vc_from_input_arbiter(selected_vc_from_input_arbiter[i]),//added
              .o_dec_error(o_dec_error[i]),
              .o_pkt_counter(pkt_counter_from_e2s[i]),
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
  
  
  wire [logVcPrio-1:0]  output_vc_i[output_num-1:0];
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
      
      
      wire [logInput-1:0]selected_input;
      //wire [logVcPrio-1:0]  output_vc_i;
      
      	
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
           .o_pkt_counter(pkt_counter_from_s2e[i]),
          // ExaNet IF
           .exanet_tx(egza)
      );
      /*if fifo_full is low, output_fifo_credits[i] is high, so there is space to accomodate packets*/
      assign output_fifo_credits[i] = ~fifo_full;
      assign selected_input    = selected_input_for_each_output[i];
      assign output_vc_i[i] = dest_output_vc_of_each_input[selected_input];
      
    end
  endgenerate
  

  
  exa_crosb_regfile  # (
          .S_AXI_ID_WIDTH(S_AXI_ID_WIDTH),
          .S_AXI_DATA_WIDTH(S_AXI_DATA_WIDTH),
          .S_AXI_ADDR_WIDTH(S_AXI_ADDR_WIDTH),
          .conf_reg_num(conf_reg_num),
          .input_num(input_num),
          .output_num(output_num),
          .prio_num(prio_num),
          .DEBUG(DEBUG)
  ) exa_crosb_regfile (
          // AXI Clock and Reset
          .S_AXI_ACLK(S_AXI_ACLK),
          .S_AXI_ARESETN(S_AXI_ARESETN),
          // Memory Read Address Channel
          .S_AXI_ARID(S_AXI_ARID),
          .S_AXI_ARADDR(S_AXI_ARADDR),
          .S_AXI_ARLEN(S_AXI_ARLEN),
          .S_AXI_ARSIZE(S_AXI_ARSIZE),
          .S_AXI_ARBURST(S_AXI_ARBURST),
          .S_AXI_ARLOCK(S_AXI_ARLOCK),
          .S_AXI_ARCACHE(S_AXI_ARCACHE),
          .S_AXI_ARPROT(S_AXI_ARPROT),
          .S_AXI_ARVALID(S_AXI_ARVALID),
          .S_AXI_ARREADY(S_AXI_ARREADY),
          // Memory Read Data Channel
          .S_AXI_RID(S_AXI_RID),
          .S_AXI_RDATA(S_AXI_RDATA),
          .S_AXI_RRESP(S_AXI_RRESP),
          .S_AXI_RLAST(S_AXI_RLAST),
          .S_AXI_RVALID(S_AXI_RVALID),
          .S_AXI_RREADY(S_AXI_RREADY),
          // Memory Write Address Channel
          .S_AXI_AWID(S_AXI_AWID),
          .S_AXI_AWADDR(S_AXI_AWADDR),
          .S_AXI_AWLEN(S_AXI_AWLEN),
          .S_AXI_AWSIZE(S_AXI_AWSIZE),
          .S_AXI_AWBURST(S_AXI_AWBURST),
          .S_AXI_AWLOCK(S_AXI_AWLOCK),
          .S_AXI_AWCACHE(S_AXI_AWCACHE),
          .S_AXI_AWPROT(S_AXI_AWPROT),
          .S_AXI_AWVALID(S_AXI_AWVALID),
          .S_AXI_AWREADY(S_AXI_AWREADY),
          // Memory Write Data Channel
          .S_AXI_WDATA(S_AXI_WDATA),
          .S_AXI_WSTRB(S_AXI_WSTRB),
          .S_AXI_WLAST(S_AXI_WLAST),
          .S_AXI_WVALID(S_AXI_WVALID),
          .S_AXI_WREADY(S_AXI_WREADY),
          //
          // Memory Write Responce Channel
          .S_AXI_BID(S_AXI_BID),
          .S_AXI_BRESP(S_AXI_BRESP),
          .S_AXI_BVALID(S_AXI_BVALID),
          .S_AXI_BREADY(S_AXI_BREADY),
          .o_cntrl_info(cntrl_info)
          //.i_pkt_counter_input(pkt_counter_from_e2s),
          //.i_pkt_counter_output(pkt_counter_from_s2e)
      );








endmodule
