`timescale 1ns / 1ps
import exanet_crosb_pkg::*;
import exanet_pkg::*;
`include "ceiling_up_log2.vh"


module exa_crosb_crosb_with_VCs_tb();

  
  localparam prio_num     = 2;
  localparam vc_num       = 3;
  localparam output_num   = 2;
  localparam input_num    = 2;
  localparam datawidth    = 128;
  localparam logVcPrio    = `log2(prio_num*vc_num);
  localparam logOutput    = `log2(output_num);
  localparam logPrio      = `log2(prio_num);
  localparam logVc        = `log2(vc_num);
  localparam logInput     = `log2(input_num);
  
  reg                                       clk;
  reg                                       resetn;
  reg                                       rand_1 = 0;
  reg [5:0]                                 rand_6 = 0;
  reg [$clog2(vc_num*prio_num)-1 :0]        rand_vc_output   = 0;
  reg [$clog2(output_num)-1 :0]             rand_dest = 0;
  /*axi generator signals*/
  logic                                     enable_w [input_num-1:0];
  logic [datawidth-1:0]                     num_of_words_w;
  logic                                     initialize;
  
  
  AXIS   S_AXIS[input_num-1  : 0]();   //from exa2axi
  AXIS   M_AXIS[output_num-1 : 0]();  //from crossbar to axi2exa
  
  logic [vc_num*prio_num-1:0]               output_fifo_credits [output_num-1:0];
  wire [$clog2(vc_num*prio_num)-1:0]        output_vc[input_num-1:0][vc_num*prio_num-1:0];
  wire [$clog2(vc_num*prio_num)-1:0]        input_vc [input_num-1:0];
  wire [prio_num*vc_num-1:0]                has_packet[input_num-1:0];
  wire [(logOutput)-1 :0]                   dests[input_num-1:0][prio_num*vc_num-1 :0];
  
  wire [$clog2(vc_num*prio_num)-1:0]        selected_vc_from_input_arbiter[input_num-1:0];
  wire                                      cts_from_input_arbiter[input_num-1:0];
  wire [$clog2(output_num)-1 :0]            dest_output_of_each_input[input_num-1:0];
  wire [$clog2(vc_num*prio_num)-1:0]        dest_output_vc_of_each_input[input_num-1:0];
  
  //assign output_vc = input_vc;/**simulating that input_vc and output_vc are the same*/ 
  
  exa_crosb_crosb_with_VCs#(
    .data_width(datawidth),
    .prio_num(prio_num),
    .input_num(input_num),
    .vc_num(vc_num),
    .output_num(output_num)
  )exa_crosb_crosb_with_VCs( 
    
    .clk(clk),
    .resetn(resetn), 
    .S_AXIS(S_AXIS),
    .M_AXIS(M_AXIS),
    .i_output_fifo_credits(output_fifo_credits),
    .i_output_vc(output_vc),/**simulating that input_vc and output_vc are the same*/ 
    .i_has_packet(has_packet),
    .i_dests(dests),
    .o_selected_vc_from_input_arbiter(selected_vc_from_input_arbiter),
    .o_cts_from_input_arbiter(cts_from_input_arbiter),
    .o_dest_output_of_each_input(dest_output_of_each_input),
    .o_dest_output_vc_of_each_input(dest_output_vc_of_each_input)
    
  );
  
  genvar i,j;
  generate
  for(i=0;i<input_num;i++)begin
  
   /*simulates has_packet signal for every VC for every output*/  
    haser_for_input_arbiter #(
   
      .prio_num(prio_num),
      .vc_num(vc_num),
      .output_num(output_num)
   
    ) haser(
       .clk(clk),
       .resetn(resetn),
       .fixed_vcs_enable(0),
       .fixed_vcs(0),
       .cts(cts_from_input_arbiter[i]),
       .last(S_AXIS[i].TLAST),
       .selected_vc(selected_vc_from_input_arbiter[i]),
       .initialize(initialize),
      
       .o_has_packet(has_packet[i]),
       .dest_i(dests[i]),
       .output_vc_i(output_vc[i])
   
    );

  
   
  // When cts_from_input_arbiter is high, axi stream is generated for the corresponding input
    axi_stream_traffic_generator_v1_0_M00_AXIS # (
        .NUM_OF_WORDS_WIDTH(datawidth),
        .C_M_AXIS_TDATA_WIDTH(datawidth),
        .prio_num(prio_num),
        .vc_num(vc_num),
        .output_num(output_num)
    ) axi_stream_traffic_generator (
        .enable(cts_from_input_arbiter[i]),
        .num_of_words(num_of_words_w), 
        .M_AXIS_ACLK(clk),
        .M_AXIS_ARESETN(resetn),
       // .o_output_vc(input_vc[i]),
        .i_fifo_full(6'b000000),// we don't care about fifo_full.there aren't fifos
        .M_AXIS(S_AXIS[i])
    );
        
  end
  endgenerate






  
    //************************* output_fifo_credits_controller ********************
  
  task output_fifo_credits_controller(input initialize,input full, input fixed_vc_enable, input [prio_num*vc_num-1:0] output_vc, input [output_num-1:0]dest_output);begin
    if(initialize & !full)begin
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
    if(!full & fixed_vc_enable & !initialize)  
      output_fifo_credits [dest_output][output_vc] = 1;      
    if(full & fixed_vc_enable & !initialize)
      output_fifo_credits [dest_output][output_vc] = 0;       
    if(!fixed_vc_enable & !full & !initialize)begin
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
   
   
     
   
   //************************* forever block calling output_fifo_credits_controller ********************
    
   always @(posedge clk) begin
     rand_1    <= $urandom() % 2;
   end
   
  logic flag_2 = 0;
  initial begin
    #110 
    forever begin 
      if(rand_1)begin
        /*@(posedge clk);*/  @(negedge clk);
         output_fifo_credits_controller(.initialize(0), .full(0), .fixed_vc_enable(0), . output_vc(0), .dest_output(0)); 
         rand_6 = ($urandom() % 3) + 1 ;
         repeat(rand_6)@(posedge clk);
       end
       else begin
        /* @(posedge clk);*/@(negedge clk);
         output_fifo_credits_controller(.initialize(0), .full(1), .fixed_vc_enable(0), .output_vc(0), .dest_output(0));
         rand_6 = ($urandom() % 3) + 1 ;
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


  
   
      
  
  initial begin
    clk = 0;
    forever begin
      #5 clk = ~clk;
    end
  end
  
  initial begin
    output_fifo_credits_controller(.initialize(1), .full(0),.fixed_vc_enable(0), . output_vc(0), .dest_output(0));
    resetn = 0;
    initialize = 1;
    num_of_words_w = 18;
    #30
    resetn = 1;
    initialize = 0;
  end
  
  
  /*The below code was used for initializing enable signal for axi stream generators and enabling them at different time*/
  /*
  int count = 0;
  int initialise_count = 0;
  initial begin
    forever begin
      @(negedge clk);
      if(!resetn)begin
        //@(negedge clk);
       // enable_w[0] = 0;
        for(initialise_count = 0; initialise_count < input_num; initialise_count++)begin
          enable_w[initialise_count] = 0;
        end
      end
      else begin
        repeat(5)
          @(negedge clk);
        enable_w[count] = 1;
        if(count < input_num)
          count = count + 1;
        else
          break;
      end
    end
  end
  */  
    
endmodule
