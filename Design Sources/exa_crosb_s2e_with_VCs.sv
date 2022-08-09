`timescale 1ns/1ns
//
import exanet_pkg::*;
import exanet_crosb_pkg::*;

`include "ceiling_up_log2.vh"

module exa_crosb_s2e_with_VCs #(
	parameter prio_num               = 2,
	parameter vc_num                 = 2,
	parameter output_num             = 4, // maybe useless
	parameter input_num              = 4, // number of inputs of next input
	parameter integer out_fifo_depth = 40, // in testbench depth is 36,
    parameter logVcPrio              = `log2(prio_num*vc_num),
    parameter logOutput              = `log2(output_num),
    parameter logPrio                = `log2(prio_num),
    parameter logVc                  = `log2(vc_num)

) (
	// Stream IF
	input                                        S_ACLK,
    input                                        S_ARESETN,
	input [logVcPrio-1:0]                        i_output_vc,
    output [prio_num*vc_num-1:0]                 o_fifo_full,
    AXIS.slave                                   S_AXIS,
	
	// ExaNet IF
    exanet.master                                exanet_tx,
    output counter_t                             o_pkt_counter

);
 
  localparam  Sop_st   = 2'b01,
              Sop_Wait = 2'b10;
			  
        
  localparam  IDDLE     = 2'b00,     
              GRANTED   = 2'b10;		  
  
  logic [vc_num-1:0]                   request_array [prio_num-1:0]        ;
 
  wire [logVcPrio-1:0]                 selected_vc                         ;
  //wire [prio_num * vc_num-1 :0]        has_packet;
 // wire                                 grant_valid;
   
    
  /*helper signals used for interface connections*/
  wire [prio_num * vc_num -1:0][127:0] data_from_fifo                      ; /*= '{default:0};*/
  wire [prio_num * vc_num -1:0]        valid_from_fifo                     ;
  wire                                 last_from_fifo                      ;
      
  wire [prio_num * vc_num -1:0]        fifo_empty                          ;
  wire [prio_num * vc_num -1:0]        fifo_prog_full                      ;    
  wire [prio_num * vc_num -1:0]        fifo_full;    
      
  wire [128:0]                         fifo_rd_data [prio_num * vc_num-1:0];
  wire [128:0]                         fifo_wr_data [prio_num * vc_num-1:0];  
  wire [prio_num * vc_num-1 :0]        fifo_enq                            ;    
  wire [prio_num * vc_num-1 :0]        fifo_deq                            ; 
  wire                                 fifo_deq_drop                       ;
  
  wire [prio_num-1:0]                  rr_go                               ;
  wire [prio_num-1:0]                  rr_go_after_prio_enf                ;
  wire [vc_num-1:0]                    select_array[prio_num-1:0]          ;
  wire [logPrio-1 :0]                  prio_sel                            ;
  wire [logVc-1 :0]                    vc_sel                              ;
      
  reg [1:0]                            state_d,state_q                     ;    
  reg [1:0]                            fsm_state                           ;     
  reg [prio_num-1:0]                   rr_go_after_prio_enf_q              ;
 
  reg [logPrio-1 :0]                   prio_sel_q                          ;
  reg [logVc-1 :0]                     vc_sel_q                            ;
   
  reg [prio_num-1:0]                   rr_go_q                             ;
//  reg                                  second_condition_rr_go_q;
 // wire                                 second_condition_rr_go;
  
  
  counter_t pkt_counter;
  assign o_pkt_counter = pkt_counter;
  
  
  reg [3:0] testing_counter = 0;
 // reg footer_valid_q;
  
  genvar i,j;
   
 /*implement pkt counter logic here*/   
  always @(posedge S_ACLK) begin
    if (~S_ARESETN) begin
      pkt_counter.hdr <= 0;
      pkt_counter.pld <= 0;
      pkt_counter.ftr <= 0;
     // footer_valid_q  <= 0;
     //  second_condition_rr_go_q <=0;
      prio_sel_q      <= 0;
      vc_sel_q        <= 0; 
      rr_go_q         <= 0;
      
    end
    else begin
   
      if (exanet_tx.header_valid & exanet_tx.header_ready)
        pkt_counter.hdr <= pkt_counter.hdr + 1;
      if (exanet_tx.payload_valid & exanet_tx.payload_ready)
        pkt_counter.pld <= pkt_counter.pld + 1;
      if (exanet_tx.footer_valid & exanet_tx.footer_ready)
        pkt_counter.ftr <= pkt_counter.ftr + 1;    

      //footer_valid_q <= exanet_tx.footer_valid;// delay footer_valid one cycle, so we can use it for dropping fifo_deq
       
      
     /* 
      if(second_condition_rr_go)
        second_condition_rr_go_q <= second_condition_rr_go;
      else if(exanet_tx.header_valid & exanet_tx.header_ready)
        second_condition_rr_go_q <= 0;
      */  
       if(rr_go != 0)begin
         prio_sel_q             <= prio_sel;
         vc_sel_q               <= vc_sel;  
         rr_go_q                <= rr_go;
       end
       
       if(exanet_tx.payload_valid & exanet_tx.payload_ready)
         rr_go_q                <= 0; // it needs to be reset, so rr_go can be asserted for the next packet
         
       /*
       if(request_array == 0 & fsm_state == Sop_st)begin
         prio_sel_q               <= 0;
         vc_sel_q                 <= 0; 
       end
        */
        
      
    end  
  end

 
  
  always_ff @(posedge S_ACLK) begin
    if(!S_ARESETN) begin
      
      rr_go_after_prio_enf_q   <= 0;
    end
    else begin
      if(rr_go_after_prio_enf != 0)//There is no need to check the fsm state because rr_go is != 0 only in state IDDLE
        rr_go_after_prio_enf_q <= rr_go_after_prio_enf; //rr_go_after_prio_enf should be latched because we will use it in the next cycle     
    end 
    
  end

  generate 
  
    for(i=0; i<prio_num; i++) begin : PRIO
      for(j=0; j<vc_num; j++) begin : VC
	  	  
	  //  assign data_from_fifo[i*vc_num + j]       = (fifo_deq[i*vc_num + j]) ? fifo_rd_data[i*vc_num + j][127:0] : data_from_fifo[i*vc_num + j];// same comment as fifo_wr_data
		assign data_from_fifo[i*vc_num + j]       = (!S_ARESETN) ? 0 : ((fifo_deq[i*vc_num + j]) ? fifo_rd_data[i*vc_num + j][127:0] : data_from_fifo[i*vc_num + j]);
		assign valid_from_fifo[i*vc_num + j]      = !fifo_empty[i*vc_num + j];//
		
		assign fifo_wr_data[i*vc_num + j]         = (S_AXIS.TVALID & ( i_output_vc == i*vc_num + j)) ? {S_AXIS.TLAST,S_AXIS.TDATA} : 0;// Does any condition need to be checked ?? or fifo_enq's conditions do the job?
	
		
		assign fifo_enq[i*vc_num + j]             = S_AXIS.TVALID & ( i_output_vc == i*vc_num + j);
		//without !footer_valid_q, fifo_deq could not be droped after tlast become low, because selected_vc changes one cycle later....*****!fifo_empty may be useless now****
        assign fifo_deq[i*vc_num + j]             = ((selected_vc == i*vc_num + j) & !fifo_empty[selected_vc] /*& !footer_valid_q*/) ? ((exanet_tx.header_valid & exanet_tx.header_ready) |
                                                                                                                                   (exanet_tx.payload_valid & exanet_tx.payload_ready) | 
                                                                                                                                    (exanet_tx.footer_valid & exanet_tx.footer_ready)) : 0;
		
		
		
		//******TEST 08/03/2022*********
	    assign request_array[i][j] = /*fifo_enq[i*vc_num + j] | */(!fifo_empty[i*vc_num + j]);
		
		exa_fifo # (
          .DEPTH             ( out_fifo_depth ),
          .DWIDTH            ( 129 ),
          .ALL_REGD          (   1 ),
          .DISTURBED         (   1 ),
          .PROG_FULL_ASSERT  (  18 ),
          .PROG_FULL_NEGATE  (  19 )
        ) in_fifo (
          .arst_n       ( S_ARESETN ),
          .clk          ( S_ACLK ),
          .i_wr_data    ( fifo_wr_data[i*vc_num + j] ),
          .i_wr_en      ( fifo_enq[i*vc_num + j]),
          .o_full       ( fifo_full[i*vc_num + j]  ),
          .o_prog_full  ( fifo_prog_full[i*vc_num + j] ),
          .o_wr_words   ( ),      
          .o_rd_data    ( fifo_rd_data[i*vc_num + j] ),
          .i_rd_en      ( fifo_deq[(i*vc_num + j)] ),
          .o_empty      ( fifo_empty[(i*vc_num + j)] )
        );
	
	  
	  end//end of VC Loop
	 
	
	//TRUE
	// assign rr_go[i] = (request_array[i]!=0) & (fsm_state == Sop_st & exanet_tx.header_ready); // without header_ready, rr_go may be high too early..So that, the selected_vc may be wrong because another vc may be not empty, until ready signal turns to high
	 
	//testing - 09/03/2022 firstly ->  
	/*exanet_tx.header_ready is added in this condition because, in case that exanet_tx.header_ready is low, rr_go should wait...rr_go_q may be unnecessary*/
	assign rr_go[i] = ((request_array[i]!=0) & (fsm_state == Sop_st) & /*!rr_go_q &*/ exanet_tx.header_ready);
	
	
	// assign second_condition_rr_go  = (request_array[i]!=0) & last_from_fifo & exanet_tx.footer_ready;
	 //assign rr_go[i] = ((request_array[i]!=0) & (fsm_state == Sop_st) & !rr_go_q & !second_condition_rr_go_q) |((request_array[i]!=0) & last_from_fifo & exanet_tx.footer_ready);// (request_array[i]!=0) & last_from_fifo & exanet_tx.footer_ready) extra
	 //rr_go_q was used for turnig rr_go low one cycle later
	  // Testing .....
	 // assign rr_go[i] =(testing_counter == 1) ? ((request_array[i]!=0) & (fsm_state == Sop_st & exanet_tx.header_ready)) : ((request_array[i]!=0) & last_from_fifo) ;
	  
    end//end of PRIO Loop
	
  endgenerate	
     

    //assuming that high prio = 1 , low prio = 0
  generate
    if      (prio_num <= 2) begin
                                       assign rr_go_after_prio_enf =     rr_go[1] ? 2'b10 :
                                                                         rr_go[0] ? 2'b01 : 2'b00; 
    end
    else if (prio_num <= 4) begin  assign rr_go_after_prio_enf =         rr_go[3] ? 4'b1000 :
                                                                         rr_go[2] ? 4'b0100 :
                                                                         rr_go[1] ? 4'b0010 : 
                                                                         rr_go[0] ? 4'b0001 : 4'b0000;     
    end
    else if (prio_num <= 8) begin  assign rr_go_after_prio_enf =         rr_go[7] ? 8'b10000000 :
                                                                         rr_go[6] ? 8'b01000000 :
                                                                         rr_go[5] ? 8'b00100000 :
                                                                         rr_go[4] ? 8'b00010000 :                                                                                            
                                                                         rr_go[3] ? 8'b00001000 :        
                                                                         rr_go[2] ? 8'b00000100 :       
                                                                         rr_go[1] ? 8'b00000010 :
                                                                         rr_go[0] ? 8'b00000001 : 8'b00000000; 
    end                                                                                    
  endgenerate
         
  //generate the RR arbiters*/
  generate 
    for (i = 0 ; i < prio_num ; i = i+1) begin : rr_gen
      ss_out_rr # (
        .input_num(vc_num)
          )ss_out_rr(
        .clk(S_ACLK),
        .resetn(S_ARESETN),
        .i_request(request_array[i]),
        .o_out(select_array[i]),
        .o_has(),
        .go(rr_go_after_prio_enf[i])
     );
    end
  endgenerate 
/*we know which prio was served, so make it binary to select the correct select array*/
  ss_1h_to_b #(
    .input_width(prio_num)
   ) ss_go_to_sel (
    .i_in(rr_go_after_prio_enf),
    .o_out(prio_sel)
  );
  //convert the one-hot array of the selected prio, to binary number of vc.
  ss_1h_to_b #(
      .input_width(vc_num)
    ) ss_grant_to_sel (
      .i_in(select_array[prio_sel]),
      .o_out(vc_sel)
    );

   
  assign selected_vc             = (rr_go != 0) ? prio_sel*vc_num + vc_sel : prio_sel_q*vc_num + vc_sel_q;
  assign last_from_fifo          = (fifo_deq[selected_vc] != 0) ? fifo_rd_data[selected_vc][128] : 0;//********* IF selected_vc be saved in register, should any condition be added?? *****
 
 // assign grant_valid             = (state_q == REQUESTED) & request_array[prio_sel][vc_sel] & request_array_q[prio_sel][vc_sel];
  
  
  
  
  
  // ****fifo_empty != 1111( ** =  ^  ) or 15(supposed prio_num*vc_num = 4), so there is at least one fifo that is not empty ******	
  /*
  assign exanet_tx.header_valid  = fifo_empty != (2**(prio_num*vc_num) - 1) & fsm_state == Sop_st;                   
  assign exanet_tx.payload_valid = fifo_empty != (2**(prio_num*vc_num) - 1) & (fsm_state == Sop_Wait) & !last_from_fifo;
  assign exanet_tx.footer_valid  = fifo_empty != (2**(prio_num*vc_num) - 1) & (fsm_state == Sop_Wait) & last_from_fifo;
  */


  assign exanet_tx.header_valid  = fifo_empty != (2**(prio_num*vc_num) - 1) & fsm_state == Sop_st; 
   /*!fifo_empty[selected_vc] is needed bacause fifo may get empty  at any time, so valid signal should get down */                  
  assign exanet_tx.payload_valid = !fifo_empty[selected_vc] & (fsm_state == Sop_Wait) & !last_from_fifo;
  assign exanet_tx.footer_valid  = fifo_empty != (2**(prio_num*vc_num) - 1) & (fsm_state == Sop_Wait) & last_from_fifo; 
  
  assign exanet_tx.data          = data_from_fifo[selected_vc];	  
  
  assign o_fifo_full             = fifo_prog_full;
  
      // ******************************** FSM ********************
  always @(posedge S_ACLK) begin
    if(~S_ARESETN) 
     fsm_state <=  Sop_st;
    else begin
      case(fsm_state)
      
        Sop_st :
        begin
          if(fifo_empty != (2**(prio_num*vc_num) - 1) & exanet_tx.header_ready )         
            fsm_state <=  Sop_Wait;
          else 
            fsm_state <=  Sop_st;
          end
        
        Sop_Wait :
        begin
     // ****fifo_empty != 1111 or 15(supposed prio_num*vc_num = 4), so there is at least one fifo that is not empty ******
          if(fifo_empty != (2**(prio_num*vc_num) - 1) & last_from_fifo & exanet_tx.footer_ready) // there was   S_AXIS.TVALID instead of fifo_empty     
            fsm_state <=  Sop_st;
          else 
            fsm_state <=  Sop_Wait;
        end      
        default  :
          fsm_state <=  Sop_st;
      endcase
    end
  end//fsm ends here



 /*
    
  always_ff @(posedge S_ACLK) begin
     if(!S_ARESETN) begin
       state_q <= IDDLE;
     end
     else begin
       state_q <= state_d;
     end
   end
 
  
           
  always_comb begin
     state_d = state_q;
     case(state_q)
       IDDLE:
         if(request_array != 0) begin
           state_d = REQUESTED;
         end
         else 
           state_d = IDDLE;
           
       REQUESTED:
         if(grant_valid)
           state_d = GRANTED;
         else
           state_d = IDDLE; 
       
       GRANTED:
         if(i_last)
           state_d = IDDLE;
         else
           state_d = GRANTED;
       default:     
         state_d = IDDLE;
                       
     endcase    
  end
  */
  
  /************** may be useless ************/
  /*
  always_comb begin
    state_d = state_q;
    case(state_q)
      IDDLE:
        if(request_array != 0 & exanet_tx.header_ready) begin
          state_d = GRANTED;
        end
        else 
          state_d = IDDLE;
      GRANTED:
        if(last_from_fifo)
          state_d = IDDLE;
        else
          state_d = GRANTED;
      default:     
        state_d = IDDLE;
                       
    endcase    
  end
   
  */
endmodule			  