`timescale 1ns / 1ps
`include "ceiling_up_log2.vh"


module exa_crosb_input_arbiter_with_VCs #(
	 parameter prio_num  	= 2,       
	 parameter output_num 	= 4,
	 parameter vc_num       = 2,
	 parameter logVcPrio    = `log2(prio_num*vc_num),
	 parameter logOutput    = `log2(output_num),
	 parameter logPrio      = `log2(prio_num),
	 parameter logVc        = `log2(vc_num)
	 
)(
  
    input						                clk,
	input						                resetn,
    input  [vc_num*prio_num-1:0]                i_has_packet,
	//input  [`log2(output_num)-1 :0]            i_dest [prio_num*vc_num-1 :0],// destination of the packet
	input  [logOutput-1 :0]                     i_dest [prio_num*vc_num-1 :0],
    //input  [vc_num*prio_num-1:0]                i_grant_from_output_arbiter[output_num-1:0],//************** dimension [vc_num*prio_num-1:0] may be useless *************	
    input  [output_num-1:0]                     i_grant_from_output_arbiter,
    input						                i_last,
    input  [vc_num*prio_num-1:0]                output_fifo_credits [output_num-1:0], 
    input  [logVcPrio-1:0]                      i_output_vc [vc_num*prio_num-1:0], // should be latched...s
    
    output logic [logVcPrio-1:0]                o_output_vc [vc_num*prio_num-1:0],
    output [prio_num*vc_num-1:0]                o_selected_request [output_num-1:0],
   // output logic [`log2(output_num)-1 :0]      o_dest [prio_num*vc_num-1 :0],
    output logic [logOutput-1 :0]               o_dest [prio_num*vc_num-1 :0],
    output                                      o_cts,
    output [logVcPrio - 1 : 0]                  o_selected_vc,/*[`log2(vc_num*prio_num)-1:0]   */ 
    output [vc_num-1:0]                         o_request_array [prio_num-1:0],//**************just for testing**************
    output [prio_num*vc_num-1:0]                o_request_to_output_arbiter,
    output [logOutput-1 :0]                     o_dest_output,//**************just for testing**************
    output [logVcPrio-1 :0]                     o_dest_vc//**************just for testing**************.
    
);

  
  reg [1:0]                         state_q; 
  //reg [`log2(output_num)-1 :0]     dest_q [prio_num*vc_num-1 :0];
  reg [logOutput-1 :0]           dest_q [prio_num*vc_num-1 :0];
  reg [logVcPrio-1:0] output_vc_q [vc_num*prio_num-1:0];
  reg [prio_num-1:0]                has_request_after_prio_enf_q;
  reg [logPrio-1 :0]       prio_sel_q;
  reg [logVc-1 :0]         vc_sel_q;
  reg [prio_num-1:0]                has_request_q;
  
  reg                               grant_from_output_arbiter_q;
 
  reg [logOutput-1 :0]     dest_output_q;
  reg [logVcPrio-1 :0]dest_vc_q;
  reg [logVcPrio-1:0] selected_vc_q;
  
  logic [1:0]                       state_d; 
  
  wire [vc_num-1:0]                 request_array [prio_num-1:0];
  wire [vc_num-1:0]                 has_packet [prio_num-1:0];
  wire [prio_num-1:0]               has_request;
  
  wire [prio_num-1:0]               has_request_after_prio_enf;
  wire [vc_num-1:0]                 select_array [prio_num-1:0];
  wire [logPrio-1 :0]               prio_sel;
  wire [logVc-1 :0]                 vc_sel;
  wire [prio_num*vc_num-1:0]        selected_request [output_num-1:0] ;
  wire [logPrio-1 :0]               selected_prio; 
  wire [logVc-1 :0]                 selected_vc_per_prio;                       
  
  
  wire [logOutput-1 :0]             dest_output;
  wire [logVcPrio-1 :0]             dest_vc;
  wire                              grant_from_output_arbiter;
  wire  [prio_num-1:0]              grant_from_output_arbiter_per_prio;
 
 
  wire  [prio_num-1:0]              go_high;
  wire  [prio_num-1:0]              go_rr;
  
    
  
  
  localparam  IDLE	    = 2'b00, 	
              REQUESTED = 2'b01,
              GRANTED   = 2'b10;
             
              
  
  always_ff @(posedge clk) begin
    if (!resetn) begin
      state_q   <= IDLE;
      
    end else begin
      state_q   <=  state_d;
    end    
  end 
  
  
 
                      
  genvar i,j;
  generate
  // Create request arrays
    for(i=0; i<prio_num; i++) begin:PRIO
      for(j=0; j<vc_num; j++)begin:VCs
        /*check which input channels have packet and if the destination output channel has space to accomodate it..
        In case that these requirements are met,  a request is added in the (high/low prio) request_array  */
          assign request_array[i][j] = (state_q == IDLE)  ? (i_has_packet[i*vc_num + j] & output_fifo_credits[i_dest[i*vc_num + j]][i_output_vc[i*vc_num + j]]) :  //when fsm state will be REQUESTED and request will be granted, then cts is high so dequeue is high and i_dest will be lost)
                                                            (i_has_packet[i*vc_num + j] & output_fifo_credits[dest_q[i*vc_num + j]][output_vc_q[i*vc_num + j]]) ;                            
                                                                      //************************************************************************************************ i_output_vc[i*vc_num + j] could be replaced by i*vc_num + j if output vc doesn't change
          assign has_packet[i][j]    = i_has_packet[i*vc_num + j]; 
      end
      
      assign grant_from_output_arbiter_per_prio[i] = (selected_prio == i) ? grant_from_output_arbiter : 0;//it was grant_from_output_arbiter_q
      
      /*this signal is used in case that grant_from_output_arbiter is asserted in same cycle that input arbiter get its request out(so between two different grants from output arbiter,
       grant_from_output_signal doesn't get low)...if o_selected_vc has changed and grant_from_output_arbiter is high, turn go high
       In case that the same selected_vc is granted more than one time without any one to be interleaved, there is no need to turn go_rr high*/
      assign go_high[i] = ((selected_vc_q != o_selected_vc) & grant_from_output_arbiter_per_prio[i]); 
       
                                
      assign has_request[i] = (request_array[i]!=0 & state_q == IDLE); /*& has_request_q == 0) | (has_request_q != 0 & state_q == IDLE & has_request_after_prio_enf_q == 2'b01 & request_array[1] !=0)
                                                                               | (has_request_q != 0 & state_q == IDLE & request_array[prio_sel_q][vc_sel_q] == 0 & request_array[i]!=0 );*/
    
      assign go_rr[i] = (grant_from_output_arbiter_per_prio[i] & !grant_from_output_arbiter_q) | go_high[i] ;
    end 
  endgenerate
  
  assign o_request_array = request_array;
  //assuming that high prio = 1 , low prio = 0
  generate
    if      (prio_num <= 2) begin
                                   assign has_request_after_prio_enf =     has_request[1] ? 2'b10 :
                                                                           has_request[0] ? 2'b01 : 2'b00; 
    end
    else if (prio_num <= 4) begin  assign has_request_after_prio_enf =     has_request[3] ? 4'b1000 :
                                                                           has_request[2] ? 4'b0100 :
                                                                           has_request[1] ? 4'b0010 : 
                                                                           has_request[0] ? 4'b0001 : 4'b0000;     
    end
    else if (prio_num <= 8) begin  assign has_request_after_prio_enf =     has_request[7] ? 8'b10000000 :
                                                                           has_request[6] ? 8'b01000000 :
                                                                           has_request[5] ? 8'b00100000 :
                                                                           has_request[4] ? 8'b00010000 :                                                                                            
                                                                           has_request[3] ? 8'b00001000 :        
                                                                           has_request[2] ? 8'b00000100 :       
                                                                           has_request[1] ? 8'b00000010 :
                                                                           has_request[0] ? 8'b00000001 : 8'b00000000; 
    end                                                                                    
  endgenerate
  
  always_ff @(posedge clk) begin
    if(!resetn) begin
      grant_from_output_arbiter_q    <=0;
      has_request_after_prio_enf_q   <= 0;
      dest_q                         <= '{default:0};//'{'{0},'{0},/*'{0},'{0},*/'{0},'{0}};
      output_vc_q                    <= '{default:0};//'{'{0},'{0},/*'{0},'{0},*/'{0},'{0}};
      has_request_q                  <= 0;
      
     
      dest_vc_q                      <=0;
      selected_vc_q                  <= prio_sel*vc_num + vc_sel;
      dest_output_q                  <= 0;
      
    end
    else begin
      if(has_request_after_prio_enf != 0)//There is no need to check the fsm state because has_request is != 0 only in state IDLE
        has_request_after_prio_enf_q <= has_request_after_prio_enf; //has_request_after_prio_enf should be latched because we will use it in the next cycle
    
    
      grant_from_output_arbiter_q   <= grant_from_output_arbiter;      
      
      
      if(grant_from_output_arbiter)begin
        dest_vc_q                  <= dest_vc;
        selected_vc_q              <= o_selected_vc;
        dest_output_q              <= dest_output;
      end
      
      if(state_q == IDLE & grant_from_output_arbiter) begin
        dest_q                    <= i_dest;
        output_vc_q               <= i_output_vc;
       
      end
      if(state_q == IDLE & grant_from_output_arbiter)begin
         prio_sel_q               <= prio_sel;
         vc_sel_q                 <= vc_sel;  
      end
      if(has_request == 0/*request_array == 0*/ & state_q == IDLE) begin
        dest_q                    <= '{default:0};//'{'{0},'{0},/*'{0},'{0},*/'{0},'{0}};
        output_vc_q               <= '{default:0};//'{'{0},'{0},/*'{0},'{0},*/'{0},'{0}};
        prio_sel_q                <= 0;
        vc_sel_q                  <= 0; 
      end
      if(has_request != 0)begin
        has_request_q             <= has_request; 
       
      end 
      else if(state_q == GRANTED)
        has_request_q             <= 0;
       
      
    end 
    
  end
 
  //generate the RR arbiters*/
  generate 
    for (i = 0 ; i < prio_num ; i = i+1) begin : rr_gen
      ss_out_rr # (
        .input_num(vc_num)
      )ss_out_rr(
        .clk(clk),
        .resetn(resetn),
        .i_request(request_array[i]),
        .o_out(select_array[i]),
        .o_has(),
        .go(go_rr[i])//it was has_request_after_prio_enf[i]
      );
    end
  endgenerate
  /*we know which prio was served, so make it binary to select the correct select array*/
    ss_1h_to_b #(
      .input_width(prio_num)
     ) ss_go_to_sel (
      .i_in(has_request_after_prio_enf),//******CHANGE**** it was has_request_after_prio_enf_q
      .o_out(prio_sel)
    );
    //convert the one-hot array of the selected prio, to binary number of vc.
    ss_1h_to_b #(
        .input_width(vc_num)
      ) ss_grant_to_sel (
        .i_in(select_array[prio_sel]),
        .o_out(vc_sel)
      );
  
  genvar k;
  //array output_num X (vc_num*prio_num).The cell with coordinates (destination output)(output_vc) will be filled with 1
  generate
    for (i=0; i<output_num ; i = i+1) begin
      for(j=0; j<prio_num; j++)begin
        for(k=0; k<vc_num; k++)begin
        /*we need to check request_packet(instead of has_packet, has_packet was wrong), because non valid request_to_output are generated */
          assign o_request_to_output_arbiter[j*vc_num + k] = (o_selected_vc == j*vc_num + k &(request_array[selected_prio][selected_vc_per_prio] != 0)) ? 1 : 0;
          assign selected_request[i][j*vc_num + k] = (has_request != 0/*request_array != 0*/) ? (dest_output == i) & (dest_vc == j*vc_num + k) : 0;//***** change******
        end
      end
    end
  endgenerate
  
  assign o_selected_request        = selected_request;
 
 // assign dest_output               = (state_q == IDLE) ? 0 : dest_q[prio_sel*vc_num + vc_sel];//num of output destination  of "vc_sel" vc of "prio_sel" priority
  //assign dest_output               = (has_request != 0) ? i_dest[prio_sel*vc_num + vc_sel] : dest_q[prio_sel_q*vc_num + vc_sel_q];
  assign dest_output               = (state_q != GRANTED) ?((has_request != 0/*request_array!=0*/) ? o_dest[prio_sel*vc_num + vc_sel] : 0) : o_dest[prio_sel_q*vc_num + vc_sel_q];
  assign o_dest_output             = dest_output; //**************just for testing**************
  //assign dest_vc                   = (state_q == IDLE) ? 0 : output_vc_q[prio_sel*vc_num + vc_sel]; //num of output vc  of "vc_sel" vc of "prio_sel" priority
  assign dest_vc                   = (state_q != GRANTED) ?((has_request != 0/*request_array!=0**/) ? o_output_vc[prio_sel*vc_num + vc_sel] : 0) : o_output_vc[prio_sel_q*vc_num + vc_sel_q]; 
  assign o_dest_vc                 = dest_vc; //**************just for testing**************
  assign grant_from_output_arbiter = i_grant_from_output_arbiter[dest_output];//[dest_vc];// grant of the destination vc of the destination output
  
  // if we don't want the selected_vc to change value(turns to 0) when there is not any request, the condition should change in has_request !=0 
  //assign o_selected_vc             = (has_request != 0) ? prio_sel*vc_num + vc_sel : prio_sel_q*vc_num + vc_sel_q ;// input vc whose request was selected
  assign o_selected_vc             = (state_q != GRANTED) ?  prio_sel*vc_num + vc_sel : prio_sel_q*vc_num + vc_sel_q;
  assign selected_vc_per_prio      = (state_q != GRANTED) ? vc_sel : vc_sel_q;
  assign selected_prio             = (state_q != GRANTED) ? prio_sel : prio_sel_q;
  
 
  
  /* ***********FSM  IMPLEMELTATION ********************/

  always_comb begin
     state_d = state_q;
     case(state_q)
       IDLE:
         if(grant_from_output_arbiter)begin
           state_d = GRANTED;
           //if grant from output arbiter for a low prio req, arrives at the same time that a high prio req is asserted, high prio is prioritised.
          /* if(has_request_after_prio_enf_q == 2'b01 & has_request == 0)begin *//*has_request == 0 is used because has_request_after_prio_enf_q delays one cycle to load the correct number, so if has_request !=0 ,it means that has_request_after_prio_enf_q has a previous- wrong value.*/
          /*    if(request_array[1] == 0)
                state_d = GRANTED;
              else
                state_d = IDLE;     
           end
           //if grant from output arbiter is for a high prio req or grant from output arbiter arrives at the same cycle(don't care if grant is for a high or low prio req), just change state
           else
             state_d = GRANTED; */ 
         end
         else 
           state_d = IDLE; 
         
       GRANTED:
         if(i_last)
           state_d = IDLE;
         else
           state_d = GRANTED;
       default: 	
         state_d = IDLE;
                     
     endcase    
  end
  
  
  
  
  assign o_dest      = (state_q != GRANTED) ? i_dest : dest_q;
  assign o_output_vc = (state_q != GRANTED) ? i_output_vc : output_vc_q;
  /*assign o_cts       = (has_request_after_prio_enf_q == 2'b01) ? ((state_q == IDLE & grant_from_output_arbiter & request_array[1] == 0 & has_request == 0) | (state_q == GRANTED)) :
                                                           ((state_q == IDLE & grant_from_output_arbiter) | (state_q == GRANTED));*/
                                                           
  assign o_cts       = (state_q == IDLE & grant_from_output_arbiter) | (state_q == GRANTED);

 
endmodule
