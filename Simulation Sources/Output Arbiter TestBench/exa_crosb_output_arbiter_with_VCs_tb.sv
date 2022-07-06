`timescale 1ns / 1ps



module exa_crosb_output_arbiter_with_VCs_tb(
    );
    
     
  localparam prio_num   = 2;
  localparam vc_num     = 3;
  localparam output_num = 8;
  localparam input_num  = 4;
  
  reg    clk            = 0;
  always #5 clk = ~clk;
  reg    resetn         = 0;
  
  logic [vc_num*prio_num-1:0]                              request[input_num-1:0];
  logic [$clog2(vc_num*prio_num)-1:0]                      output_vc [vc_num*prio_num-1:0];
  logic                                                    last;
  //logic [vc_num*prio_num-1:0]                              grant[input_num];
  logic [input_num-1:0]                                    grant;
    
  logic [$clog2(input_num)-1:0]                            input_sel;
  logic                                                    cts;
  logic [input_num-1:0]                                    request_array [prio_num-1:0];
  logic [$clog2(prio_num)-1:0]                             prio_sel;
  
  logic                                                    signal_for_low_cts;
  logic                                                    cts_from_input_arbiter = 0;
  reg                                                      cts_from_input_arbiter_low_prio_q;
  reg                                                      cts_from_input_arbiter_high_prio_q;
  logic                                                    random_cts_from_input_arbiter;
  logic                                                    cts_from_input_arbiter_low_prio;
  logic                                                    cts_from_input_arbiter_high_prio;
  logic                                                    got_random_num = 0;
   
  reg                                                      last_q = 0;
  reg [input_num-1:0]                                      grant_q = 0;
   
  reg [$clog2(input_num)-1:0]                              selected_input_q_high;
  reg [$clog2(input_num)-1:0]                              selected_input_q_low; 
   
   
  logic [$clog2(input_num)-1:0]                            expected_selected_input;
  logic [$clog2(input_num)-1:0]                            reuse_selected_input;
  reg [$clog2(input_num)-1:0]                              expected_selected_input_q;
  logic                                                    first_high_prio = 1;
  logic                                                    first_low_prio  = 1;
  

 
  
  
  
  exa_crosb_output_arbiter_with_VCs #(
    .input_num(input_num),
    .output_num(output_num),
    .vc_num(vc_num)
  
  )output_arbiter_dut(
    .clk(clk),
    .resetn(resetn),
    .i_request(request),
    .i_output_vc(output_vc),
    .i_last(last),
    .o_request_array(request_array),
    .o_prio_sel(prio_sel),
    
    .o_grant(grant),
    .o_input_sel(input_sel),
    .o_cts(cts),
    .cts_from_input_arbiter(cts_from_input_arbiter)
  );
  
  logic initialize;
  
  requester_for_output_arbiter # (
    .input_num(input_num),
    .prio_num(prio_num),
    .vc_num(vc_num)
  
  )requester(
    .clk(clk),
    .resetn(resetn),
    .last(last),
    .fixed_inputs_enable(0),
    .fixed_inputs(0),
    .initialize(initialize),
    .selected_input(input_sel),
    .cts(cts),
    
    .o_request(request)
    
  
  
  
  );
 
  
  
/*  
  task requester(input initialize);begin
    if(initialize)begin
      for(int i=0;i<input_num;i++)begin
        for(int j=0; j<prio_num*vc_num;j++)begin
          request[i][j] = 0;  
        end
      end
    end
    
    else begin
      for(int i=0;i<input_num;i++)begin
        for(int j=0; j<prio_num*vc_num;j++)begin
          request[i][j] = 1;  
        end
      end
    
      
    end
    
  end
  endtask
  
 */ 
 
      
//save the previous selected_vc
always @(posedge clk) begin
 if(!resetn)begin
   selected_input_q_high <= 0;
   selected_input_q_low  <= 0;
   
 end
 else begin
   if(cts)begin 
     if(prio_sel > 0)
       selected_input_q_high <= input_sel;
     else 
       selected_input_q_low  <= input_sel;
   
   end
  // expected_selected_input_q <= expected_selected_input;
 end

end



/**************************************************** ROUND ROBIN ******************************************************/   

// ******** DESPITE THE FACT THAT CAN PREDICT RIGHT, IF INPUT_SEL TURNS TO 3, THE BLOCK IS NOT TRIGGERED AND TRUE_SELECTED_INPUT DOES NOT TURN HIGH********


assign reuse_selected_input             = (prio_sel) ? request_array[1][selected_input_q_high] : request_array[0][selected_input_q_low];
assign cts_from_input_arbiter_low_prio  = (!prio_sel & cts_from_input_arbiter)  ? 1 : 0;//indicate the case that  a low prio req was selected, it was also granted. 
assign cts_from_input_arbiter_high_prio = (prio_sel  & cts_from_input_arbiter)  ? 1 : 0;//indicate the case that  a high prio req was selected, and it was also granted.
 
always_comb begin
 //check for high prio reqs
 if(request_array[1] != 0)begin
    
   if(!first_high_prio)begin//for true expected_selected_vc for the first packet of high prio
      for(int i=1;i<input_num + 1;i++)begin
      /*when cts_from_output_arbiter turns low, check if the previous time that a high prio req has been selected, has also been granted too.
        So we can decide which will be the next expected_selected_input.
        waiting cts_from_input_arbiter to be low, we let expected_selected_input take its value before or same time that a new input will be selected*/
       if((request_array[1][(selected_input_q_high + i) % input_num] != 0) & (!cts_from_input_arbiter & cts_from_input_arbiter_high_prio_q))begin // ************ CHANGE 13/04/2022***** it was request_array[1][(selected_input_q_high + i) % input_num] != 0
          expected_selected_input = (selected_input_q_high + i) % input_num ;//**************** CHANGE ***** THERE WAS ERROR***
          break;
       end
       /*if our prevous high prio request was not granted, check if the previous selected input could be used again. If it can't, select a new one */
       else begin
         if((request_array[1][(selected_input_q_high + i) % input_num] != 0) & (!cts_from_input_arbiter & !cts_from_input_arbiter_high_prio_q))begin
           if(reuse_selected_input == 0)begin
             expected_selected_input = (selected_input_q_high + i) % input_num ;//**************** CHANGE ***** THERE WAS ERROR***
             break;
           end
           else 
             expected_selected_input = selected_input_q_high;
         end
       end
     end
    
   end
   else begin
     for(int i=0;i<input_num;i++)begin
       if(request_array[1][i] != 0)begin
         expected_selected_input = i;
         first_high_prio = 0;
         break;
       end
     end
   
   end
   
 end 
 
 //check for low prio reqs while there is no high prio one 
 if(request_array[1] == 0 & request_array[0] != 0)begin
   if(!first_low_prio)begin
     for(int i=1;i<input_num + 1;i++)begin
      /*when cts_from_output_arbiter turns low, check if the previous time that a high prio req has been selected, has also been granted too.
        So we can decide which will be the next expected_selected_input.
        waiting cts_from_input_arbiter to be low, we let expected_selected_input take its value before or same time that a new input will be selected*/
       if((request_array[0][(selected_input_q_low + i) % input_num] != 0) & (!cts_from_input_arbiter & cts_from_input_arbiter_low_prio_q))begin // ************ CHANGE 13/04/2022*****
         expected_selected_input = (selected_input_q_low + i) % input_num;
         break;
       end
        /*if our prevous high prio request was not granted, check if the previous selected input could be used again. If it can't, select a new one */
       else begin
         if((request_array[0][(selected_input_q_low + i) % input_num] != 0) & (!cts_from_input_arbiter & !cts_from_input_arbiter_low_prio_q))begin
           if(reuse_selected_input == 0)begin
             expected_selected_input = (selected_input_q_low + i) % input_num;
             break;
           end
           else
             expected_selected_input = selected_input_q_low; 
         end
       end
     end
   end
   
   else begin
     for(int i=0;i<vc_num;i++)begin
       if(request_array[0][i] != 0 & (prio_sel == 0))begin
         expected_selected_input = i;
         first_low_prio = 0;
         break;
       end
     end
   end
   
 end
 
 if(request_array == 0)begin
   expected_selected_input = input_num - 1;//because when this condtion is true, input sel is 3
 end
end




logic true_selected_input = 0;
always @(input_sel or cts_from_input_arbiter) begin // cts is added because when due to the fact that request == 0, and input_sel = 3, the block is not  triggered
 if(input_sel == expected_selected_input)// *******change********
   true_selected_input = 1;
 else 
   true_selected_input = 0;
end
//****************************************** END OF ROUND ROBIN **************************************************************************/
  always@(posedge clk) begin
   // random_cts_from_input_arbiter <= $urandom() % 2;
    
    /*Store cts_from_input_arbiter_low/high_prio whenever the corresponding prio request is selected.
      These signals help us to remember for any prio, if the selected request , was finally granted or not, 
      so we will know what will be the  true expected_selected_input*/
    if(!prio_sel)
      cts_from_input_arbiter_low_prio_q  <= cts_from_input_arbiter_low_prio;
    if(prio_sel)
      cts_from_input_arbiter_high_prio_q <= cts_from_input_arbiter_high_prio;
      
      
      
    
  end
  
  
  
 /* random_cts should be driven in negedge*/
   always@(negedge clk) begin
     if(grant != 0)
       random_cts_from_input_arbiter <= $urandom() % 2;
       
     
    // got_random_num is used in order to not changing cts_from_input_arbiter all the time that grant is high
     if(grant != 0 & got_random_num == 0 & random_cts_from_input_arbiter !=0)
       got_random_num <= 1;
    // restore got_random_num to 0, so a new random cts_from_input_arbiter will be stored
     if(last_q)
       got_random_num <= 0;
             
       
   
   end
  
  always@(negedge clk)begin
    last_q  <= last;
  //  grant_q <= grant;
  end
  
  
  always_comb begin
     // got_random_num is used in order to not changing cts_from_input_arbiter all the time that grant is high
     if(grant != 0 & got_random_num == 0)begin // WRONG COMMENT -> using grant_q, we make cts_from_input_arbiter high, one cycle after grant has been asserted, just like input arbiter does.
         cts_from_input_arbiter = random_cts_from_input_arbiter;
        
     end
     if(cts_from_input_arbiter)begin
       if(last_q)begin// it is used for dropping cts_from_input_arbiter when last signal is low(last_q is high)
         cts_from_input_arbiter = 0;
         
       end
     end    
  end
  
 
 
  
  initial begin
    //requester(1);
    last = 0;
    initialize = 1;
    #100
    resetn = 1;
   // #15
    initialize = 0;
    //requester(0);
    /*
    #5
    request[0][0] = 1;  
    request[1][4] = 1;
    request[3][1] = 1;
     # 10 request[1][4] = 0;
     */
    forever begin
      while(!(cts_from_input_arbiter))@(posedge clk);//  CTS FROM INPUT ARBITER is the signal that indicates the packet's sending, not cts from output arbiter!
      repeat(17)@(posedge clk);
      @(negedge clk);
      last = 1;
      @(negedge clk);
      last = 0;
      @(posedge clk);//this delay is necessary used because without it last starts over even if cts_from_output_arbiter has just turned low..
    end
  end
  
endmodule
  