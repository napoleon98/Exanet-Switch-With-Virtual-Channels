`timescale 1ns / 1ps
`include "ceiling_up_log2.vh"


module exa_crosb_output_arbiter_with_VCs#(
	 parameter prio_num  	= 2,       
	 parameter output_num 	= 4,
	 parameter vc_num       = 2,
	 parameter input_num    = 4,
	 parameter logVcPrio    = `log2(prio_num*vc_num),
     parameter logOutput    = `log2(output_num),
     parameter logPrio      = `log2(prio_num),
     parameter logVc        = `log2(vc_num),
     parameter logInput     = `log2(input_num)
)(   
     input                                                    clk,
     input                                                    resetn,
     input [vc_num*prio_num-1:0]                              i_request[input_num-1:0],
     input                                                    i_last,
     input                                                    cts_from_input_arbiter,              
     output [input_num-1:0]                                   o_grant,
     output [(logInput-1):0]                                  o_input_sel
   
 );

 
  reg [1:0]                         state_q; 
 
  reg [logInput-1 :0]               input_sel_q;
  
  reg [logPrio-1 :0]                prio_sel_q;
  reg [input_num-1:0]               grant_q;
  
  logic [1:0]                       state_d;

  
  logic [input_num-1:0]             request_array [prio_num-1:0];

  wire [prio_num-1:0]               rr_go;
  wire [prio_num-1:0]               rr_go_after_prio_enf;
  wire [input_num-1:0]              grant_array[prio_num-1:0];
  wire [input_num-1:0]              grant_d;
  wire [logPrio-1 :0]               prio_sel;
  wire [logInput-1 :0]              input_sel;

  
  
  localparam  IDDLE	    = 2'b00, 	
              REQUESTED = 2'b01,
              GRANTED   = 2'b10;
              
  
  always_ff @(posedge clk) begin
    if(!resetn) begin
      state_q <= IDDLE;
    end
    else begin
      state_q <= state_d;
    end
  end
  

  
  
  genvar i,j;
  //check if any channel of input i and prio j has request and in this case set 1 to the corrresponding cell in request_array
  for(i=0;i<input_num;i++)begin
    for(j=0;j<prio_num;j++)begin
   
      assign request_array[j][i] = (i_request[i][(j+1)*vc_num -1 : j*vc_num]) ? 1 : 0; //i_request[i][(j+1)*vc_num -1 : j*vc_num] contains "vc_num" bits.So we separate the requests of each prio
         
    end
  end 
 
  

  
  generate 
    for(i=0;i<prio_num;i++)begin
      assign rr_go[i] = (request_array[i]!=0) & (state_q == IDDLE);// rr_go is high for one cycle(fsm  changes state)
    end
  endgenerate
  
  generate
      if      (prio_num <= 2) begin
                                     assign rr_go_after_prio_enf =     rr_go[1] ? 2'b10 :
                                                                       rr_go[0] ? 2'b01 : 2'b00; 
      end
      else if (prio_num <= 4) begin  assign rr_go_after_prio_enf =     rr_go[3] ? 4'b1000 :
                                                                       rr_go[2] ? 4'b0100 :
                                                                       rr_go[1] ? 4'b0010 : 
                                                                       rr_go[0] ? 4'b0001 : 4'b0000;     
      end
      else if (prio_num <= 8) begin  assign rr_go_after_prio_enf =     rr_go[7] ? 8'b10000000 :
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
        .input_num(input_num)
          )ss_out_rr(
        .clk(clk),
        .resetn(resetn),
        .i_request(request_array[i]),
        .o_out(grant_array[i]),
        .go(rr_go_after_prio_enf[i])

      );
    end
  endgenerate
     /*we know which prio was served, so make it binary to select the correct grant array*/ 
  ss_1h_to_b #(
    .input_width(prio_num)
   ) ss_go_to_sel (
    .i_in(rr_go_after_prio_enf),
    .o_out(prio_sel)
  );
  
   //convert the one-hot array of the selected prio, to binary number of input.
  ss_1h_to_b #(
      .input_width(input_num)
    ) ss_grant_to_sel (
      .i_in(grant_array[prio_sel]),
      .o_out(input_sel)
    );
    
    always_ff @(posedge clk) begin
      if(!resetn)begin
        input_sel_q <= 0;
        prio_sel_q  <= 0;
        grant_q     <= 0;
        
      end
      else begin
        if(rr_go)begin 
          input_sel_q <= input_sel;
          prio_sel_q  <= prio_sel;
          grant_q     <= grant_d;
        end
      end
    end
    
    
      
    
 
  assign grant_d     = grant_array[prio_sel];

  assign o_grant     = (state_q == GRANTED) ? grant_q : grant_d ;
 
  assign o_input_sel = (state_q == GRANTED) ? input_sel_q : input_sel;
  

  
  /* ******************************************FSM  IMPLEMELTATION *******************************/
  always_comb begin
    state_d = state_q;
    case(state_q)
      IDDLE:
        if(rr_go ) 
          state_d = GRANTED;
        else
          state_d = IDDLE;
   
      GRANTED:
        if(i_last | !cts_from_input_arbiter)
          state_d = IDDLE;
        else
          state_d = GRANTED;
      default:
        state_d = IDDLE; 
        
    endcase
  end
      
  
endmodule
