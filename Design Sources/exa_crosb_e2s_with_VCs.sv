`timescale 1ns / 1ps

import exanet_pkg::*;
import exanet_crosb_pkg::*;
`include "ceiling_up_log2.vh"


module exa_crosb_e2s_with_VCs # (
    parameter fifo_enable          = 0,
    parameter prio_num             = 2,
    parameter vc_num               = 2,
    parameter net_route_reg_enable = 0,
    parameter output_num           = 4,
    parameter integer in_fifo_depth= 40,
    parameter max_ports            = 32,
	parameter TDEST_WIDTH          = `log2(output_num),
	parameter REG_DQ               = 1,
	parameter INPUT_PORT_NUMBER    = 0,
	parameter [41:0] PORTx_LOW_ADDR  [max_ports] = '{default:0}/*{0}*/ ,
    parameter [41:0] PORTx_HIGH_ADDR [max_ports] = '{default:0}/*{0} */,
    parameter DEBUG                = "false",
    parameter dimension_x          = 4,
    parameter dimension_y          = 2,
    parameter dimension_z          = 2 ,
    parameter logVcPrio            = `log2(prio_num*vc_num),
    parameter logOutput            = `log2(output_num),
    parameter logPrio              = `log2(prio_num),
    parameter logVc                = `log2(vc_num)    
    ) 

(
    // AXI STREAM IF
	input                                M_ACLK,
	input                                M_ARESETN,
	//
	input  [ 21:0]                       i_src_coord,
	input                                i_cts_from_input_arbiter,
	input [logVcPrio-1:0]  i_selected_vc_from_input_arbiter,
	//
    AXIS.master                          M_AXIS,	
	// ExaNet IF
    exanet.slave                         exanet_rx,
    input  cntrl_info_t                  i_cntrl_info,
    	
    (* KEEP = DEBUG *) (* MARK_DEBUG = DEBUG *)
	output		     	                 o_dec_error,
	output [prio_num*vc_num-1:0]         o_has_packet,
	output [prio_num*vc_num-1:0]         o_fifo_full,
	output [logOutput-1 :0]              o_dests [prio_num*vc_num-1:0],
    output [logVcPrio-1:0]               o_output_vc [vc_num*prio_num-1:0]
);
    

  localparam Idle_St = 2'b01,
             Xfer_St = 2'b10;
  reg [1:0]  X_State;
    // 
  AXIS         M_AXIS_exa2axi() ;
          
  (* KEEP = DEBUG *) (* MARK_DEBUG = DEBUG *)
  wire [127:0]           modified_header;    
  (* KEEP = DEBUG *) (* MARK_DEBUG = DEBUG *)
  wire                   tdest_valid;
  logic                  dec_error;
    
  
   /*helper signals used for interface connections*/    
  (* KEEP = DEBUG *) (* MARK_DEBUG = DEBUG *)
  wire [prio_num*vc_num-1 : 0][127:0]           tdata_from_fifo;    
  (* KEEP = DEBUG *) (* MARK_DEBUG = DEBUG *)
  wire [prio_num*vc_num-1 : 0]                  tvalid_from_fifo;    
  (* KEEP = DEBUG *) (* MARK_DEBUG = DEBUG *)
  wire [prio_num*vc_num-1 : 0]                  tlast_from_fifo;    
  (* KEEP = DEBUG *) (* MARK_DEBUG = DEBUG *)
  wire [prio_num*vc_num-1 : 0][TDEST_WIDTH-1:0] tdest_from_fifo; 
  
  reg [4 :0]                                    vc_from_header_q;
  
  
  /*helper signlas used for out vc allocation */
  wire [127:0]           modified_header_from_out_vc_allocation; 
  wire [prio_num : 0]    prio;// maybe it's useless
  
  
  exa_crosb_net_routing #(
        .INPUT_PORT_NUMBER(INPUT_PORT_NUMBER),
        .TDEST_WIDTH ( TDEST_WIDTH ),
        .output_num (output_num),
        .max_ports  (max_ports),
        .PORTx_LOW_ADDR(PORTx_LOW_ADDR) ,
        .PORTx_HIGH_ADDR(PORTx_HIGH_ADDR),
        .reg_enable(net_route_reg_enable),
        .DEBUG(DEBUG),
        .dimension_x(dimension_x),
        .dimension_y(dimension_y),
        .dimension_z(dimension_z) 
      ) exa_crosb_net_routing (
        .Clk                     ( M_ACLK ),
        .Reset                   ( ~M_ARESETN) ,
        .i_header                ( exanet_rx.data ),
        .o_prio                  ( ),
        .i_hdr_valid             ( exanet_rx.header_valid ),
        .i_src_coord             ( i_src_coord ),
        .o_tdest                 ( M_AXIS_exa2axi.TDEST ),
        .o_dest_valid            ( tdest_valid ),
        .o_dec_error             ( dec_error ),
        .i_cntrl_info            ( i_cntrl_info )
      ); 
   
  assign o_dec_error = (dec_error != 0);
   
  exanet_header exa_hdr;
  assign exa_hdr = (exanet_rx.header_valid) ? exanet_rx.data : 0;
  
 /*implement the Exa 2 AXI logic here */ 
  always @(posedge M_ACLK) begin
    if(~M_ARESETN) X_State <=  Idle_St;
    else begin
      case(X_State)
        Idle_St :begin
          if(exanet_rx.header_valid & M_AXIS_exa2axi.TREADY)
            X_State <=  Xfer_St;
          else X_State <=  Idle_St;
        end
          Xfer_St : begin
            if(exanet_rx.footer_valid & M_AXIS_exa2axi.TREADY)
              X_State <=  Idle_St;
            else X_State <=  Xfer_St;
          end
        default  :
          X_State <=  Idle_St;
      endcase
    end
  end    
  


  exa_crosb_output_vc_allocation #(
    .prio_num(prio_num),
    .vc_num(vc_num),
    .INPUT_PORT_NUMBER(INPUT_PORT_NUMBER),
    .output_num(output_num),
    .TDEST_WIDTH(TDEST_WIDTH)
  )exa_crosb_output_vc_allocation(
    .clk(M_ACLK),
    .resetn(M_ARESETN),
    .i_hdr_valid(exanet_rx.header_valid),
    .i_input_vc(exa_hdr.vc),
    .i_header(exanet_rx.data),
    .i_tdest(M_AXIS_exa2axi.TDEST),
    .i_cntrl_info ( i_cntrl_info ),
    //.o_output_vc(o_output_vc),
    .o_header(modified_header)
  );

  
/*in case of header, then maybe it has been modified -- "modified_header" will be replaced from "modified_header_from_out_vc_allocation" */
  assign M_AXIS_exa2axi.TDATA  = (tdest_valid) ? modified_header : exanet_rx.data  ;
  assign M_AXIS_exa2axi.TLAST  = exanet_rx.footer_valid;    
  
  /*in case of header, w8 for the tdest to be calculated*/
  assign M_AXIS_exa2axi.TVALID = (X_State == Idle_St) ? (exanet_rx.header_valid & tdest_valid)  :  exanet_rx.payload_valid | exanet_rx.footer_valid;
  
  
  assign exanet_rx.header_ready  = M_AXIS_exa2axi.TREADY;
  assign exanet_rx.payload_ready = (X_State==Xfer_St) & M_AXIS_exa2axi.TREADY;
  assign exanet_rx.footer_ready  = (X_State==Xfer_St) & M_AXIS_exa2axi.TREADY;
 
  
  
  assign M_AXIS.TDATA  = tdata_from_fifo[i_selected_vc_from_input_arbiter];
  assign M_AXIS.TLAST  = tlast_from_fifo[i_selected_vc_from_input_arbiter];
  assign M_AXIS.TDEST  = tdest_from_fifo[i_selected_vc_from_input_arbiter];
  assign M_AXIS.TVALID = tvalid_from_fifo[i_selected_vc_from_input_arbiter];
  assign M_AXIS.prio   = (i_selected_vc_from_input_arbiter > (vc_num - 1)) ? 1 : 0; // ****high prio = 1. low prio = 0******
  
  always_ff @(posedge M_ACLK) begin
    if(!M_ARESETN) begin
      vc_from_header_q <= 0;
      
    end
    else begin
      if(exanet_rx.header_valid) begin
        vc_from_header_q <= exa_hdr.vc;
      end
    end
    
  end
  
  
  genvar i,j;
 
  generate

            
    (* KEEP = DEBUG *) (* MARK_DEBUG = DEBUG *)
    wire [prio_num * vc_num -1 :0]            fifo_prog_full;    
    (* KEEP = DEBUG *) (* MARK_DEBUG = DEBUG *)
    wire [prio_num * vc_num-1 :0]            fifo_empty;    
    (* KEEP = DEBUG *) (* MARK_DEBUG = DEBUG *)
    wire [127 +1 + TDEST_WIDTH:0] fifo_rd_data [prio_num * vc_num-1 :0];    
    (* KEEP = DEBUG *) (* MARK_DEBUG = DEBUG *)
    wire [127 +1 + TDEST_WIDTH:0] fifo_wr_data [prio_num * vc_num-1 :0];    
    (* KEEP = DEBUG *) (* MARK_DEBUG = DEBUG *)
    wire [prio_num * vc_num-1 :0]            fifo_enq;    
    (* KEEP = DEBUG *) (* MARK_DEBUG = DEBUG *)
    wire [prio_num * vc_num-1 :0]            fifo_deq;
    
    wire [prio_num * vc_num-1 :0]            fifo_full;
      
    (* KEEP = DEBUG *) (* MARK_DEBUG = DEBUG *)
    reg  [prio_num * vc_num-1 :0]            exanet_ready_q;
    
    for(j=0; j<prio_num; j++) begin :PRIO
      for(i=0; i<vc_num; i++) begin :VC
    //the data going into the fifos//
        
        
        assign fifo_wr_data[j*vc_num + i]        =   {M_AXIS_exa2axi.TDEST,M_AXIS_exa2axi.TLAST,M_AXIS_exa2axi.TDATA}; 
       
       // if header_valid = 1 start writing and don't wait for the header to be stored in vc_from_header_q
        assign fifo_enq[j*vc_num + i]            =  exanet_rx.header_valid ? ((exa_hdr.vc == j*vc_num + i) ? (M_AXIS_exa2axi.TVALID & M_AXIS_exa2axi.TREADY) : 0) : (vc_from_header_q == j*vc_num + i) ? (M_AXIS_exa2axi.TVALID & M_AXIS_exa2axi.TREADY) : 0;
            
      
        if (net_route_reg_enable) //if network routing is pipelined, then wait for the answer.
          assign M_AXIS_exa2axi.TREADY = (exanet_rx.header_valid) ? exanet_ready_q[exa_hdr.vc] & tdest_valid : exanet_ready_q[vc_from_header_q];
        else
          assign M_AXIS_exa2axi.TREADY = (exanet_rx.header_valid) ? exanet_ready_q[exa_hdr.vc] : exanet_ready_q[vc_from_header_q] ;
          

    
       assign tdata_from_fifo[j*vc_num + i]    = fifo_rd_data[(j*vc_num + i)][127:0]                                                 ;
       assign tvalid_from_fifo[j*vc_num + i]   =  ~fifo_empty[(j*vc_num + i)]                                                        ;
       assign tlast_from_fifo[j*vc_num + i]    = fifo_rd_data[(j*vc_num + i)][128] & (~fifo_empty[(j*vc_num + i)])                   ;
       assign tdest_from_fifo[j*vc_num + i]    = fifo_rd_data[(j*vc_num + i)][TDEST_WIDTH+129-1:129]                                 ;
       assign fifo_deq[j*vc_num + i]           = (i_selected_vc_from_input_arbiter == (j*vc_num + i)) ? i_cts_from_input_arbiter : 0 ;
       assign o_has_packet[(j*vc_num + i)]     = ~fifo_empty[(j*vc_num + i)]                                                         ;
    
       
       
       /*output_vc has the number of output_vc  of the first packet that is going to go out*/
        assign o_output_vc [(j*vc_num + i)]     = fifo_rd_data[(j*vc_num + i)][4:0];
       
      /*one cycle after the data are written in fifo, the head is in rd_data without any dequeue*/
        assign o_dests[j*vc_num + i]            =  fifo_rd_data[(j*vc_num + i)][TDEST_WIDTH+129-1:129];
   
       
        assign o_fifo_full [(j*vc_num + i)]     = fifo_prog_full[j*vc_num + i];
       
        always @ (posedge M_ACLK) begin
          if (!M_ARESETN)
            exanet_ready_q[(j*vc_num + i)] <=  0;
          else begin
            if (!fifo_prog_full[(j*vc_num + i)])
              exanet_ready_q[(j*vc_num + i)] <=  1;
            else
              if (M_AXIS_exa2axi.TLAST)
                exanet_ready_q[(j*vc_num + i)] <=  0;
          end
        end  

        //(* KEEP = DEBUG *) (* MARK_DEBUG = DEBUG *)
        
        exa_fifo # (
          .DEPTH             ( in_fifo_depth ),
          .DWIDTH            ( 127 +2 + TDEST_WIDTH ),
          .ALL_REGD          (   1 ),
          .DISTURBED         (   1 ),
          .PROG_FULL_ASSERT  (  18 ), //one max pkt length 
          .PROG_FULL_NEGATE  (  19 )
        ) in_fifo (
          .arst_n       ( M_ARESETN ),
          .clk          ( M_ACLK ),
          .i_wr_data    ( fifo_wr_data[(j*vc_num + i)] ),
          .i_wr_en      ( fifo_enq[(j*vc_num + i)] ),
          .o_full       ( fifo_full[j*vc_num + i] ),
          .o_prog_full  ( fifo_prog_full[(j*vc_num + i)] ),
          .o_wr_words   (  ),      
          .o_rd_data    ( fifo_rd_data[(j*vc_num + i)] ),
          .i_rd_en      ( fifo_deq[(j*vc_num + i)] ),
          .o_empty      ( fifo_empty[(j*vc_num + i)] )
        );
        /*
        always_ff @(posedge M_ACLK) begin assert(!fifo_full) else $fatal("fifo full on e2s"); end 
        */
      end // end of second for loop
    end // end of first for loop
     
    //end // end of "else"
  endgenerate
    
endmodule
