
`timescale 1ns/1ns
import exanet_crosb_pkg::*;
import exanet_pkg::*;


`include "ceiling_up_log2.vh"



module exa_crosb_top_with_VCs_tb();
  

  localparam testlength = 1000;
  localparam input_num  = 10;
  localparam output_num = 10;
  localparam prio_num   = 2;
  localparam vc_num     = 2;
  localparam data_width = 128;
  
  localparam conf_reg_num = 256;
  localparam S_AXI_DATA_WIDTH      = 128;
  localparam S_AXI_ADDR_WIDTH      = `log2(conf_reg_num*16);// 16 may needs to be changed !!!!!
  localparam S_AXI_ID_WIDTH        = 12;
  localparam dimension_x           = 4;
  localparam dimension_y           = 2;
  localparam dimension_z           = 2;
  
  localparam logVcPrio             = `log2(prio_num*vc_num);
  localparam logOutput             = `log2(output_num);
  localparam logPrio               = `log2(prio_num);
  localparam logVc                 = `log2(vc_num);

  reg                       clk		      = 0                            ;
  always #5 clk = ~clk;
  reg                       resetn	      = 0                            ;
  reg [input_num - 1 : 0]   traffic_work  = 0                            ;
  reg [input_num - 1 : 0]   dif_size_en   = 0                            ;
  reg [input_num - 1 : 0]   fixed_dest_en = 0                            ;
  reg [input_num - 1 : 0]   delay_en      = 0                            ;
  reg [input_num - 1 : 0]   fixed_header_vc_en = 0                       ;
  reg [9 : 0]               fixed_dest    = 0                            ; 

  reg [4:0]                 fixed_dest_x  = 0                            ;
  reg [4:0]                 fixed_dest_y  = 0                            ;
  reg [4:0]                 fixed_dest_z  = 0                            ;
  
  reg [4 : 0]               valid_drop_rate[input_num -1 :0]             ;
  reg [31:0]                phase = 0; 
  reg [4 : 0]               backpressure[output_num - 1 :0] = {default:0};
  
  reg [4 : 0]               fixed_vc_header = 0                          ;
  
   
  exanet s_exanet_rx[input_num - 1 :0]()                                 ;     
  exanet m_exanet_tx[output_num -1 :0]()                                 ;  
  
  logic [ 21:0]             i_src_coord = 22'b00_0000_0000_0000_0000_0000;
                                                                     
                                                                    
 /* logic [ 21:0]             i_src_coord_cons[output_num - 1 : 0] = {22'b00_0000_0000_0000_0001_0001,
                                                                    22'b00_0000_0000_0000_0001_0000,
                                                                    22'b00_0000_0000_0000_0000_0001,
                                                                    22'b00_0000_0000_0000_0000_0000}; 
  
  */
  reg [31:0] headers_generated[input_num-1:0] = {default:0} ;//{0,0,0,0} ;
  reg [31:0] headers_consumed[output_num-1:0] ={default:0}  ;
  logic [31:0] total_headers_generated                      ;
  logic [31:0] total_headers_consumed                       ;
  reg [31:0] payload_generated[input_num-1:0] ={default:0}  ;
  reg [31:0] payload_consumed[output_num-1:0] ={default:0}  ;
  logic [31:0] total_payload_generated                      ;
  logic [31:0] total_payload_consumed                       ;
  reg [31:0] footer_generated[input_num-1:0] ={default:0}   ;
  reg [31:0] footer_consumed[output_num-1:0] ={default:0}   ;
  logic [31:0] total_footer_generated                       ;
  logic [31:0] total_footer_consumed                        ;
  
  logic [logOutput-1 :0] dests_of_each_input[input_num-1:0][prio_num*vc_num-1 :0];
  
  

    // AXI Clock and Reset
  logic                           S_AXI_ACLK;
  logic                           S_AXI_ARESETN;
    // Memory Read Address Channel
  logic [S_AXI_ID_WIDTH-1:0]      S_AXI_ARID    = 0 ;  
  logic [S_AXI_ADDR_WIDTH-1:0]    S_AXI_ARADDR  = 0 ;  
  logic [7:0]                     S_AXI_ARLEN   = 0 ;  
  logic [2:0]                     S_AXI_ARSIZE  = 0 ;  
  logic [1:0]                     S_AXI_ARBURST = 0 ;  
  logic [1:0]                     S_AXI_ARLOCK  = 0 ;  
  logic [3:0]                     S_AXI_ARCACHE = 0 ;  
  logic [2:0]                     S_AXI_ARPROT  = 0 ;  
  logic                           S_AXI_ARVALID = 0 ;  
  logic                           S_AXI_ARREADY     ;  
  // Memory Read Data Channel                   = 0    
  logic [S_AXI_ID_WIDTH-1:0]      S_AXI_RID         ;  
  logic [S_AXI_DATA_WIDTH-1:0]    S_AXI_RDATA       ;  
  logic [1:0]                     S_AXI_RRESP       ;  
  logic                           S_AXI_RLAST       ;  
  logic                           S_AXI_RVALID      ;  
  logic                           S_AXI_RREADY  = 0 ;  
  // Memory Write Address Channel               = 0    
  logic [S_AXI_ID_WIDTH-1:0]      S_AXI_AWID    = 0 ;  
  logic [S_AXI_ADDR_WIDTH-1:0]    S_AXI_AWADDR  = 0 ;  
  logic [7:0]                     S_AXI_AWLEN   = 0 ;  
  logic [2:0]                     S_AXI_AWSIZE  = 0 ;  
  logic [1:0]                     S_AXI_AWBURST = 0 ;  
  logic [1:0]                     S_AXI_AWLOCK  = 0 ;  
  logic [3:0]                     S_AXI_AWCACHE = 0 ;  
  logic [2:0]                     S_AXI_AWPROT  = 0 ;  
  logic                           S_AXI_AWVALID = 0 ;  
  logic                           S_AXI_AWREADY     ;  
  // Memory Write Data Channel                  = 0    
  logic [S_AXI_DATA_WIDTH-1:0]    S_AXI_WDATA   = 0 ;  
  logic [(S_AXI_DATA_WIDTH/8)-1:0]S_AXI_WSTRB   = 0 ;  
  logic                           S_AXI_WLAST   = 0 ;  
  logic                           S_AXI_WVALID  = 0 ;  
  logic                           S_AXI_WREADY      ;  
      //
      // Memory Write Responce Channel
  logic [S_AXI_ID_WIDTH-1:0]     S_AXI_BID          ; 
  logic [1:0]                    S_AXI_BRESP        ;
  logic                          S_AXI_BVALID       ;
  logic                          S_AXI_BREADY  = 0  ;
      
   
  cntrl_info_t  cntrl_info;


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
        .prio_num(prio_num),
        .dimension_x(dimension_x),
        .dimension_y(dimension_y),
        .dimension_z(dimension_z)
      )traffic_gen (
        .clk(clk),
        .resetn(resetn),
        .i_src_coord(i),
        .dif_size_enable(dif_size_en[i]),
        .fixed_dest_enable(fixed_dest_en[i]),
        //.fixed_dest(fixed_dest),
        .fixed_dest_x(fixed_dest_x),
        .fixed_dest_y(fixed_dest_y),
        .fixed_dest_z(fixed_dest_z),
        
        .fixed_header_vc_enable(fixed_header_vc_en),
        .fixed_header_vc(fixed_vc_header),
        .delay_enable(delay_en),
        .i_work(traffic_work[i]),
        .exa(s_exanet_rx[i]),
        .valid_drop_rate(valid_drop_rate[i])
      );
    end 
  endgenerate
  
  
  generate
    for (i = 0 ; i < output_num ; i = i +1 ) begin :traffic_cons
      exa_crosb_traffic_consumer_with_VCs #(
        .vc_num(vc_num),
        .prio_num(prio_num),
        .input_num(input_num),
        .output_num(output_num)
      )traffic_consumer (
        .clk(clk),
        .resetn(resetn),
        .i_src_coord(i),//just because 18(example dest) is multiple of 9    //it was 'h10*(i + 3) and before it was 'h10*(i/2)
        .exa(m_exanet_tx[i]),
        .i_backpressure(backpressure[i]),
        .i_dests_of_each_input(dests_of_each_input)
      );     

    end 
  endgenerate
  
  
  
        
//--------------- TASK WRITE--------------------------
  task Write(input [S_AXI_ADDR_WIDTH - 1 : 0] awaddr, input [S_AXI_DATA_WIDTH - 1 : 0] wdata); begin
    @(negedge clk);
    S_AXI_AWADDR  = awaddr;
    S_AXI_WDATA   = wdata;
    S_AXI_WSTRB   = 4'hf;// in reg_file, [3:0] bytes are checked..if they are 4'hf, wdata[[31:0]] are written in cntrl_info_reg[i][31:0]
    S_AXI_AWVALID = 1;
    S_AXI_WVALID  = 1;
    S_AXI_BREADY  = 1;
 
    while(!(/*S_AXI_AWREADY &*/ S_AXI_WREADY)) @(posedge clk);
    @(negedge clk);  
    S_AXI_AWVALID = 0;
    S_AXI_WVALID = 0;
    while(!(S_AXI_BVALID)) @(posedge clk);          
    @(negedge clk);        
    S_AXI_BREADY = 0;
 
  end 
  endtask 
  
  
  

  
  exa_crosb_top_with_VCs #(
      .input_num(input_num),
      .output_num(output_num),
      .prio_num(prio_num),
      .vc_num(vc_num),
      .max_ports(10),//it was 4
      .S_AXI_ID_WIDTH   (3),
      .S_AXI_DATA_WIDTH (128),
      .conf_reg_num(conf_reg_num),
      /*num of addresses below should be the same as max_ports = output_num*/
      
      .PORTx_LOW_ADDR   ({42'h38000000000,42'h38000000010,42'h38000000020,42'h38000000030,42'h38000000040,42'h38000000050,42'h38000000060,42'h38000000070,42'h38000000080,42'h38000000090} ),
      .PORTx_HIGH_ADDR  ({42'h3800000000f,42'h3800000001f,42'h3800000002f,42'h3800000003f,42'h3800000004f,42'h3800000005f,42'h3800000006f,42'h3800000007f,42'h3800000008f,42'h3800000009f} ),
      .in_fifo_depth          ( 40 ),
      .out_fifo_depth         ( 40 ),
      //.net_route_reg_enable  ( 8'b11111111),
      .net_route_reg_enable  ( 4'b0000),
      .dimension_x(dimension_x),
      .dimension_y(dimension_y),
      .dimension_z(dimension_z)
     
     )exanet_crosb_top_with_VCs_dut (
       
       .ACLK(clk),
       .ARESETN(resetn),
       .i_src_coord(i_src_coord),
       .exanet_rx(s_exanet_rx),
       .exanet_tx(m_exanet_tx),
       .o_dests_of_each_input(dests_of_each_input),
       
       
          // AXI Clock and Reset
       .S_AXI_ACLK(clk),
       .S_AXI_ARESETN(resetn),
       // Memory Read Address Channel
       .S_AXI_ARID(S_AXI_ARID),
       .S_AXI_ARADDR(S_AXI_ARADDR),
       .S_AXI_ARLEN(S_AXI_ARLEN),
       .S_AXI_ARSIZE(S_AXI_ARSIZE),
       .S_AXI_ARBURST(S_AXI_ARBURST),
       .S_AXI_ARLOCK(S_AXI_ARLOCK),
       .S_AXI_ARCACHE(S_AXI_ARCACHE),
       .S_AXI_ARPROT(S_AXI_ARPROT),
       .S_AXI_ARVALID(S_AXI_ARVALID),
       .S_AXI_ARREADY(S_AXI_ARREADY),
       // Memory Read Data Channel
       .S_AXI_RID(S_AXI_RID),
       .S_AXI_RDATA(S_AXI_RDATA),
       .S_AXI_RRESP(S_AXI_RRESP),
       .S_AXI_RLAST(S_AXI_RLAST),
       .S_AXI_RVALID(S_AXI_RVALID),
       .S_AXI_RREADY(S_AXI_RREADY),
       // Memory Write Address Channel
       .S_AXI_AWID(S_AXI_AWID),
       .S_AXI_AWADDR(S_AXI_AWADDR),
       .S_AXI_AWLEN(S_AXI_AWLEN),
       .S_AXI_AWSIZE(S_AXI_AWSIZE),
       .S_AXI_AWBURST(S_AXI_AWBURST),
       .S_AXI_AWLOCK(S_AXI_AWLOCK),
       .S_AXI_AWCACHE(S_AXI_AWCACHE),
       .S_AXI_AWPROT(S_AXI_AWPROT),
       .S_AXI_AWVALID(S_AXI_AWVALID),
       .S_AXI_AWREADY(S_AXI_AWREADY),
       // Memory Write Data Channel
       .S_AXI_WDATA(S_AXI_WDATA),
       .S_AXI_WSTRB(S_AXI_WSTRB),
       .S_AXI_WLAST(S_AXI_WLAST),
       .S_AXI_WVALID(S_AXI_WVALID),
       .S_AXI_WREADY(S_AXI_WREADY),
       //
       // Memory Write Responce Channel
       .S_AXI_BID(S_AXI_BID),
       .S_AXI_BRESP(S_AXI_BRESP),
       .S_AXI_BVALID(S_AXI_BVALID),
       .S_AXI_BREADY(S_AXI_BREADY),
       .o_cntrl_info(cntrl_info)
       //.i_pkt_counter_input(pkt_counter_from_e2s),
       //.i_pkt_counter_output(pkt_counter_from_s2e)       
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
    input [input_num - 1 : 0] t_traffic_work                   ;
    input [input_num - 1 : 0] t_dif_size_en                    ;
    input [input_num - 1 : 0] t_delay_en                       ;
    input [input_num - 1 : 0] t_fixed_dest_en                  ;
   // input [9 : 0]             t_fixed_dest                     ;
    input [3 : 0]             t_fixed_dest_x                   ;
    input [3 : 0]             t_fixed_dest_y                   ;
    input [3 : 0]             t_fixed_dest_z                   ;
    
    input [4 : 0]             t_backpressure   [output_num-1:0];
    input [4 : 0]             t_valid_drop_rate[input_num-1 :0];
    input [31:0]              t_test_length                    ;
    input [input_num - 1 : 0] t_fixed_header_vc_enable         ;
    input [4 : 0]             t_fixed_vc_header                ;  

    begin
      $display("begin new round of tests");
      $display("Inputs that work            : %0b",t_traffic_work);     
      $display("dif size enable             : %0b",t_dif_size_en);      
      $display("fixed destination enable    : %0b",t_fixed_dest_en); 
     // $display("fixed destination           : %0d",t_fixed_dest);
      $display("fixed destination x         : %0d",t_fixed_dest_x);
      $display("fixed destination y         : %0d",t_fixed_dest_y);
      $display("fixed destination z         : %0d",t_fixed_dest_z);
      
      $display("delay destination           : %0b",t_delay_en); 
      $display("backpressure value          : %0p",t_backpressure); 
      $display("valid_drop value            : %0p",t_valid_drop_rate);  
      $display("fixed_header_vc_enable      : %0d",t_fixed_header_vc_enable);  
      $display("fixed_vc                    : %0d",t_fixed_vc_header);    
      $display("---------------------------------------------------");     
            
      //fixed_dest         = t_fixed_dest        ;
      
      fixed_dest_x         = t_fixed_dest_x        ;
      fixed_dest_y         = t_fixed_dest_y        ;
      fixed_dest_z         = t_fixed_dest_z        ;
      
      fixed_vc_header    = t_fixed_vc_header   ;
      for (int i = 0 ; i < input_num ; i++) begin
       // traffic_work[i]    = t_traffic_work[i]   ;       
        fixed_dest_en[i]   = t_fixed_dest_en[i]  ;
        delay_en[i]        = t_delay_en[i]       ;
        valid_drop_rate[i] = t_valid_drop_rate[i];
        dif_size_en[i]     = t_dif_size_en[i];
        fixed_header_vc_en[i] = t_fixed_header_vc_enable[i];
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
    reg [`log2(vc_num*prio_num)-1:0]rVc;
    reg [input_num-1:0] r16b;
    reg [input_num-1:0] r16c;
    reg [input_num-1:0] r16d;
    
    
    reg [`log2(dimension_x)-1:0]rDstX;
    reg [`log2(dimension_y)-1:0]rDstY;
    reg [`log2(dimension_z)-1:0]rDstZ;
    //reg [15:0] r16e;
  
   
   
   initial begin
     resetn = 0;
     
          S_AXI_AWADDR  = 0;
          S_AXI_WDATA   = 0;
          S_AXI_WSTRB   = 0;
          S_AXI_AWVALID = 0;
          S_AXI_WVALID  = 0;
          S_AXI_BREADY  = 0;
  
     #103
     resetn = 1;
     
     
  
       
     
     
     //Write(5'b00000, 64'b0000_0000_0000_0000_0000_0000_0000);
     Write(5'b10000, 64'b0110_0101_0100_0011_0010_0001_0000);
          

    // #200
     phase ++ ;
     $display("--------------phase 1--------------");      
     //     traffic_work , dif_size_en , delay_enable ,fixed_dest_en, fixed_dest,            backpressure, valid_drop_rate,test_length ,fixed_header_vc_enable, fixed_header_vc
     //singe size, single type , single dest , no backpressure , no validdrop
    //run_test ( 16'b0000000000000001 ,   16'b0000000000000000 ,    16'b0000000000000000 ,   16'b0000000000000001 , 4'b0011, 4'b0000,4'b0000,     '{default:0} ,  '{default:0}  , testlength, 16'b0000000000000000, 4'b0000);
     
     run_test ( 10'b0000000001 ,   10'b0000000000 ,    10'b0000000000 ,   10'b0000000001 , 4'b0011, 4'b0001,4'b0000,     '{default:0} ,  '{default:0}  , testlength, 10'b0000000000, 4'b0000);  
     //with backpressure  
     run_test ( 10'b0000000001 ,   10'b0000000000 ,    10'b0000000000 ,   10'b0000000001 , 4'b0001, 4'b0001,4'b0000,     '{4,4,4,4,4,4,4,4,4,4}   ,  '{default:0}  , testlength, 10'b0000000000, 4'b0000);  
     //with valid_drop
     
     run_test ( 10'b0000000001 ,   10'b0000000000 ,    10'b0000000000 ,   10'b0000000001 , 4'b0010, 4'b0000,4'b0000,     '{default:0} ,  '{4,4,4,4,4,4,4,4,4,4}  ,   testlength, 10'b0000000000, 4'b0000);  
     //with backpressure and valid_drop
     run_test ( 10'b0000000001 ,   10'b0000000000 ,    10'b0000000000 ,   10'b0000000001 , 4'b0011, 4'b0000,4'b0000,     '{4,4,4,4,4,4,4,4,4,4}   ,  '{4,4,4,4,4,4,4,4,4,4}  ,   testlength, 10'b0000000000, 4'b0000);  
  
     $display("--------------phase 1 with delay between packets------------");   
    //     traffic_work , dif_size_en , delay_enable ,fixed_dest_en, fixed_dest,            backpressure, valid_drop_rate,test_length ,fixed_header_vc_enable, fixed_header_vc
     //singe size, single type , single dest , no backpressure , no validdrop, and delay
     run_test ( 10'b0000000010 ,   10'b0000000000 ,    10'b0000000001 ,   10'b0000000010 ,  4'b0001, 4'b0000,14'b0000,    '{default:0} ,  '{default:0}  , testlength, 10'b0000000000, 4'b0000);  
     //with backpressure  
     run_test ( 10'b0000000010 ,   10'b0000000000 ,    10'b0000000001 ,   10'b0000000010 ,  4'b0001, 4'b0001,4'b0000,     '{4,4,4,4,4,4,4,4,4,4}   ,  '{default:0}  , testlength, 10'b0000000000, 4'b0000);  
     //with valid_drop
     run_test ( 10'b0000000010 ,   10'b0000000000 ,    10'b0000000001 ,   10'b0000000010 ,  4'b0010, 4'b0000,4'b0000,    '{default:0} ,  '{4,4,4,4,4,4,4,4,4,4}  ,   testlength, 10'b0000000000, 4'b0000);  
     //with backpressure and valid_drop
     run_test ( 10'b0000000010 ,   10'b0000000000 ,    10'b0000000001 ,   10'b0000000010 ,  4'b0011, 4'b0000,4'b0000,    '{4,4,4,4,4,4,4,4,4,4}   ,  '{4,4,4,4,4,4,4,4,4,4}  ,   testlength, 10'b0000000000, 4'b0000);  
  
     phase ++ ;
     $display("--------------phase 3 with dif_size_en = 1--------------");   
     //     traffic_work , dif_size_en , delay_enable ,fixed_dest_en, fixed_dest,            backpressure, valid_drop_rate,test_length ,fixed_header_vc_enable, fixed_header_vc
     //mutiple size, single type , single dest , no backpressure , no validdrop
     run_test ( 10'b0000000001 ,   10'b0000000001 ,    10'b0000000000 ,   10'b0000000001 ,   4'b0011, 4'b0000,4'b0000,     '{default:0} ,  '{default:0}  , testlength, 10'b0000000000, 4'b0000);  
     //with backpressure  
     run_test ( 10'b0000000001 ,   10'b0000000001 ,    10'b0000000000 ,   10'b0000000001 ,   4'b0011, 4'b0000,4'b0000,     '{4,4,4,4,4,4,4,4,4,4}   ,  '{default:0}  , testlength, 10'b0000000000, 4'b0000);  
     //with valid_drop
     run_test ( 10'b0000000001 ,   10'b0000000001 ,    10'b0000000000 ,   10'b0000000001 ,   4'b0010, 4'b0001,4'b0000,     '{default:0} ,  '{4,4,4,4,4,4,4,4,4,4}  ,   testlength, 10'b0000000000, 4'b0000);  
     //with backpressure and valid_drop
     run_test ( 10'b0000000001 ,   10'b0000000001 ,    10'b0000000000 ,   10'b0000000001 ,   4'b0011, 4'b0000,4'b0000,     '{4,4,4,4,4,4,4,4,4,4}   ,  '{4,4,4,4,4,4,4,4,4,4}  ,   testlength, 10'b0000000000, 4'b0000);  
  
     phase ++ ;
     $display("--------------phase 4 with multiple dests--------------");   
    //     traffic_work , dif_size_en , delay_enable ,fixed_dest_en, fixed_dest,            backpressure, valid_drop_rate,test_length ,fixed_header_vc_enable, fixed_header_vc
     //singe size, single type , multi dest , no backpressure , no validdrop
     run_test ( 10'b0000000001 ,   10'b0000000000 ,    10'b0000000000 ,   10'b0000000000 ,  4'b0011, 4'b0000,4'b0000,     '{default:0} ,  '{default:0}  , testlength, 10'b0000000000, 4'b0000);  
     //with backpressure  
     run_test ( 10'b0000000001 ,   10'b0000000000 ,    10'b0000000000 ,   10'b0000000000 ,  4'b0011, 4'b0000,4'b0000,     '{4,4,4,4,4,4,4,4,4,4}   ,  '{default:0}  , testlength, 10'b0000000000, 4'b0000);  
     //with valid_drop
     run_test ( 10'b0000000001 ,   10'b0000000000 ,    10'b0000000000 ,   10'b0000000000 ,  4'b0011, 4'b0000,4'b0000,     '{default:0} ,  '{4,4,4,4,4,4,4,4,4,4}  ,   testlength, 10'b0000000000, 4'b0000);  
     //with backpressure and valid_drop
     run_test ( 10'b0000000001 ,   10'b0000000000 ,    10'b0000000000 ,   10'b0000000000 ,  4'b0011, 4'b0000,4'b0000,     '{4,4,4,4,4,4,4,4,4,4}   ,  '{4,4,4,4,4,4,4,4,4,4}  ,   testlength, 10'b0000000000, 4'b0000);  
  
     phase ++ ;
     
     
     $display("--------------phase 5--------------");   
    //     traffic_work , dif_size_en , delay_enable ,fixed_dest_en, fixed_dest,            backpressure, valid_drop_rate,test_length ,fixed_header_vc_enable, fixed_header_vc
     //multiple input singe size, single type , single dest , no backpressure , no validdrop
     run_test ( 10'b1111111111 ,  10'b0000000000 ,    10'b0000000000 ,    10'b1111111111 ,   4'b0000, 4'b0000,4'b0000,     '{default:0} , '{default:0}  , testlength, 10'b0000000000, 4'b0000);  
     //with backpressure  
     run_test ( 10'b1111111111 ,  10'b0000000000 ,    10'b0000000000 ,    10'b1111111111 ,   4'b0011, 4'b0000,4'b0000,     '{4,4,4,4,4,4,4,4,4,4}   , '{default:0}  , testlength, 10'b0000000000, 4'b0000);  
     //with valid_drop
     run_test ( 10'b1111111111 ,  10'b0000000000 ,    10'b0000000000 ,    10'b1111111111 ,   4'b0010, 4'b0001,4'b0000,     '{default:0} ,  '{4,4,4,4,4,4,4,4,4,4}  ,  testlength, 10'b0000000000, 4'b0000);  
     //with backpressure and valid_drop
     run_test ( 10'b1111111111 , 10'b0000000000 ,     10'b0000000000 ,    10'b1111111111 ,   4'b0001, 4'b0001,4'b0000,     '{4,4,4,4,4,4,4,4,4,4}   ,  '{4,4,4,4,4,4,4,4,4,4}  ,   testlength, 10'b0000000000, 4'b0000);  
  
     phase ++ ;
     $display("--------------phase 6--------------");   
     //     traffic_work , dif_size_en , delay_enable ,fixed_dest_en, fixed_dest,            backpressure, valid_drop_rate,test_length ,fixed_header_vc_enable, fixed_header_vc
     //multiple input ,  single size, single type , multiple dest , no backpressure , no validdrop
     run_test ( 10'b1111111111 ,  10'b0000000000 ,    10'b0000000000 ,    10'b0000000000 ,   4'b0011, 4'b0000,4'b0000,     '{default:0} , '{default:0}  , testlength, 10'b0000000000, 4'b0000);  
     //with backpressure  
     run_test ( 10'b1111111111 ,  10'b0000000000 ,    10'b0000000000 ,    10'b0000000000 ,   4'b0011, 4'b0000,4'b0000,     '{4,4,4,4,4,4,4,4,4,4}   , '{default:0}  , testlength, 10'b0000000000, 4'b0000);  
     //with valid_drop
     run_test ( 10'b1111111111 ,  10'b0000000000 ,    10'b0000000000 ,    10'b0000000000 ,   4'b0011, 4'b0000,4'b0000,     '{default:0} ,  '{4,4,4,4,4,4,4,4,4,4}   , testlength, 10'b0000000000, 4'b0000);  
     //with backpressure and valid_drop
     run_test ( 10'b1111111111 ,  10'b0000000000 ,    10'b0000000000 ,    10'b0000000000 ,   4'b0011, 4'b0000,4'b0000,     '{4,4,4,4,4,4,4,4,4,4}   ,  '{4,4,4,4,4,4,4,4,4,4}   , testlength, 10'b0000000000, 4'b0000);  
  
     phase ++ ;
     $display("--------------phase 7--------------");   
     //     traffic_work , dif_size_en , delay_enable ,fixed_dest_en, fixed_dest,            backpressure, valid_drop_rate,test_length ,fixed_header_vc_enable, fixed_header_vc
     //multiple input ,  multiple size, single type , single dest , no backpressure , no validdrop
     run_test ( 10'b1111111111 ,  10'b1111111111 ,    10'b0000000000 ,    10'b1111111111 ,   4'b0000, 4'b0000,4'b0000,    '{default:0} ,  '{default:0}, testlength, 10'b0000000000, 4'b0000);  
     //with backpressure   
     run_test ( 10'b1111111111 ,  10'b1111111111 ,    10'b0000000000 ,    10'b1111111111 ,   4'b0011, 4'b0001,4'b0000,    '{4,4,4,4,4,4,4,4,4,4}   ,  '{default:0}, testlength, 10'b0000000000, 4'b0000);  
     //with valid_drop
     run_test ( 10'b1111111111  , 10'b1111111111 ,    10'b0000000000 ,    10'b1111111111 ,   4'b0001, 4'b0000,4'b0000,    '{default:0} ,  '{4,4,4,4,4,4,4,4,4,4}  , testlength, 10'b0000000000, 4'b0000);  
     //with backpressure and valid_drop
     run_test ( 10'b1111111111  , 10'b1111111111 ,    10'b0000000000 ,    10'b1111111111 ,   4'b0010, 4'b0001,4'b0000,    '{4,4,4,4,4,4,4,4,4,4}   ,  '{4,4,4,4,4,4,4,4,4,4}  , testlength, 10'b0000000000, 4'b0000);  
  
     phase ++ ;
     $display("--------------phase 8--------------");   
     //     traffic_work , dif_size_en , delay_enable ,fixed_dest_en, fixed_dest,            backpressure, valid_drop_rate,test_length ,fixed_header_vc_enable, fixed_header_vc
     //multiple input, multiple size, multiple type , multiple dest , no backpressure , no validdrop
     run_test ( 10'b1111111111 ,  10'b1111111111 ,    10'b0000000000 ,    10'b0000000000 ,   4'b0011, 4'b0000,4'b0000,    '{default:0} ,  '{default:0} , testlength, 10'b0000000000, 4'b0000);  
     //with backpressure  
     run_test ( 10'b1111111111 ,  10'b1111111111 ,    10'b0000000000 ,    10'b0000000000 ,   4'b0011, 4'b0000,4'b0000,    '{4,4,4,4,4,4,4,4,4,4}   ,  '{default:0} , testlength, 10'b0000000000, 4'b0000);  
     //with valid_drop
     run_test ( 10'b1111111111  , 10'b1111111111 ,    10'b0000000000 ,    10'b0000000000 ,   4'b0011, 4'b0000,4'b0000,    '{default:0} ,  '{4,4,4,4,4,4,4,4,4,4}   , testlength, 10'b0000000000, 4'b0000);  
     //with backpressure and valid_drop
     run_test ( 10'b1111111111  , 10'b1111111111 ,    10'b0000000000 ,    10'b0000000000 ,   4'b0011, 4'b0000,4'b0000,    '{4,4,4,4,4,4,4,4,4,4}   ,  '{4,4,4,4,4,4,4,4,4,4}   , testlength, 10'b0000000000, 4'b0000);  
  
     $display("--------------phase 8 with delays--------------");   
     //     traffic_work , dif_size_en , delay_enable ,fixed_dest_en, fixed_dest,            backpressure, valid_drop_rate,test_length ,fixed_header_vc_enable, fixed_header_vc
     //multiple input multiple size, multiple type , multiple dest , no backpressure , no validdrop
     run_test ( 10'b1111111111 ,  10'b1111111111 ,   10'b1111111111 ,     10'b0000000000 ,   4'b0011, 4'b0000,4'b0000,    '{default:0} , '{default:0}  , testlength, 10'b0000000000, 4'b0000);  
     //with backpressure  
     run_test ( 10'b1111111111 ,  10'b1111111111 ,   10'b1111111111 ,     10'b0000000000 ,   4'b0011, 4'b0000,4'b0000,    '{4,4,4,4,4,4,4,4,4,4}   , '{default:0}  , testlength, 10'b0000000000, 4'b0000);  
     //with valid_drop
     run_test ( 10'b1111111111  , 10'b1111111111 ,   10'b1111111111 ,     10'b0000000000 ,   4'b0011, 4'b0000,4'b0000,    '{default:0} ,  '{4,4,4,4,4,4,4,4,4,4}   , testlength, 10'b0000000000, 4'b0000);  
     //with backpressure and valid_drop
     run_test ( 10'b1111111111  , 10'b1111111111 ,   10'b1111111111 ,     10'b0000000000 ,   4'b0011, 4'b0000,4'b0000,   '{4,4,4,4,4,4,4,4,4,4}   ,  '{4,4,4,4,4,4,4,4,4,4}   , testlength, 10'b0000000000, 4'b0000);  
  
     phase ++ ;
     
  
     $display("--------------phase 9 with fixed low prio vc--------------");   
     //     traffic_work , dif_size_en , delay_enable ,fixed_dest_en, fixed_dest,            backpressure, valid_drop_rate,test_length ,fixed_header_vc_enable, fixed_header_vc
     //multiple input multiple size, multiple type , multiple dest , no backpressure , no validdrop
     run_test ( 10'b1111111111 ,  10'b1111111111 ,   10'b1111111111 ,     10'b0000000000 ,   4'b0011, 4'b0000,4'b0000,    '{default:0} , '{default:0}  , testlength, 10'b1111111111, 4'b0001);  
     //with backpressure  
     run_test ( 10'b1111111111 ,  10'b1111111111 ,   10'b1111111111 ,     10'b0000000000 ,   4'b0011, 4'b0000,4'b0000,    '{4,4,4,4,4,4,4,4,4,4}   , '{default:0}  , testlength, 10'b0000001001, 4'b0001);  
    //with valid_drop 
     run_test ( 10'b1111111111  , 10'b1111111111 ,   10'b1111111111 ,     10'b0000000000 ,   4'b0011, 4'b0000,4'b0000,    '{default:0} ,  '{4,4,4,4,4,4,4,4,4,4}   , testlength, 10'b0000000110, 4'b0001);  
    //with backpressure and valid_drop
     run_test ( 10'b1111111111  , 10'b1111111111 ,   10'b1111111111 ,     10'b0000000000 ,   4'b0011, 4'b0000,4'b0000,    '{4,4,4,4,4,4,4,4,4,4}   ,  '{4,4,4,4,4,4,4,4,4,4}   , testlength, 10'b0000000101, 4'b0001);  
          
     
     phase ++ ;    
  
     $display("--------------phase 10 with fixed high prio vc--------------");   
    //     traffic_work , dif_size_en , delay_enable ,fixed_dest_en, fixed_dest,            backpressure, valid_drop_rate,test_length ,fixed_header_vc_enable, fixed_header_vc
     //multiple input multiple size, multiple type , multiple dest , no backpressure , no validdrop
     run_test ( 10'b1111111111 ,  10'b1111111111 ,   10'b1111111111 ,     10'b0000000000 ,   4'b0011, 4'b0000,4'b0000,    '{default:0} , '{default:0}  , testlength, 10'b1111111111, 4'b0011);  
     //with backpressure  
     run_test ( 10'b1111111111 ,  10'b1111111111 ,   10'b1111111111 ,     10'b0000000000 ,   4'b0011, 4'b0000,4'b0000,    '{4,4,4,4,4,4,4,4,4,4}   , '{default:0}  , testlength, 10'b1111111111, 4'b0011);  
    //with valid_drop
     run_test ( 10'b1111111111  , 10'b1111111111 ,   10'b1111111111 ,     10'b0000000000 ,   4'b0011, 4'b0000,4'b0000,    '{default:0} ,  '{4,4,4,4,4,4,4,4,4,4}   , testlength, 10'b1111111111, 4'b0011);  
    //with backpressure and valid_drop
     run_test ( 10'b1111111111  , 10'b1111111111 ,   10'b1111111111 ,     10'b0000000000 ,   4'b0011, 4'b0000,4'b0000,    '{4,4,4,4,4,4,4,4,4,4}   ,  '{4,4,4,4,4,4,4,4,4,4}   , testlength, 10'b1111111111, 4'b0011);  
          
     
         
     
     
     
     
     
     
     
     
     
     
   /*   
    
    
     run_test ( 4'b0001 ,   4'b0000 ,    4'b0000 ,   4'b0001 , 4'b0011, 4'b0000,4'b0000,     '{default:0} ,  '{default:0}  , testlength, 4'b0000, 4'b0000);  
     //with backpressure  
    run_test ( 4'b0001 ,   4'b0000 ,    4'b0000 ,   4'b0001 , 4'b0001, 4'b0001,4'b0000,     '{8,8,8,8}   ,  '{default:0}  , testlength, 4'b0000, 4'b0000);  
     //with valid_drop
     
     run_test ( 4'b0001 ,   4'b0000 ,    4'b0000 ,   4'b0001 , 4'b0010, 4'b0000,4'b0000,     '{default:0} ,  '{8,8,8,8}  ,   testlength, 4'b0000, 4'b0000);  
     //with backpressure and valid_drop
     run_test ( 4'b0001 ,   4'b0000 ,    4'b0000 ,   4'b0001 , 4'b0011, 4'b0000,4'b0000,     '{8,8,8,8}   ,  '{8,8,8,8}  ,   testlength, 4'b0000, 4'b0000);  
  
     $display("--------------phase 1 with delay between packets------------");   
    //     traffic_work , dif_size_en , delay_enable ,fixed_dest_en, fixed_dest,            backpressure, valid_drop_rate,test_length ,fixed_header_vc_enable, fixed_header_vc
     //singe size, single type , single dest , no backpressure , no validdrop, and delay
     run_test ( 4'b0010 ,   4'b0000 ,    4'b0001 ,   4'b0010 ,  4'b0001, 4'b0000,4'b0000,    '{default:0} ,  '{default:0}  , testlength, 4'b0000, 4'b0000);  
     //with backpressure  
     run_test ( 4'b0010 ,   4'b0000 ,    4'b0001 ,   4'b0010 ,  4'b0001, 4'b0001,4'b0000,     '{8,8,8,8}   ,  '{default:0}  , testlength, 4'b0000, 4'b0000);  
     //with valid_drop
     run_test ( 4'b0010 ,   4'b0000 ,    4'b0001 ,   4'b0010 ,  4'b0010, 4'b0000,4'b0000,    '{default:0} ,  '{8,8,8,8}  ,   testlength, 4'b0000, 4'b0000);  
     //with backpressure and valid_drop
     run_test ( 4'b0010 ,   4'b0000 ,    4'b0001 ,   4'b0010 ,  4'b0011, 4'b0000,4'b0000,    '{8,8,8,8}   ,  '{8,8,8,8}  ,   testlength, 4'b0000, 4'b0000);  
  
     phase ++ ;
     $display("--------------phase 3 with dif_size_en = 1--------------");   
     //     traffic_work , dif_size_en , delay_enable ,fixed_dest_en, fixed_dest,            backpressure, valid_drop_rate,test_length ,fixed_header_vc_enable, fixed_header_vc
     //mutiple size, single type , single dest , no backpressure , no validdrop
     run_test ( 4'b0001 ,   4'b0001 ,    4'b0000 ,   4'b0001 ,   4'b0011, 4'b0000,4'b0000,     '{default:0} ,  '{default:0}  , testlength, 4'b0000, 4'b0000);  
     //with backpressure  
     run_test ( 4'b0001 ,   4'b0001 ,    4'b0000 ,   4'b0001 ,   4'b0011, 4'b0000,4'b0000,     '{8,8,8,8}   ,  '{default:0}  , testlength, 4'b0000, 4'b0000);  
     //with valid_drop
     run_test ( 4'b0001 ,   4'b0001 ,    4'b0000 ,   4'b0001 ,   4'b0010, 4'b0001,4'b0000,     '{default:0} ,  '{8,8,8,8}  ,   testlength, 4'b0000, 4'b0000);  
     //with backpressure and valid_drop
     run_test ( 4'b0001 ,   4'b0001 ,    4'b0000 ,   4'b0001 ,   4'b0011, 4'b0000,4'b0000,     '{8,8,8,8}   ,  '{8,8,8,8}  ,   testlength, 4'b0000, 4'b0000);  
  
     phase ++ ;
     $display("--------------phase 4 with multiple dests--------------");   
    //     traffic_work , dif_size_en , delay_enable ,fixed_dest_en, fixed_dest,            backpressure, valid_drop_rate,test_length ,fixed_header_vc_enable, fixed_header_vc
     //singe size, single type , multi dest , no backpressure , no validdrop
     run_test ( 4'b0001 ,   4'b0000 ,    4'b0000 ,   4'b0000 ,  4'b0011, 4'b0000,4'b0000,     '{default:0} ,  '{default:0}  , testlength, 4'b0000, 4'b0000);  
     //with backpressure  
     run_test ( 4'b0001 ,   4'b0000 ,    4'b0000 ,   4'b0000 ,  4'b0011, 4'b0000,4'b0000,     '{8,8,8,8}   ,  '{default:0}  , testlength, 4'b0000, 4'b0000);  
     //with valid_drop
     run_test ( 4'b0001 ,   4'b0000 ,    4'b0000 ,   4'b0000 ,  4'b0011, 4'b0000,4'b0000,     '{default:0} ,  '{8,8,8,8}  ,   testlength, 4'b0000, 4'b0000);  
     //with backpressure and valid_drop
     run_test ( 4'b0001 ,   4'b0000 ,    4'b0000 ,   4'b0000 ,  4'b0011, 4'b0000,4'b0000,     '{8,8,8,8}   ,  '{8,8,8,8}  ,   testlength, 4'b0000, 4'b0000);  
  
     phase ++ ;
     
     
     $display("--------------phase 5--------------");   
    //     traffic_work , dif_size_en , delay_enable ,fixed_dest_en, fixed_dest,            backpressure, valid_drop_rate,test_length ,fixed_header_vc_enable, fixed_header_vc
     //multiple input singe size, single type , single dest , no backpressure , no validdrop
     run_test ( 4'b1111 ,  4'b0000 ,    4'b0000 ,    4'b1111 ,   4'b0000, 4'b0000,4'b0000,     '{default:0} , '{default:0}  , testlength, 4'b0000, 4'b0000);  
     //with backpressure  
     run_test ( 4'b1111 ,  4'b0000 ,    4'b0000 ,    4'b1111 ,   4'b0011, 4'b0000,4'b0000,     '{8,8,8,8}   , '{default:0}  , testlength, 4'b0000, 4'b0000);  
     //with valid_drop
     run_test ( 4'b1111 ,  4'b0000 ,    4'b0000 ,    4'b1111 ,   4'b0010, 4'b0001,4'b0000,     '{default:0} ,  '{8,8,8,8}  ,  testlength, 4'b0000, 4'b0000);  
     //with backpressure and valid_drop
     run_test ( 4'b1111 , 4'b0000 ,     4'b0000 ,    4'b1111 ,   4'b0001, 4'b0001,4'b0000,     '{8,8,8,8}   ,  '{8,8,8,8}  ,   testlength, 4'b0000, 4'b0000);  
  
     phase ++ ;
     $display("--------------phase 6--------------");   
     //     traffic_work , dif_size_en , delay_enable ,fixed_dest_en, fixed_dest,            backpressure, valid_drop_rate,test_length ,fixed_header_vc_enable, fixed_header_vc
     //multiple input ,  single size, single type , multiple dest , no backpressure , no validdrop
     run_test ( 4'b1111 ,  4'b0000 ,    4'b0000 ,    4'b0000 ,   4'b0011, 4'b0000,4'b0000,     '{default:0} , '{default:0}  , testlength, 4'b0000, 4'b0000);  
     //with backpressure  
     run_test ( 4'b1111 ,  4'b0000 ,    4'b0000 ,    4'b0000 ,   4'b0011, 4'b0000,4'b0000,     '{8,8,8,8}   , '{default:0}  , testlength, 4'b0000, 4'b0000);  
     //with valid_drop
     run_test ( 4'b1111 ,  4'b0000 ,    4'b0000 ,    4'b0000 ,   4'b0011, 4'b0000,4'b0000,     '{default:0} ,  '{8,8,8,8}   , testlength, 4'b0000, 4'b0000);  
     //with backpressure and valid_drop
     run_test ( 4'b1111 ,  4'b0000 ,    4'b0000 ,    4'b0000 ,   4'b0011, 4'b0000,4'b0000,     '{8,8,8,8}   ,  '{8,8,8,8}   , testlength, 4'b0000, 4'b0000);  
  
     phase ++ ;
     $display("--------------phase 7--------------");   
     //     traffic_work , dif_size_en , delay_enable ,fixed_dest_en, fixed_dest,            backpressure, valid_drop_rate,test_length ,fixed_header_vc_enable, fixed_header_vc
     //multiple input ,  multiple size, single type , single dest , no backpressure , no validdrop
     run_test ( 4'b1111 ,  4'b1111 ,    4'b0000 ,    4'b1111 ,   4'b0000, 4'b0000,4'b0000,    '{default:0} ,  '{default:0}, testlength, 4'b0000, 4'b0000);  
     //with backpressure   
     run_test ( 4'b1111 ,  4'b1111 ,    4'b0000 ,    4'b1111 ,   4'b0011, 4'b0001,4'b0000,    '{8,8,8,8}   ,  '{default:0}, testlength, 4'b0000, 4'b0000);  
     //with valid_drop
     run_test ( 4'b1111  , 4'b1111 ,    4'b0000 ,    4'b1111 ,   4'b0001, 4'b0000,4'b0000,    '{default:0} ,  '{8,8,8,8}  , testlength, 4'b0000, 4'b0000);  
     //with backpressure and valid_drop
     run_test ( 4'b1111  , 4'b1111 ,    4'b0000 ,    4'b1111 ,   4'b0010, 4'b0001,4'b0000,    '{8,8,8,8}   ,  '{8,8,8,8}  , testlength, 4'b0000, 4'b0000);  
  
     phase ++ ;
     $display("--------------phase 8--------------");   
     //     traffic_work , dif_size_en , delay_enable ,fixed_dest_en, fixed_dest,            backpressure, valid_drop_rate,test_length ,fixed_header_vc_enable, fixed_header_vc
     //multiple input, multiple size, multiple type , multiple dest , no backpressure , no validdrop
     run_test ( 4'b1111 ,  4'b1111 ,    4'b0000 ,    4'b0000 ,   4'b0011, 4'b0000,4'b0000,    '{default:0} ,  '{default:0} , testlength, 4'b0000, 4'b0000);  
     //with backpressure  
     run_test ( 4'b1111 ,  4'b1111 ,    4'b0000 ,    4'b0000 ,   4'b0011, 4'b0000,4'b0000,    '{8,8,8,8}   ,  '{default:0} , testlength, 4'b0000, 4'b0000);  
     //with valid_drop
     run_test ( 4'b1111  , 4'b1111 ,    4'b0000 ,    4'b0000 ,   4'b0011, 4'b0000,4'b0000,    '{default:0} ,  '{8,8,8,8}   , testlength, 4'b0000, 4'b0000);  
     //with backpressure and valid_drop
     run_test ( 4'b1111  , 4'b1111 ,    4'b0000 ,    4'b0000 ,   4'b0011, 4'b0000,4'b0000,    '{8,8,8,8}   ,  '{8,8,8,8}   , testlength, 4'b0000, 4'b0000);  
  
     $display("--------------phase 8 with delays--------------");   
     //     traffic_work , dif_size_en , delay_enable ,fixed_dest_en, fixed_dest,            backpressure, valid_drop_rate,test_length ,fixed_header_vc_enable, fixed_header_vc
     //multiple input multiple size, multiple type , multiple dest , no backpressure , no validdrop
     run_test ( 4'b1111 ,  4'b1111 ,   4'b1111 ,     4'b0000 ,   4'b0011, 4'b0000,4'b0000,    '{default:0} , '{default:0}  , testlength, 4'b0000, 4'b0000);  
     //with backpressure  
     run_test ( 4'b1111 ,  4'b1111 ,   4'b1111 ,     4'b0000 ,   4'b0011, 4'b0000,4'b0000,    '{8,8,8,8}   , '{default:0}  , testlength, 4'b0000, 4'b0000);  
     //with valid_drop
     run_test ( 4'b1111  , 4'b1111 ,   4'b1111 ,     4'b0000 ,   4'b0011, 4'b0000,4'b0000,    '{default:0} ,  '{8,8,8,8}   , testlength, 4'b0000, 4'b0000);  
     //with backpressure and valid_drop
     run_test ( 4'b1111  , 4'b1111 ,   4'b1111 ,     4'b0000 ,   4'b0011, 4'b0000,4'b0000,    '{8,8,8,8}   ,  '{8,8,8,8}   , testlength, 4'b0000, 4'b0000);  
  
     phase ++ ;
     
  
     $display("--------------phase 9 with fixed low prio vc--------------");   
     //     traffic_work , dif_size_en , delay_enable ,fixed_dest_en, fixed_dest,            backpressure, valid_drop_rate,test_length ,fixed_header_vc_enable, fixed_header_vc
     //multiple input multiple size, multiple type , multiple dest , no backpressure , no validdrop
     run_test ( 4'b1111 ,  4'b1111 ,   4'b1111 ,     4'b0000 ,   4'b0011, 4'b0000,4'b0000,    '{default:0} , '{default:0}  , testlength, 4'b1111, 4'b0001);  
     //with backpressure  
     run_test ( 4'b1111 ,  4'b1111 ,   4'b1111 ,     4'b0000 ,   4'b0011, 4'b0000,4'b0000,    '{8,8,8,8}   , '{default:0}  , testlength, 4'b1001, 4'b0001);  
    //with valid_drop
     run_test ( 4'b1111  , 4'b1111 ,   4'b1111 ,     4'b0000 ,   4'b0011, 4'b0000,4'b0000,    '{default:0} ,  '{8,8,8,8}   , testlength, 4'b0110, 4'b0001);  
    //with backpressure and valid_drop
     run_test ( 4'b1111  , 4'b1111 ,   4'b1111 ,     4'b0000 ,   4'b0011, 4'b0000,4'b0000,    '{8,8,8,8}   ,  '{8,8,8,8}   , testlength, 4'b0101, 4'b0001);  
          
     
     phase ++ ;    
  
     $display("--------------phase 10 with fixed high prio vc--------------");   
    //     traffic_work , dif_size_en , delay_enable ,fixed_dest_en, fixed_dest,            backpressure, valid_drop_rate,test_length ,fixed_header_vc_enable, fixed_header_vc
     //multiple input multiple size, multiple type , multiple dest , no backpressure , no validdrop
     run_test ( 4'b1111 ,  4'b1111 ,   4'b1111 ,     4'b0000 ,   4'b0011, 4'b0000,4'b0000,    '{default:0} , '{default:0}  , testlength, 4'b1111, 4'b0101);  
     //with backpressure  
     run_test ( 4'b1111 ,  4'b1111 ,   4'b1111 ,     4'b0000 ,   4'b0011, 4'b0000,4'b0000,    '{8,8,8,8}   , '{default:0}  , testlength, 4'b1111, 4'b0101);  
    //with valid_drop
     run_test ( 4'b1111  , 4'b1111 ,   4'b1111 ,     4'b0000 ,   4'b0011, 4'b0000,4'b0000,    '{default:0} ,  '{8,8,8,8}   , testlength, 4'b1111, 4'b0101);  
    //with backpressure and valid_drop
     run_test ( 4'b1111  , 4'b1111 ,   4'b1111 ,     4'b0000 ,   4'b0011, 4'b0000,4'b0000,    '{8,8,8,8}   ,  '{8,8,8,8}   , testlength, 4'b1111, 4'b0101);  
          
     
  */
     
     $display("--------------final phase--------------");   
     for (int i= 0 ; i < 100 ; i ++ ) begin
      
       r5   = $random();
       r16a = $random();//($urandom() % (input_num-1)) + 1;
       r16b = $random();
       r16c = $random();
       r16d = $random();
       rVc  = $urandom() % (vc_num*prio_num);
       
       rDstX = $urandom() % (dimension_x);
       rDstY = $urandom() % (dimension_y);
       rDstZ = $urandom() % (dimension_z);
       $display("--------------another one bytes the dust %d,%d,%d,%d,%d,%d --------------",r5,r16a,r16b,r16c,r16d,rVc); 
        
       
     
       
                            
       run_test ( r16a , r16b , r16c , 10'b0000000000 , rDstX, rDstY,rDstZ, '{r5,r5,r5,r5,r5,r5,r5,r5,r5,r5} , '{r5,r5,r5,r5,r5,r5,r5,r5,r5,r5} , testlength, r16a, rVc);
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
