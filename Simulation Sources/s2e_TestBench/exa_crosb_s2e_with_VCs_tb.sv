`timescale 1ns / 1ps

module exa_crosb_s2e_with_VCs_tb();

  parameter integer C_S00_AXI_DATA_WIDTH	= 32;
  parameter integer C_S00_AXI_ADDR_WIDTH	= 4;
  localparam prio_num   = 2;
  localparam vc_num     = 2;

// Parameters of Axi Master Bus Interface M00_AXIS
  parameter integer C_M00_AXIS_TDATA_WIDTH	= 128;
  parameter integer C_M00_AXIS_START_COUNT	= 1;
  parameter integer NUM_OF_WORDS_WIDTH      = 128;

  reg                                  m00_axis_aclk;
  reg                                  m00_axis_aresetn;
  reg                                  enable_w;
  reg [NUM_OF_WORDS_WIDTH-1:0]         num_of_words_w;
  reg [$clog2(vc_num*prio_num)-1 :0]   rand_vc   = 0;
  
  AXIS                                 s_axis(); 
  exanet                               m_exanet_tx();
  
  logic [prio_num*vc_num-1 : 0]        fifo_full;
  logic [$clog2(vc_num*prio_num)-1:0]  output_vc_i;
  logic [4:0]                          backpressure;
  
  
  // Instantiation of Axi Bus Interface M00_AXIS
	axi_stream_traffic_generator_v1_0_M00_AXIS # (
	    .NUM_OF_WORDS_WIDTH(NUM_OF_WORDS_WIDTH),
		.C_M_AXIS_TDATA_WIDTH(C_M00_AXIS_TDATA_WIDTH),
		.C_M_START_COUNT(C_M00_AXIS_START_COUNT)
	) axi_stream_traffic_generator_v1_0_M00_AXIS_inst (
	    .enable(enable_w),
	    .num_of_words(num_of_words_w), 
		.M_AXIS_ACLK(m00_axis_aclk),
		.M_AXIS_ARESETN(m00_axis_aresetn),
		.o_output_vc(output_vc_i),
		.i_fifo_full(fifo_full),
		.M_AXIS(s_axis)
	);
	
 exa_crosb_s2e_with_VCs #(
         .prio_num(prio_num),
         .vc_num(vc_num),
         .output_num(4), // maybe useless
         .input_num(4), // maybe useless 
         .out_fifo_depth(72)// it was 40
    )s2e_with_VCs (
        
         .S_ACLK(m00_axis_aclk),
         .S_ARESETN(m00_axis_aresetn),
         .i_output_vc(output_vc_i),
         .o_fifo_full(fifo_full),
         .S_AXIS(s_axis),
        
        // ExaNet IF
         .exanet_tx(m_exanet_tx)
    );
    
    
   exa_traffic_consumer_with_VCs #(
       .prio_num(prio_num),
       .vc_num(vc_num)
   
   )exa_traffic_consumer_with_VCs(
       .clk(m00_axis_aclk),
       .resetn(m00_axis_aresetn),
       .i_backpressure(backpressure),
 
       .exa(m_exanet_tx)
     
     
   
   );
	

  /*  
  task output_vcer(input fixed_vc_enable, input[$clog2(prio_num*vc_num)-1 :0] fixed_vc, input initialize);begin
    if(initialize) begin
     
   end
   else begin
     if(fixed_vc_enable)begin
       output_vc_i = fixed_vc; 
       
     end
     else begin
       rand_vc     = $urandom() % (prio_num*vc_num);
       output_vc_i = rand_vc;
       
     end  
   end    
  end 
  endtask

*/

initial begin
          m00_axis_aclk = 0;
          forever begin
            #5 m00_axis_aclk = ~m00_axis_aclk;
          end
  end
    
  initial begin
          m00_axis_aresetn = 0;
          /*
          m_exanet_tx.header_ready  = 0;
          m_exanet_tx.payload_ready = 0;
          m_exanet_tx.footer_ready  = 0;
          */
          #25 m00_axis_aresetn = 1;
          //#995//#295
          /*
          m_exanet_tx.header_ready  = 1;
          m_exanet_tx.payload_ready = 1;
          m_exanet_tx.footer_ready  = 1;
          */
          /*
          #700
          m_exanet_tx.header_ready  = 0;
          m_exanet_tx.payload_ready = 0;
          m_exanet_tx.footer_ready  = 0;*/
         
          
  end

  // Enable, disable and re-enable output stream using tready
  initial begin
            s_axis.TREADY = 0;//m00_axis_tready = 0;
            enable_w = 1;
            num_of_words_w = 18;
            backpressure = 5'b01000;// ****** CHANGING THIS TO 10000, PROBLEM STARTS*****
            #40 s_axis.TREADY = 1; // ****** THIS SHOULD BE DRIVEN BY exa_crosb_s2e_with_VCs ***********
            //#550 m00_axis_tready = 0;
            //#40 m00_axis_tready = 1;
  end
  
  always_ff @(posedge m00_axis_aclk) begin 
    if(fifo_full == (2**(prio_num*vc_num) - 1)) begin // check if fifo_full == 1111(** = ^)
      $fatal("All fifos are full on s2e"); 
    end
     
      
  end
  /*
  always begin 
  
    while(!m00_axis_tlast)begin
      @(posedge m00_axis_aclk);
    end
       enable_w = 0;
      @(posedge m00_axis_aclk);
      @(posedge m00_axis_aclk);
      @(posedge m00_axis_aclk);
      enable_w = 1;
    
  end
  */
  
  
  
  /*
  initial begin
     output_vcer(1,0,0);
    forever begin
      #5
      if(m00_axis_tlast)begin
        enable_w = 0;
        #10
        enable_w = 1;
        output_vcer(1,2,0);
        while (fifo_full[output_vc_i] == 1)begin
          output_vcer(0,1,0);// fixed_vc == 0, so random vc will be selected
        end
      end
      else begin 
        @(negedge m00_axis_aclk);
      end
      
    end  
  end
 */
 
endmodule
