`timescale 1ns / 1ps

/* This module simulates output arbiter. It can grant a request either at the same cycle that this request is generated, or after 
  a random number of cycles.  */

module granter_from_output_arbiter #(
  
    parameter vc_num   = 3,
    parameter prio_num = 2,
    parameter output_num = 8


)(
  
  input                                        clk,
  input                                        resetn,
  input                                        last,
  input [prio_num*vc_num-1:0]                  selected_request [output_num-1:0],
  input logic[$clog2(output_num)-1 :0]              output_dest,
  input logic [$clog2(vc_num*prio_num)-1:0]          output_vc_dest,

  output  [output_num-1:0]                      grant_from_output_arbiter


);


  localparam IDLE = 2'b00,
             WAITING  = 2'b01,
             GRANTED  = 2'b10;
             
  reg                          delay;
  reg                          with_delay;
  reg [3:0]                    counter;
  reg [3:0]                    num_of_delay_cycles;
  reg [1:0]                    state_q ;           
  logic [1:0]                  state_d ; 
 
  
  always @(posedge clk) begin
    if (~resetn) 
      state_q <=  IDLE;
    else
      state_q <=  state_d;
  end
  
  always @(posedge clk)begin
    if (~resetn) begin
      counter <= 0;
      with_delay  <= 0;
      num_of_delay_cycles <= 0;
    end
    else begin
      if(state_q == IDLE)begin
       
        num_of_delay_cycles <= 3;//$urandom() % 3 + 1;
        /* This signal will determine if the input request will be granted at the same cycle or not*/
        with_delay          <= 1;//$urandom();
      end
     
    end
  end
   
  always @(posedge clk)begin
  /*In case that with_delay is high, or state==Waiting, increase counter*/
    if((state_q == IDLE & selected_request != 0 & with_delay) | state_q == WAITING)
      counter <= counter + 1;
    
    if(state_q == GRANTED)
      counter <= 0;
      
  end
  
  
  
  always_comb begin
    state_d = state_q;
    case(state_q)
      IDLE:
        if(selected_request != 0)begin
          if(with_delay)
            state_d = WAITING;
          else
            state_d = GRANTED;
        end
        else
          state_d = IDLE;
      WAITING:
        if(counter == num_of_delay_cycles)
          state_d = GRANTED;
        else
          state_d = WAITING;
      GRANTED:
        if(last)
          state_d = IDLE;
        else
          state_d = GRANTED;
      default: 	
        state_d = IDLE;
    endcase
  end
  
  genvar i,j,k;
  generate
    for (i=0; i<output_num ; i = i+1) begin
   
       assign grant_from_output_arbiter[i] = ((selected_request !=0 & !with_delay & state_q == IDLE) | 
                                              (state_q== WAITING & counter == num_of_delay_cycles) | state_q == GRANTED) ? (output_dest == i) : 0;//***** change******
    end
  endgenerate
  
  











endmodule
