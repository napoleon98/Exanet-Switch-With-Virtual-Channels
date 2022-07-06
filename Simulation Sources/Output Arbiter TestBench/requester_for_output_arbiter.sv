`timescale 1ns / 1ps

module requester_for_output_arbiter #(
  parameter vc_num    = 3,
  parameter prio_num  = 2,
  parameter input_num = 4


)(
  input                               clk,
  input                               resetn,
  input                               last,
  input                               fixed_inputs_enable,
  input [input_num - 1:0]             fixed_inputs,
  input                               initialize,
  input [$clog2(input_num)-1:0]       selected_input,
  input                               cts,
  
  output [vc_num*prio_num-1:0]        o_request[input_num-1:0]

);
  

    
  reg [1:0]                          state_q [input_num -1:0];
  reg [input_num -1 :0]              rand_input;
  reg [$clog2(vc_num*prio_num)-1 :0] rand_vc [input_num -1:0];
  reg [input_num -1 :0]              rand_drop_request;//it will be used for simulating  a request that has been granted but has been dropped at the same time 
  
  
  logic [1:0]                        state_d [input_num -1:0]; 
  logic [vc_num*prio_num-1:0]        request[input_num-1:0]; 
  logic [vc_num*prio_num-1:0]        fixed_request[input_num-1:0];
  
  logic [3:0]                        last_counter[input_num -1:0];
  logic [1:0]                        rand_packets_per_vc[input_num -1:0];
  
  localparam                         REQUEST_HIGH = 2'b01,
                                     REQUEST_LOW  = 2'b00,
                                     GRANTED      = 2'b10;
               
               
    
  genvar i; 
  generate
  for(i=0;i<input_num;i++)begin  
    always @(posedge clk) begin
      if (~resetn) 
        state_q[i] <=  REQUEST_LOW;
      else
        state_q[i] <=  state_d[i];
      end
    end
  endgenerate
  
  
  generate
    for(i=0;i<input_num;i++)begin  
      always @(posedge clk) begin
        if (~resetn) 
          rand_drop_request[i]   <= 0;
        else begin
          if(state_q[i] == REQUEST_HIGH)
            rand_drop_request[i] <= $urandom();  
          else 
            rand_drop_request[i] <= 0;
        end
         
      end
    end
  endgenerate
  
  
   
   generate
     for(i=0;i<input_num;i++)begin
       always_ff @(posedge clk) begin
         if(!resetn)begin
           rand_packets_per_vc[i] <= 0;
           last_counter[i]         = 0;
           rand_vc[i]             <= 0;
         end
         else begin
           if(state_q[i] == REQUEST_LOW)
             rand_packets_per_vc[i] <= 2; //$urandom() % 2 + 1; // simulate that every channel has 0 - 2 packets  
           if(state_q[i] == REQUEST_LOW )
             rand_vc[i] <= $urandom() % 6;
        end
       end
     end 
   endgenerate
  
  
  always_ff @(posedge clk) begin
    if(!resetn)begin
     // rand_vc           <= 0;
      rand_input        <= 0;
      
    end
    else begin
      //rand_vc             <= $urandom() % 6;
      rand_input          <= $urandom();
      
    end
  end 
  
  

  //Generate as many fsms as the number of inputs 
  generate
  for(i=0;i<input_num;i++)begin  
    always_comb begin
      state_d[i] = state_q[i];
      case(state_q[i])
        REQUEST_LOW:
          if(!initialize & (rand_input[i] != 0))
            state_d[i] = REQUEST_HIGH;
          else
            state_d[i] = REQUEST_LOW;
        REQUEST_HIGH:
          if(cts & (selected_input == i))begin
            state_d[i] = GRANTED;
          end
          else
            state_d[i] = REQUEST_HIGH;
             
        GRANTED:
          if(last /*& (rand_packets_per_vc[i] == last_counter[i])*/)
            state_d[i] = REQUEST_LOW;
          else
            state_d[i] = GRANTED; 
        default:
          state_d[i] = REQUEST_LOW;
      endcase
    end
  end
  endgenerate
  
  
  
  // generate one controller for each input
  generate 
    for(i=0;i<input_num;i++)begin
      always_comb begin 
        if(state_q[i] == REQUEST_LOW)begin
          request[i] = 0;
          last_counter[i] = 0;
          /*
          if(!fixed_inputs_enable)
            fixed_request[i] = fixed_inputs[i];
            */
        end      
        if(state_q[i] == REQUEST_HIGH)begin
          request[i][rand_vc[i]] = 1;//rand_vc 
        end
        /****************RAND DROP*****************/
        //if rand_drop_request[i] is high then request[i] is dropped,
        if(state_q[i] == REQUEST_HIGH & rand_drop_request[i])begin
          request[i] = 0;
        end
        
        if(state_q[i] == GRANTED) begin
          if(!fixed_inputs_enable)begin
            if(last & (selected_input == i))begin
			/*
              last_counter[i] = last_counter[i] + 1;
              if(rand_packets_per_vc[i] == last_counter[i])//When the last of last packet comes, drop request signal for this vc
			  */
              request[i] = 0;
            end
          end
              /*  
              else
                request[i] = 1;// may be useless, because request[i] is already high.
                */
            
            /*
            else
              request[i] = 1;
              */
           
          else begin
            if(last)
              fixed_request[i] = 0;
            else
              fixed_request[i] = 1;
          end
        end
      end
    end 
  endgenerate 
  
  assign o_request = (fixed_inputs_enable) ? fixed_request : request;

endmodule
