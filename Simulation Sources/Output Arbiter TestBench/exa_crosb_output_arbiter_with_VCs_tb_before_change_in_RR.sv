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
    
    .o_grant(grant),
    .o_input_sel(input_sel),
    .o_cts(cts)
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
      while(!cts)@(posedge clk);
      repeat(17)@(posedge clk);
      last = 1;
      @(posedge clk);
      last = 0;
    end
  end
  
endmodule
