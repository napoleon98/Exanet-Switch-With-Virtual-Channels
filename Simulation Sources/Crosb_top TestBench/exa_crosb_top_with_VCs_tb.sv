
`timescale 1ns/1ns
import exanet_crosb_pkg::*;
import exanet_pkg::*;



module exa_crosb_top_with_VCs_tb();
  

  localparam testlength = 1000;
  localparam input_num  = 4;
  localparam output_num = 4;
  localparam prio_num   = 2;
  localparam vc_num     = 3;
  localparam data_width = 128;


  reg                       clk		      = 0;
  always #5 clk = ~clk;
  reg                       resetn	      = 0;
  reg [input_num - 1 : 0]   traffic_work  = 0;
  reg [input_num - 1 : 0]   dif_size_en   = 0;
  reg [input_num - 1 : 0]   fixed_dest_en = 0;
  reg [input_num - 1 : 0]   delay_en      = 0;
  reg [9 : 0]               fixed_dest    = 0; 
  reg [4 : 0]               valid_drop_rate[input_num -1 :0];
  reg [31:0]                phase = 0; 
  reg [4 : 0]               backpressure[output_num - 1 :0];
  
   
  exanet s_exanet_rx[input_num - 1 :0]();     
  exanet m_exanet_tx[output_num -1 :0]();   
  
  
  
  reg [31:0] headers_generated[input_num-1:0] = {default:0};//{0,0,0,0} ;
  reg [31:0] headers_consumed[output_num-1:0] ={0,0,0,0} ;
  logic [31:0] total_headers_generated;
  logic [31:0] total_headers_consumed ;
  reg [31:0] payload_generated[input_num-1:0] ={0,0,0,0} ;
  reg [31:0] payload_consumed[output_num-1:0] ={0,0,0,0} ;
  logic [31:0] total_payload_generated;
  logic [31:0] total_payload_consumed ;
  reg [31:0] footer_generated[input_num-1:0] ={0,0,0,0} ;
  reg [31:0] footer_consumed[output_num-1:0] ={0,0,0,0} ;
  logic [31:0] total_footer_generated;
  logic [31:0] total_footer_consumed ; 
  


  genvar k;
  generate
    for (k=0 ; k < input_num ; k ++ ) begin
      always @(posedge clk) begin
        if (s_exanet_rx[k].header_valid & s_exanet_rx[k].header_ready)
          headers_generated[k] <= headers_generated[k] + 1;
         if (s_exanet_rx[k].payload_valid & s_exanet_rx[k].payload_ready)
            payload_generated[k] <= payload_generated[k] + 1;         
         if (s_exanet_rx[k].footer_valid & s_exanet_rx[k].footer_ready)
              footer_generated[k] <= footer_generated[k] + 1;         
      end  
    end
  
    for (k=0 ; k < output_num ; k ++ ) begin
      always @(posedge clk) begin
        if (m_exanet_tx[k].header_valid & m_exanet_tx[k].header_ready)
          headers_consumed[k] <= headers_consumed[k] + 1;
         if (m_exanet_tx[k].payload_valid & m_exanet_tx[k].payload_ready)
            payload_consumed[k] <= payload_consumed[k] + 1;         
        if (m_exanet_tx[k].footer_valid & m_exanet_tx[k].footer_ready)
              footer_consumed[k] <= footer_consumed[k] + 1;                  
      end  
    end
  
  endgenerate
 
  always_comb begin
    logic [31:0] sum1,sum2,sum3,sum4,sum5,sum6;
    sum1 = 0; sum2 = 0 ; sum3 = 0 ; sum4 =  0 ; sum5 = 0 ; sum6 = 0;
    for (int k = 0 ; k<input_num ; k++ ) begin
      sum1 = sum1 + headers_generated[k];
      sum2 = sum2 + payload_generated[k];
      sum3 = sum3 + footer_generated[k] ;
    end
    for (int k = 0 ; k<output_num ; k++ ) begin
      sum4 = sum4 + headers_consumed[k];
      sum5 = sum5 + payload_consumed[k];
      sum6 = sum6 + footer_consumed[k] ;
    end  
    total_headers_generated = sum1; 
    total_headers_consumed  = sum4;
    total_payload_generated = sum2;
    total_payload_consumed  = sum5;
    total_footer_generated  = sum3;
    total_footer_consumed   = sum6;
  end

  
  

  genvar i ;
  generate
    for (i = 0 ; i < input_num ; i = i +1 ) begin :traffic_gen   
      exa_crosb_traffic_gen #(
        .prio_val(0),
        .tag(i),
        .vc_num(vc_num),
        .prio_num(prio_num)
      )traffic_gen_0 (
        .clk(clk),
        .resetn(resetn),
        .i_src_coord(i),
        .dif_size_enable(dif_size_en[i]),
        .fixed_dest_enable(fixed_dest_en[i]),
        .fixed_dest(fixed_dest),
        .delay_enable(delay_en),
        .i_work(traffic_work[i]),
        .exa(s_exanet_rx[i]),
        .valid_drop_rate(valid_drop_rate[i])
      );
    end 
  endgenerate
  
  
  generate
    for (i = 0 ; i < output_num ; i = i +1 ) begin
      exa_crosb_traffic_consumer_with_VCs #(
        .vc_num(vc_num),
        .prio_num(prio_num),
        .input_num(input_num),
        .output_num(output_num)
      )traffic_consumer (
        .clk(clk),
        .resetn(resetn),
        .i_src_coord('h10*(i + 3)),// it was 'h10*(i/2)
        .exa(m_exanet_tx[i]),
        .i_backpressure(backpressure[i])
      );     

    end 
  endgenerate
  
  
  
  

  
  exa_crosb_top_with_VCs #(
      .input_num(input_num),
      .output_num(output_num),
      .prio_num(prio_num),
      .vc_num(vc_num),
      .max_ports(4),
      .S_AXI_ID_WIDTH   (3),
      .S_AXI_DATA_WIDTH (128),
      /*num of addresses below should be the same as max_ports = output_num*/
      
      .PORTx_LOW_ADDR   ({/*42'h38000000000,42'h38000000010,42'h38000000020,*/42'h38000000030,42'h38000000040,42'h38000000050,42'h38000000060/*,42'h38000000070*/} ),
      .PORTx_HIGH_ADDR  ({/*42'h3800000000f,42'h3800000001f,42'h3800000002f,*/42'h3800000003f,42'h3800000004f,42'h3800000005f,42'h3800000006f/*,42'h3800000007f*/} ),
      .in_fifo_depth          ( 40 ),
      .out_fifo_depth         ( 40 ),
      //.net_route_reg_enable  ( 8'b11111111),
      .net_route_reg_enable  ( 4'b0000)
     
     )exanet_crosb_top_with_VCs_dut (
       
       .ACLK(clk),
       .ARESETN(resetn),
       .i_src_coord(0),
       .exanet_rx(s_exanet_rx),
       .exanet_tx(m_exanet_tx)
     );




   
   logic is_inactive;
   logic [31:0] inactive_counter;
   logic [input_num-1:0]active_flag_0;
   logic [output_num-1:0]active_flag_1;

   generate
       for (k = 0 ; k <input_num ; k++) begin
         always_comb begin
           active_flag_0[k] = 0;
           if (s_exanet_rx[k].header_valid | s_exanet_rx[k].payload_valid | s_exanet_rx[k].footer_valid ) active_flag_0[k] = 1;
         end
       end
       
       for (k = 0 ; k <output_num ; k++) begin
         always_comb begin
           active_flag_1[k] = 0;
           if (m_exanet_tx[k].header_valid | m_exanet_tx[k].payload_valid | m_exanet_tx[k].footer_valid ) active_flag_1[k] = 1;
         end
       end     
   endgenerate
   
   always @(posedge clk) begin
     if ((active_flag_0==0) & (active_flag_1==0))
       inactive_counter <= inactive_counter + 1;  
     else
       inactive_counter <= 0;
                  
     if (inactive_counter == 500)//IT WAS 1000
       is_inactive = 1;
     else
       is_inactive = 0;
   end  


 
  task run_test;
    input [input_num - 1 : 0] t_traffic_work               ;
    input [input_num - 1 : 0] t_dif_size_en                ;
    input [input_num - 1 : 0] t_delay_en                   ;
    input [input_num - 1 : 0] t_fixed_dest_en              ;
    input [9 : 0]             t_fixed_dest                 ;
    input [4 : 0]             t_backpressure   [output_num-1:0];
    input [4 : 0]             t_valid_drop_rate[input_num-1 :0];
    input [31:0]              t_test_length                ;

    begin
      $display("begin new round of tests");
      $display("Inputs that work            : %0b",t_traffic_work);     
      $display("dif size enable             : %0b",t_dif_size_en);      
      $display("fixed destination enable    : %0b",t_fixed_dest_en); 
      $display("fixed destination           : %0d",t_fixed_dest);
      $display("delay destination           : %0b",t_delay_en); 
      $display("backpressure value          : %0p",t_backpressure); 
      $display("valid_drop value            : %0p",t_valid_drop_rate);       
      $display("---------------------------------------------------");     
            
      fixed_dest         = t_fixed_dest        ;
      for (int i = 0 ; i < input_num ; i++) begin
       // traffic_work[i]    = t_traffic_work[i]   ;       
        fixed_dest_en[i]   = t_fixed_dest_en[i]  ;
        delay_en[i]        = t_delay_en[i]       ;
        valid_drop_rate[i] = t_valid_drop_rate[i];
        dif_size_en[i]     = t_dif_size_en[i];
      end

      for (int i = 0 ; i < output_num ; i++) begin
        backpressure[i] = t_backpressure[i];
      end     
      
      
      for (int i = 0 ; i < input_num ; i++) begin
        traffic_work[i]    = t_traffic_work[i]   ; 
        @(posedge clk);
        
      end
      
      
      
    
      repeat(t_test_length) @(posedge clk);
      for (int i = 0 ; i < input_num ; i++) begin
        traffic_work = 0;
      end      
         
      wait(is_inactive)   @(posedge clk);

      if ((total_headers_generated != total_headers_consumed)  & (total_payload_generated != total_payload_consumed) & (total_footer_generated != total_footer_consumed)) begin
        $display( " there was a problem with h/p/f");
        $display("headers gen / cons : %d  | %d " , total_headers_generated , total_headers_consumed);
        $display("payload gen / cons : %d  | %d " , total_payload_generated , total_payload_consumed);
        $display("footer gen / cons : %d  | %d " , total_footer_generated , total_footer_consumed);
        $finish();          
      end 
        
       $display("END OF TEST" );
       $display("time is %t",$time); 
      repeat(10)   @(posedge clk); //it was 1000
    
    end  
  endtask
  
  
  
  

    reg [4:0] r5;
    reg [input_num-1:0] r16a;
    reg [input_num-1:0] r16b;
    reg [input_num-1:0] r16c;
    reg [input_num-1:0] r16d;
    //reg [15:0] r16e;
  
   
   
   initial begin
     resetn = 0;
  
     #103
     resetn = 1;
    // #200
     phase ++ ;
     $display("--------------phase 1--------------");      
     //     traffic_work , dif_size_en , delay_enable ,fixed_dest_en,fixed_dest, backpressure,valid_drop_rate,test_length 
     //singe size, single type , single dest , no backpressure , no validdrop
     run_test ( 4'b0001 ,   4'b0000 ,    4'b0000 ,   4'b0001 ,   'h2 ,     '{default:0} ,  '{default:0}  , testlength);  
     //with backpressure  
     run_test ( 4'b0001 ,   4'b0000 ,    4'b0000 ,   4'b0001 ,   'h2 ,     '{8,8,8,8}   ,  '{default:0}  , testlength);  
     //with valid_drop
     run_test ( 4'b0001 ,   4'b0000 ,    4'b0000 ,   4'b0001 ,   'h2 ,     '{default:0} ,  '{8,8,8,8}  ,   testlength);  
     //with backpressure and valid_drop
     run_test ( 4'b0001 ,   4'b0000 ,    4'b0000 ,   4'b0001 ,   'h2 ,     '{8,8,8,8}   ,  '{8,8,8,8}  ,   testlength);  
  
     $display("--------------phase 1 with delay between packets------------");   
    //     traffic_work , dif_size_en , delay_enable ,fixed_dest_en,fixed_dest, backpressure,valid_drop_rate,test_length 
     //singe size, single type , single dest , no backpressure , no validdrop, and delay
     run_test ( 4'b0010 ,   4'b0000 ,    4'b0001 ,   4'b0001 ,   'h1 ,     '{default:0} ,  '{default:0}  , testlength);  
     //with backpressure  
     run_test ( 4'b0010 ,   4'b0000 ,    4'b0001 ,   4'b0001 ,   'h1 ,     '{8,8,8,8}   ,  '{default:0}  , testlength);  
     //with valid_drop
     run_test ( 4'b0010 ,   4'b0000 ,    4'b0001 ,   4'b0001 ,   'h1 ,     '{default:0} ,  '{8,8,8,8}  ,   testlength);  
     //with backpressure and valid_drop
     run_test ( 4'b0010 ,   4'b0000 ,    4'b0001 ,   4'b0001 ,   'h1 ,     '{8,8,8,8}   ,  '{8,8,8,8}  ,   testlength);  
  
     phase ++ ;
     $display("--------------phase 3 with dif_size_en = 1--------------");   
     //         traffic_work              ,dif_size_en         , delay_enable       ,fixed_dest_en,fixed_dest,      backpressure,                            valid_drop_rate,test_length 
     //mutiple size, single type , single dest , no backpressure , no validdrop
     run_test ( 4'b0001 ,   4'b0001 ,    4'b0000 ,   4'b0001 ,   'h1 ,     '{default:0} ,  '{default:0}  , testlength);  
     //with backpressure  
     run_test ( 4'b0001 ,   4'b0001 ,    4'b0000 ,   4'b0001 ,   'h1 ,     '{8,8,8,8}   ,  '{default:0}  , testlength);  
     //with valid_drop
     run_test ( 4'b0001 ,   4'b0001 ,    4'b0000 ,   4'b0001 ,   'h1 ,     '{default:0} ,  '{8,8,8,8}  ,   testlength);  
     //with backpressure and valid_drop
     run_test ( 4'b0001 ,   4'b0001 ,    4'b0000 ,   4'b0001 ,   'h1 ,     '{8,8,8,8}   ,  '{8,8,8,8}  ,   testlength);  
  
     phase ++ ;
     $display("--------------phase 4 with multiple dests--------------");   
     //         traffic_work              ,dif_size_en         , delay_enable       ,fixed_dest_en,fixed_dest,      backpressure,                            valid_drop_rate,test_length 
     //singe size, single type , multi dest , no backpressure , no validdrop
     run_test ( 4'b0001 ,   4'b0000 ,    4'b0000 ,   4'b0000 ,   'h1 ,     '{default:0} ,  '{default:0}  , testlength);  
     //with backpressure  
     run_test ( 4'b0001 ,   4'b0000 ,    4'b0000 ,   4'b0000 ,   'h1 ,     '{8,8,8,8}   ,  '{default:0}  , testlength);  
     //with valid_drop
     run_test ( 4'b0001 ,   4'b0000 ,    4'b0000 ,   4'b0000 ,   'h1 ,     '{default:0} ,  '{8,8,8,8}  ,   testlength);  
     //with backpressure and valid_drop
     run_test ( 4'b0001 ,   4'b0000 ,    4'b0000 ,   4'b0000 ,   'h1 ,     '{8,8,8,8}   ,  '{8,8,8,8}  ,   testlength);  
  
     phase ++ ;
     
     
     $display("--------------phase 5--------------");   
     //         traffic_work              ,dif_size_en         , delay_enable       ,fixed_dest_en,fixed_dest,      backpressure,                            valid_drop_rate,test_length 
     //multiple input singe size, single type , single dest , no backpressure , no validdrop
     run_test ( 4'b1111 ,  4'b0000 ,    4'b0000 ,    4'b1111 ,   'h1 ,     '{default:0} , '{default:0}  , testlength);  
     //with backpressure  
     run_test ( 4'b1111 ,  4'b0000 ,    4'b0000 ,    4'b1111 ,   'h1 ,     '{8,8,8,8}   , '{default:0}  , testlength);  
     //with valid_drop
     run_test ( 4'b1111 ,  4'b0000 ,    4'b0000 ,    4'b1111 ,   'h1 ,     '{default:0} ,  '{8,8,8,8}  ,  testlength);  
     //with backpressure and valid_drop
     run_test ( 4'b1111 , 4'b0000 ,     4'b0000 ,    4'b1111 ,   'h1 ,     '{8,8,8,8}   ,  '{8,8,8,8}  ,   testlength);  
  
     phase ++ ;
     $display("--------------phase 6--------------");   
     //         traffic_work              ,dif_size_en         , delay_enable       ,fixed_dest_en,fixed_dest,      backpressure,                            valid_drop_rate,test_length 
     //multiple input ,  single size, single type , multiple dest , no backpressure , no validdrop
     run_test ( 4'b1111 ,  4'b0000 ,    4'b0000 ,    4'b0000 ,   'h1 ,     '{default:0} , '{default:0}  , testlength);  
     //with backpressure  
     run_test ( 4'b1111 ,  4'b0000 ,    4'b0000 ,    4'b0000 ,   'h1 ,     '{8,8,8,8}   , '{default:0}  , testlength);  
     //with valid_drop
     run_test ( 4'b1111 ,  4'b0000 ,    4'b0000 ,    4'b0000 ,   'h1 ,     '{default:0} ,  '{8,8,8,8}   , testlength);  
     //with backpressure and valid_drop
     run_test ( 4'b1111 ,  4'b0000 ,    4'b0000 ,    4'b0000 ,   'h1 ,     '{8,8,8,8}   ,  '{8,8,8,8}   , testlength);  
  
     phase ++ ;
     $display("--------------phase 7--------------");   
     //         traffic_work              ,dif_size_en         , delay_enable       ,fixed_dest_en,fixed_dest,      backpressure,                            valid_drop_rate,test_length 
     //multiple input ,  multiple size, single type , single dest , no backpressure , no validdrop
     run_test ( 4'b1111 ,  4'b1111 ,    4'b0000 ,    4'b1111 ,   'h1 ,    '{default:0} ,  '{default:0}, testlength);  
     //with backpressure   
     run_test ( 4'b1111 ,  4'b1111 ,    4'b0000 ,    4'b1111 ,   'h1 ,    '{8,8,8,8}   ,  '{default:0}, testlength);  
     //with valid_drop
     run_test ( 4'b1111  , 4'b1111 ,    4'b0000 ,    4'b1111 ,   'h1 ,    '{default:0} ,  '{8,8,8,8}  , testlength);  
     //with backpressure and valid_drop
     run_test ( 4'b1111  , 4'b1111 ,    4'b0000 ,    4'b1111 ,   'h1 ,    '{8,8,8,8}   ,  '{8,8,8,8}  , testlength);  
  
     phase ++ ;
     $display("--------------phase 8--------------");   
     //         traffic_work              ,dif_size_en         , delay_enable       ,fixed_dest_en,fixed_dest,      backpressure,                            valid_drop_rate,test_length 
     //multiple input, multiple size, multiple type , multiple dest , no backpressure , no validdrop
     run_test ( 4'b1111 ,  4'b1111 ,    4'b0000 ,    4'b0000 ,   'h1 ,    '{default:0} ,  '{default:0} , testlength);  
     //with backpressure  
     run_test ( 4'b1111 ,  4'b1111 ,    4'b0000 ,    4'b0000 ,   'h1 ,    '{8,8,8,8}   ,  '{default:0} , testlength);  
     //with valid_drop
     run_test ( 4'b1111  , 4'b1111 ,    4'b0000 ,    4'b0000 ,   'h1 ,    '{default:0} ,  '{8,8,8,8}   , testlength);  
     //with backpressure and valid_drop
     run_test ( 4'b1111  , 4'b1111 ,    4'b0000 ,    4'b0000 ,   'h1 ,    '{8,8,8,8}   ,  '{8,8,8,8}   , testlength);  
  
     $display("--------------phase 8 with delays--------------");   
     //         traffic_work              ,dif_size_en         , delay_enable       ,fixed_dest_en,fixed_dest,      backpressure,                            valid_drop_rate,test_length 
     //multiple input multiple size, multiple type , multiple dest , no backpressure , no validdrop
     run_test ( 4'b1111 ,  4'b1111 ,   4'b1111 ,     4'b0000 ,   'h1 ,    '{default:0} , '{default:0}  , testlength);  
     //with backpressure  
     run_test ( 4'b1111 ,  4'b1111 ,   4'b1111 ,     4'b0000 ,   'h1 ,    '{8,8,8,8}   , '{default:0}  , testlength);  
     //with valid_drop
     run_test ( 4'b1111  , 4'b1111 ,   4'b1111 ,     4'b0000 ,   'h1 ,    '{default:0} ,  '{8,8,8,8}   , testlength);  
     //with backpressure and valid_drop
     run_test ( 4'b1111  , 4'b1111 ,   4'b1111 ,     4'b0000 ,   'h1 ,    '{8,8,8,8}   ,  '{8,8,8,8}   , testlength);  
  
  
     phase ++ ;
     
     $display("--------------final phase--------------");   
     for (int i= 0 ; i < 100 ; i ++ ) begin
      
       r5   = $random();
       r16a = ($urandom() % (input_num-1)) + 1;
       r16b = $random();
       r16c = $random();
       r16d = $random();
       $display("--------------another one bytes the dust %d,%d,%d,%d,%d, --------------",r5,r16a,r16b,r16c,r16d);   
       run_test ( r16a , r16b , r16c , r16d , 'h1 , '{r5,r5,r5,r5} , '{r5,r5,r5,r5} , testlength);
       $display("headers gen / cons : %d  | %d " , total_headers_generated , total_headers_consumed);
       $display("payload gen / cons : %d  | %d " , total_payload_generated , total_payload_consumed);
       $display("footer gen / cons : %d  | %d " , total_footer_generated , total_footer_consumed);
       phase ++ ;
       if ((total_headers_generated != total_headers_consumed)  | (total_payload_generated != total_payload_consumed) | (total_footer_generated != total_footer_consumed) ) begin
         $display("there was a problem with hdr/ftrts!!");
         $finish();
       end      
     end
    
     $display("All tests completed succesfuly ");
      $display("headers gen / cons : %d  | %d " , total_headers_generated , total_headers_consumed);
      $display("payload gen / cons : %d  | %d " , total_payload_generated , total_payload_consumed);
      $display("footer gen / cons : %d  | %d " , total_footer_generated , total_footer_consumed);
     $finish();
     
     
  
   end
 

  
  
  
  

  /* ************ ******************MY VERY FIRST  INITIAL BLOCK *****************************
  initial begin
    resetn = 0;

    #103
    resetn = 1;
    traffic_work  = 4'b0001;
    fixed_dest    = 4'b0000;
    delay_en      = 4'b0000;
    fixed_dest_en = 4'b0000;// 4'b1111;
    dif_size_en   = 4'b0000;
    valid_drop_rate = '{default:0};
    
    
    backpressure[0] = 5'b00010;
    backpressure[1] = 5'b00010;
    backpressure[2] = 5'b00010;
    backpressure[3] = 5'b00010;
    
    */
    
    /*the below lines  were used to control ready signals, and are commented out because this jod is done by consumer now*/
   /*
    m_exanet_tx[0].header_ready   = 0;
    m_exanet_tx[0].payload_ready  = 0;
    m_exanet_tx[0].footer_ready   = 0;
    
        
    m_exanet_tx[1].header_ready   = 0;
    m_exanet_tx[1].payload_ready  = 0;
    m_exanet_tx[1].footer_ready   = 0;
    
        
    m_exanet_tx[2].header_ready   = 0;
    m_exanet_tx[2].payload_ready  = 0;
    m_exanet_tx[2].footer_ready   = 0;
    
        
    m_exanet_tx[3].header_ready   = 0;
    m_exanet_tx[3].payload_ready  = 0;
    m_exanet_tx[3].footer_ready   = 0;
   */
    /*
    #10
    traffic_work  = 4'b0101;
    #10
    traffic_work  = 4'b0111;
    #10
    traffic_work  = 4'b1111;
    */
    
  /*the below lines  were used to control ready signals, and are commented out because this jod is done by consumer now*/
      /*
      #500
      m_exanet_tx[0].header_ready   = 1;
      m_exanet_tx[0].payload_ready  = 1;
      m_exanet_tx[0].footer_ready   = 1;
      
          
      m_exanet_tx[1].header_ready   = 1;
      m_exanet_tx[1].payload_ready  = 1;
      m_exanet_tx[1].footer_ready   = 1;
      
          
      m_exanet_tx[2].header_ready   = 1;
      m_exanet_tx[2].payload_ready  = 1;
      m_exanet_tx[2].footer_ready   = 1;
      
          
      m_exanet_tx[3].header_ready   = 1;
      m_exanet_tx[3].payload_ready  = 1;
      m_exanet_tx[3].footer_ready   = 1;
      
    #500
       
     m_exanet_tx[0].header_ready   = 0;
     m_exanet_tx[0].payload_ready  = 0;
     m_exanet_tx[0].footer_ready   = 0;
     
         
     m_exanet_tx[1].header_ready   = 0;
     m_exanet_tx[1].payload_ready  = 0;
     m_exanet_tx[1].footer_ready   = 0;
     
         
     m_exanet_tx[2].header_ready   = 0;
     m_exanet_tx[2].payload_ready  = 0;
     m_exanet_tx[2].footer_ready   = 0;
     
         
     m_exanet_tx[3].header_ready   = 0;
     m_exanet_tx[3].payload_ready  = 0;
     m_exanet_tx[3].footer_ready   = 0;
     
    #500
     
   
       
       m_exanet_tx[0].header_ready   = 1;
       m_exanet_tx[0].payload_ready  = 1;
       m_exanet_tx[0].footer_ready   = 1;
       
           
       m_exanet_tx[1].header_ready   = 1;
       m_exanet_tx[1].payload_ready  = 1;
       m_exanet_tx[1].footer_ready   = 1;
       
           
       m_exanet_tx[2].header_ready   = 1;
       m_exanet_tx[2].payload_ready  = 1;
       m_exanet_tx[2].footer_ready   = 1;
       
           
       m_exanet_tx[3].header_ready   = 1;
       m_exanet_tx[3].payload_ready  = 1;
       m_exanet_tx[3].footer_ready   = 1;   
     */
     
    
 /*   
  end
  */
  
  
  
  
  
endmodule
