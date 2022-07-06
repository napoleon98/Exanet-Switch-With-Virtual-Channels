`timescale 1ns / 1ps
import exanet_crosb_pkg::*;
import exanet_pkg::*;



module exa_crosb_input_arbiter_with_VCs_tb(

);


  localparam prio_num   = 2;
  localparam vc_num     = 3;
  localparam output_num = 8;
  
  localparam num_of_has = 2;
  
  reg    clk		    = 0;
  always #5 clk = ~clk;
  reg    resetn         = 0;
 //inputs
  logic [vc_num*prio_num-1 : 0]           has_packet;
  //logic [$clog2(output_num)-1 :0]         dest_i [prio_num*vc_num-1 :0];
  logic [(output_num)-1 :0]               dest_i [prio_num*vc_num-1 :0];
  logic [vc_num*prio_num-1:0]             grant_from_output_arbiter[output_num-1:0];
  logic                                   last;
  logic [vc_num*prio_num-1:0]             output_fifo_credits [output_num-1:0];
  logic [$clog2(vc_num*prio_num)-1:0]     output_vc_i [vc_num*prio_num-1:0];
  //outputs
  logic [$clog2(vc_num*prio_num)-1:0]     output_vc_o [vc_num*prio_num-1:0];
  logic [prio_num*vc_num-1:0]             selected_request [output_num-1:0];
 // logic [$clog2(output_num)-1 :0]         dest_o [prio_num*vc_num-1 :0];
  logic [(output_num)-1 :0]               dest_o [prio_num*vc_num-1 :0];
  logic                                   cts;
  logic [$clog2(vc_num*prio_num)-1:0]     selected_vc;
  
  
  logic [$clog2(vc_num*prio_num)-1:0]    input_vc;
  logic [$clog2(vc_num*prio_num)-1:0]    output_vc;
  logic [$clog2(output_num)-1 :0]        dest_output;
  logic                                  flag =0;
  logic [vc_num-1:0]                     request_array [prio_num-1:0];
  logic [vc_num-1:0]                     request_array_1 [prio_num-1:0];
  logic [$clog2(output_num)-1 :0]         output_dest_grant_controller;
  logic [$clog2(vc_num*prio_num)-1:0]    output_vc_dest_grant_controller;
  logic                                  stop = 0;
  
  reg [5:0]                          rand_6    = 0;
  reg [$clog2(output_num)-1 :0]      rand_dest = 0;
  reg [$clog2(vc_num*prio_num)-1 :0] rand_vc_has   = 0;
  reg [$clog2(vc_num*prio_num)-1 :0] rand_vc_output   = 0;
  reg [$clog2(vc_num*prio_num)-1 :0] rand_vc_dest   = 0;
  reg [$clog2(vc_num*prio_num)-1 :0] rand_vc   = 0;
  reg                                rand_1    =0;
  reg [$clog2(vc_num*prio_num)-1:0]  selected_vc_q_high;
  reg [$clog2(vc_num*prio_num)-1:0]  selected_vc_q_low;
  
  exa_crosb_input_arbiter_with_VCs # (
       .prio_num(prio_num),
       .vc_num(vc_num),
       .output_num(output_num)
    ) input_arbiter_dut (
       .clk(clk),
       .resetn(resetn),
       .i_has_packet(has_packet),
       .i_dest(dest_i),
       .i_grant_from_output_arbiter(grant_from_output_arbiter),
       .i_last(last),
       .output_fifo_credits(output_fifo_credits),
       .i_output_vc(output_vc_i),
       .o_output_vc(output_vc_o),
       .o_selected_request(selected_request),
       .o_dest(dest_o),
       .o_cts(cts),
       .o_selected_vc(selected_vc),
       .o_request_array(request_array),
       .o_dest_output(output_dest_grant_controller),
       .o_dest_vc(output_vc_dest_grant_controller)
    
    );
    
    
  logic fixed_vcs_enable;
  logic [(vc_num*prio_num)-1:0] fixed_vcs;
  logic initialize;
  
  haser_for_input_arbiter #(
  
     .prio_num(prio_num),
     .vc_num(vc_num),
     .output_num(output_num)
  
  ) haser(
     .clk(clk),
     .resetn(resetn),
     .fixed_vcs_enable(fixed_vcs_enable),
     .fixed_vcs(fixed_vcs),
     .cts(cts),
     .last(last),
     .selected_vc(selected_vc),
     .initialize(initialize),
     
     .o_has_packet(has_packet),
     .dest_i(dest_i),
     .output_vc_i(output_vc_i)
  
  );
  
  /*
  task haser(input fixed_vc_enable, input [$clog2(vc_num*prio_num)-1:0] fixed_vc, input [vc_num*prio_num-1:0] num_of_has, input initialize, input has); begin
    if(initialize) begin
      for(int i=0; i<prio_num*vc_num; i++) begin
        has_packet[i]              = 0;
      end  
    end
    else begin
      if(has) begin
        if(fixed_vc_enable)
          has_packet[fixed_vc]           = 1;
        else begin
          rand_vc_has = $urandom() % (prio_num*vc_num); 
          has_packet[rand_vc_has]            = 1;
        end
        if (num_of_has != 0) begin
          for(int i=0; i<num_of_has; i++) begin
            has_packet[i]              = 1;
          end  
        end
      end
      else begin
        if(fixed_vc_enable)
          has_packet[fixed_vc]           = 0;
        else begin
          rand_vc_has = $urandom() % (prio_num*vc_num);
          has_packet[rand_vc_has]            = 0;
        end
        if (num_of_has != 0) begin
          for(int i=0; i<num_of_has; i++) begin
            has_packet[i]              = 0;
          end  
        end
      end
          
    end
  
  end
  endtask
  */
  
  task output_fifo_credits_controller(input initialize,input full, input not_full,input fixed_vc_enable, input [prio_num*vc_num-1:0] output_vc, input [output_num-1:0]dest_output);begin
    if(initialize & not_full)begin
      for(int i=0;i<output_num; i++)begin 
        for(int j=0;j<prio_num*vc_num;j++)begin
          output_fifo_credits[i][j] = 1;
        end
      end
    end 
    else if(initialize & full) begin
      for(int i=0;i<output_num; i++)begin 
        for(int j=0;j<prio_num*vc_num;j++)begin
          output_fifo_credits[i][j] = 0;
        end
      end  
    end 
    if(not_full & fixed_vc_enable & !initialize)  
      output_fifo_credits [dest_output][output_vc] = 1;      
    if(full & fixed_vc_enable & !initialize)
      output_fifo_credits [dest_output][output_vc] = 0;       
    if(!fixed_vc_enable & not_full & !initialize)begin
      rand_vc_output = $urandom() % (prio_num*vc_num);
      rand_dest = $urandom() % output_num;
      output_fifo_credits[rand_dest][rand_vc_output]      = 1;
    end
    if(!fixed_vc_enable & full & !initialize)begin
      rand_vc_output = $urandom() % (prio_num*vc_num);
      rand_dest = $urandom() % output_num;
      output_fifo_credits[rand_dest][rand_vc_output]      = 0;
    end
  end 
  endtask
  
  
  task dester(input fixed_dest_enable, input [$clog2(output_num)-1 :0] fixed_dest, input fixed_vc_enable, input[$clog2(prio_num*vc_num)-1 :0] fixed_vc,input initialize);begin
    if(initialize) begin
      for(int i=0;i<prio_num*vc_num;i++)begin
        dest_i[i]        = 0;
      end
    end
    else begin
      if(fixed_dest_enable & !fixed_vc_enable ) begin
        rand_vc_dest = $urandom() % (prio_num*vc_num);
        dest_i[rand_vc_dest]    = fixed_dest;
       
        
      end
      if(fixed_vc_enable & !fixed_dest_enable ) begin
        rand_dest = $urandom() % (output_num - 1) + 1;// dest between 1 - output_num
        dest_i[fixed_vc]   = rand_dest;
        
      end
      if(fixed_dest_enable & fixed_vc_enable )begin
        dest_i[fixed_vc]   = fixed_dest;
        
      end  
      if(!fixed_dest_enable & !fixed_vc_enable )begin
        rand_dest = $urandom() % (output_num - 1) + 1;// dest between 1 - output_num
        rand_vc_dest = $urandom() % (prio_num*vc_num);
        dest_i[rand_vc_dest]    = rand_dest;
        
      end 
    end  
  end
  endtask
  
  task output_vcer(input fixed_vc_enable, input[$clog2(prio_num*vc_num)-1 :0] fixed_vc, input initialize);begin
    if(initialize) begin
      for(int i=0;i<prio_num*vc_num;i++)begin
        output_vc_i[i]     = 0;
      end
   end
   else begin
     if(fixed_vc_enable)begin
       output_vc_i[fixed_vc] = fixed_vc; //same input and output vc
       
     end
     else begin
       rand_vc = $urandom() % (prio_num*vc_num);
       output_vc_i[rand_vc]  = rand_vc;
       
     end  
   end    
  end 
  endtask
  
  
  
  logic cond =0;
  assign request_array_1 = exa_crosb_input_arbiter_with_VCs.request_array;
  task grant_from_output_arbiter_controller(input initialize); begin
    
    for(int i=0;i<output_num;i++)begin
      for(int j=0;j<prio_num*vc_num;j++)begin
        if(initialize)
          grant_from_output_arbiter[i][j] = 0;
       /* else begin
          if(selected_request[i][j] != 0 &(i != 0 | j != 0)) begin
            output_dest_grant_controller = i;
            output_vc_dest_grant_controller = j;
          end
        end*/
      end
    end
    
    if(!initialize) begin
      rand_6       = ($urandom() % 5 + 1);
      /*repeat(1)@(negedge clk);*/repeat(rand_6) @(posedge clk);//waiting for the grant from output arbiter
      #1
      if(selected_request[output_dest_grant_controller][output_vc_dest_grant_controller] != 0)begin//check if selected_request is high when output arbiter is ready to grant it.
        cond = 0;
        if((request_array[0]!=0 & request_array[1]==0) | (request_array[1]!=0 & exa_crosb_input_arbiter_with_VCs.prio_sel_q == 1))begin
        
          if((request_array[0]!=0 & request_array[1]==0))begin
            $display("request_array[1] is, %b and time is %t" , request_array_1[1],$time);
            $display("request_array[0] is, %b and time is %t" , request_array_1[0],$time);
          end
          @(negedge clk);
          grant_from_output_arbiter[output_dest_grant_controller][output_vc_dest_grant_controller] = 1;
          repeat(17) 
            @(posedge clk);//waiting for the "tlast" signal  
            @(negedge clk);     
            last                                                   = 1;
            @(negedge clk);
            last                                                   = 0;
          
        //grant_from_output_arbiter[output_dest_grant_controller][output_vc_dest_grant_controller] = 0;
          for(int i=0;i<output_num;i++)begin
            for(int j=0;j<prio_num*vc_num;j++)begin   
              grant_from_output_arbiter[i][j] = 0;
            end
          end
          
         @(posedge clk);//@(negedge clk); // **** USING @(negedge clk) simulating grant in same cycle, @(posedge clk)  simulating in next cycle
        end
        else
          @(posedge clk);
      end
      else begin
        grant_from_output_arbiter[output_dest_grant_controller][output_vc_dest_grant_controller] = 0;
        @(posedge clk);// @(negedge clk);// **** USING @(negedge clk) simulating grant in same cycle, @(posedge clk)  simulating in next cycle
        cond = 1;
      end
    end
    
    
  end
  endtask
  
  //*********************** grant_from_output_arbiter ***************************
  initial begin
    #115//#180
    forever begin
      if(selected_request != 0)
        grant_from_output_arbiter_controller(.initialize(0));
      else begin
        @(negedge clk);
      end
    end
  end
  /*
  always @(posedge clk) begin 
  
    for(int i=0;i<output_num;i++)begin
      for(int j=0;j<prio_num*vc_num;j++)begin
        if(initialize)
          grant_from_output_arbiter[i][j] = 0;
        else begin
          if(selected_request[i][j] != 0 &(i != 0 | j != 0)) begin
            output_dest_grant_controller    = i;
            output_vc_dest_grant_controller = j;
          end
        end
      end
    end  
    
  end
  */
  always @(posedge clk) begin
    rand_6    <= ($urandom() % 6) + 5 ;
    rand_1    <= $urandom() % 2;
  end
    
    


//*********************************************** ROUND ROBIN SIMULATOR FOR TESTING IF INPUT ARBITER'S OUTPUT IS THE EXPECTED ************************************
    
    
  //save the previous selected_vc
  always @(posedge clk) begin
    if(!resetn)begin
      selected_vc_q_high <= 0;
      selected_vc_q_low  <= 0;
      
    end
    else begin 
      if(selected_vc > vc_num-1)
        selected_vc_q_high <= selected_vc;
      if(selected_vc < vc_num)
        selected_vc_q_low  <= selected_vc;
        
      expected_selected_vc_q <= expected_selected_vc;
    end
  
  end
 
 
 logic [$clog2(vc_num*prio_num)-1:0] expected_selected_vc;
 reg [$clog2(vc_num*prio_num)-1:0] expected_selected_vc_q;
 logic first_high_prio = 1;
 logic first_low_prio  = 1;
 
  
 /**************************************************** ROUND ROBIN ******************************************************/   
  always_comb begin
    //check for high prio reqs
    if(request_array[1] != 0)begin
       
      if(!first_high_prio)begin//for true expected_selected_vc for the first packet of high prio
         for(int i=1;i<vc_num + 1;i++)begin
          if(request_array[1][(selected_vc_q_high + i) % vc_num] != 0)begin
            expected_selected_vc = (selected_vc_q_high + i) % vc_num + vc_num;//**************** CHANGE ***** THERE WAS ERROR***
            break;
          end
        end
       
      end
      else begin
        for(int i=0;i<vc_num;i++)begin
          if(request_array[1][i] != 0)begin
            expected_selected_vc = vc_num + i;
            first_high_prio = 0;
            break;
          end
        end
      
      end
      
    end 
    
    //check for low prio reqs while there is no high prio one 
    if(request_array[1] == 0 & request_array[0] != 0)begin
      if(!first_low_prio)begin
        for(int i=1;i<vc_num + 1;i++)begin
          if(request_array[0][(selected_vc_q_low + i) % vc_num] != 0)begin
            expected_selected_vc = (selected_vc_q_low + i) % vc_num;
            break;
          end
        end
      end
      
      else begin
        for(int i=0;i<vc_num;i++)begin
          $display("i is  %d",i);
          $display("request  %d",request_array[0][i]);
          if(request_array[0][i] != 0)begin
            expected_selected_vc = i;
            $display("expected vc %d",i);
            first_low_prio = 0;
            break;
          end
        end
      end
      
    end
  end
  
  
  
  
  logic true_selected_vc = 0;
  always @(selected_vc) begin
    if(selected_vc == expected_selected_vc)// *******change********
      true_selected_vc = 1;
    else 
      true_selected_vc = 0;
  end
  
  genvar i;
  
  
  
  //************************* output_fifo_credits_controller ********************
  
  logic flag_2 = 0;
  initial begin
    #110 
    forever begin 
       if(rand_1)begin
         output_fifo_credits_controller(.initialize(0), .full(0),  .not_full(1),.fixed_vc_enable(0), . output_vc(0), .dest_output(0)); 
         rand_6 = ($urandom() % 6) + 5 ;
         repeat(rand_6)@(posedge clk);
       end
       else begin
         output_fifo_credits_controller(.initialize(0), .full(1),  .not_full(0),.fixed_vc_enable(0), . output_vc(0), .dest_output(0));
         rand_6 = ($urandom() % 6) + 5 ;
         repeat(rand_6)@(posedge clk);
       end 
       
       
       
       /*Just for testing the case that fifo gets full before a grant comes*/
       
       /*
       for(int i=0; i<prio_num*vc_num; i++)begin
         if((has_packet[i] != 0) & !flag_2)begin
           rand_6 = ($urandom() % 6) + 5 ;
           flag_2 = 1;
           repeat(rand_6)@(posedge clk);
           output_fifo_credits_controller(.initialize(0), .full(1),  .not_full(0),.fixed_vc_enable(1), . output_vc(i), .dest_output(dest_i[i]));
         end
         else begin
           @(negedge clk);
         end   
       end  
       */
       
        
    end
  end
  
  
  
  //********************* Intitializations *************************************
  initial begin 
    //haser(.fixed_vc_enable(0),.fixed_vc(0),.num_of_has(0),.initialize(1),.has(0)); 
    output_fifo_credits_controller(.initialize(1), .full(0),  .not_full(1),.fixed_vc_enable(0), . output_vc(0), .dest_output(0));
    dester( .fixed_dest_enable(0), . fixed_dest(0), .fixed_vc_enable(0), .fixed_vc(0), .initialize(1));
    output_vcer(.fixed_vc_enable(0), .fixed_vc(0), .initialize(1));
    grant_from_output_arbiter_controller(.initialize(1));
    last = 0;
    initialize = 1;
    fixed_vcs = 0;
    fixed_vcs_enable = 0;
    #100
    resetn      = 1;
    input_vc    = 2;
    output_vc   = 2;
    dest_output = 1;
    
    //haser_for_input_arbiter------- input signals
    initialize  = 0;
    fixed_vcs    = 0;;
    fixed_vcs_enable = 0;
    
  end
  



endmodule