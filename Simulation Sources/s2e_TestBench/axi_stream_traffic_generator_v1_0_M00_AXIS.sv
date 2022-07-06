`timescale 1 ns / 1 ps
//
import exanet_pkg::*;
import exanet_crosb_pkg::*;
/* 
   This axi stream generator: 
     - generates packets consisted of 18 flits and adds them in a random vc
     - between generation of two packets there is a 6 cycle delay(4 in fsm + 2 in delay)
     - if the random number of vc that was selected, is full, packet is added in the first vc(from 0) that has space to accomodate it
     - all the generated packets are stored in a memory accodring to which vc are destined to. Each vc has its own row in memory with enough space for 3 complete packets(3*18 = 54) 
   */

	module axi_stream_traffic_generator_v1_0_M00_AXIS #
	(
		
        parameter integer NUM_OF_WORDS_WIDTH = 1,
		
		parameter integer C_M_AXIS_TDATA_WIDTH	= 32,
		// Start count is the number of clock cycles the master will wait before initiating/issuing any transaction.
		parameter integer C_M_START_COUNT	= 5,
		
		parameter prio_num               = 2,
        parameter vc_num                 = 2,
        parameter output_num             = 2
	)
	(
		
        input wire enable,
        
        input wire [NUM_OF_WORDS_WIDTH-1:0] num_of_words,
        
        input [prio_num*vc_num-1:0]  i_fifo_full,

		input wire  M_AXIS_ACLK, 
		input wire  M_AXIS_ARESETN,
		
		// output_vc indicates the vc in which the packet is going to be destined
		output [$clog2(vc_num*prio_num)-1:0]          o_output_vc,
		
		AXIS.master                          M_AXIS
	);                                            
	                                                                                           
	                                                                                                                                                                                                        
	// Define the states of state machine                                                
	// The control state machine oversees the writing of input streaming data to the FIFO,
	// and outputs the streaming data from the FIFO                                      
	parameter [1:0] IDLE = 2'b00,        // This is the initial/idle state               
	                                                                                     
	                INIT_COUNTER  = 2'b01, // This state initializes the counter, once   
	                                // the counter reaches C_M_START_COUNT count,        
	                                // the state machine changes state to SEND_STREAM     
	                SEND_STREAM   = 2'b10; // In this state the                          
	                                     // stream data is output through M_AXIS_TDATA   
	// State variable                                                                    
	reg [1:0] mst_exec_state;                                                            
	// Example design FIFO read pointer                                                  
	reg [NUM_OF_WORDS_WIDTH-1:0] read_pointer;                                                      

	// AXI Stream internal signals
	//wait counter. The master waits for the user defined number of clock cycles before initiating a transfer.
	
	reg [10:0] count;//it was  reg [WAIT_COUNT_BITS-1 : 0] 	count;
	reg [10:0] delay;
	//streaming data valid
	wire  	axis_tvalid;
	//streaming data valid delayed by one clock cycle
	reg  	axis_tvalid_delay;
	//Last of the streaming data 
	wire  	axis_tlast;
	//Last of the streaming data delayed by one clock cycle
	reg  	axis_tlast_delay;
	//FIFO implementation signals
	reg [C_M_AXIS_TDATA_WIDTH-1 : 0] 	stream_data_out;
	reg [C_M_AXIS_TDATA_WIDTH-1 : 0] 	stream_data_out_q;
	reg [4:0]                           tdest;
	wire  	tx_en;
	//The master has issued all the streaming data stored in FIFO
	wire  	tx_done;
	
	
	
    reg [31:0]                         rand_32            = 0;
    reg [31:0]                         rand_32_header     = 0;
    reg [4:0]                          rand_dest          = 0;
    reg [$clog2(vc_num*prio_num)-1:0]  rand_output_vc     = 0; 
    reg [$clog2(vc_num*prio_num)-1:0]  output_vc_q;
    reg [127:0]                        MEM [vc_num*prio_num - 1:0][54] ; // 1152 packets storage. 
    
    reg [31:0]                         mem_pointer[vc_num*prio_num - 1:0]          = '{'{0},/*'{0},'{0},*/'{0},'{0},'{0}};
    reg [31:0]                         mem_pointer_q[vc_num*prio_num - 1:0]        = '{'{0},/*'{0},'{0},*/'{0},'{0},'{0}};
    reg                                axis_tvalid_q;
    
  
    always @(posedge M_AXIS_ACLK) begin
      rand_32           <= $random();
      rand_output_vc    <= $urandom() % vc_num*prio_num;
      rand_dest         <= $urandom() % output_num;
      if(read_pointer == num_of_words - 2)
         rand_32_header    <= $random();
      
    end  
	// I/O Connections assignments

	assign M_AXIS.TVALID = axis_tvalid_delay;
	assign M_AXIS.TDATA	 = stream_data_out;
	assign M_AXIS.TLAST	 = axis_tlast_delay;
	//assign M_AXIS.TDEST  = tdest;
	

	// Control state machine implementation                             
	always @(posedge M_AXIS_ACLK) begin                                            
	                                                                     
	  if (!M_AXIS_ARESETN) begin                                                   
	  // Synchronous reset (active low)                                                                                                      
	    mst_exec_state <= IDLE;                                             
	    count    <= 0;                                                      
	  end                                                                   
	  else                                                                    
	    case (mst_exec_state)                                                 
	      IDLE:                                                                 
	        mst_exec_state  <= INIT_COUNTER; // INIT_COUNTER;  
                                                                  
	      INIT_COUNTER:  begin                                                                                    
	        if ( count == 1/*it was 4*/ )begin                                                                                        
	          mst_exec_state  <= SEND_STREAM;                               
	        end                                                             
	        else begin                                                                                                                         
	          count <= count + 1;                                           
	          mst_exec_state  <= INIT_COUNTER;                              
	        end                                                             
	      end                                                                  
	      SEND_STREAM:begin
	        count <= 0;                                           	                          
	        if (tx_done) begin                                                                                                                          
	          mst_exec_state <= IDLE;                                       
	        end                                                             
	        else  begin                                                                                                                                 
	          mst_exec_state <= SEND_STREAM;                                
	        end    
	      end                                                         
	    endcase                                                               
	end                                                                       

	
	assign axis_tvalid = (mst_exec_state == SEND_STREAM) && enable;
	                                                                                                                                                         
	assign axis_tlast  = (read_pointer == num_of_words-2);                                
	                                                                                                                                                                                           
	// Delay the axis_tvalid and axis_tlast signal by one clock cycle                              
	// to match the latency of M_AXIS_TDATA                                                        
	always @(posedge M_AXIS_ACLK) begin                                                                                                                                                    
	  if (!M_AXIS_ARESETN)begin                                                                                                                                                                 
	    axis_tvalid_delay  <= 1'b0;                                                               
	    axis_tlast_delay   <= 1'b0; 
	    stream_data_out_q  <= stream_data_out;
	    mem_pointer_q      <= mem_pointer;                                                               
	  end                                                                                        
	  else  begin                                                                                       
	    stream_data_out_q  <= stream_data_out;                                                                                     
	    axis_tvalid_delay  <= axis_tvalid;                                                        
	    axis_tlast_delay   <= axis_tlast;  
	    mem_pointer_q      <= mem_pointer;    
	    axis_tvalid_q      <= M_AXIS.TVALID;                                                  
	  end                                                                                        
	end                                                                                            

	
	
	assign tx_done = !enable | (read_pointer == num_of_words-2); 
	

	always@(posedge M_AXIS_ACLK) begin                                                                                                                    
	  if(!M_AXIS_ARESETN)begin                                                            
	                                                                            
	    read_pointer <= 0;                                                         
	                                                                 
	  end                                                                          
	  else  begin 
	  
	    if(M_AXIS.TVALID)begin
	      if(mem_pointer[output_vc_q] == 53)begin
	        mem_pointer[output_vc_q] <= 0;
	      end
	      else
	        mem_pointer[output_vc_q] <= mem_pointer[output_vc_q] + 1;
	      
	    end
	                                                                                                                                       
	    if (read_pointer < num_of_words - 1 && mst_exec_state == SEND_STREAM )begin                              
	                                                                            
	      if (tx_en)  begin                                                                                                                                                                  
	        read_pointer <= read_pointer + 1;   
	      end  
	    end                                                                      
	    else if (read_pointer == (num_of_words -1) && mst_exec_state == SEND_STREAM) begin                           
	                                                                            
	      read_pointer <= 0;                                                       
	    end
	        
	  end //end of else of reset                                                                   
	end //end of always                                                                             
 
	assign tx_en = M_AXIS.TREADY && axis_tvalid_delay;//axis_tvalid; 
	
	//in case that rand_output_vc is full find the first non full vc 
	genvar i;
	logic [prio_num*vc_num-1:0]non_zero;
	logic [$clog2(vc_num*prio_num)-1:0]non_zero_binary;
	assign non_zero = (i_fifo_full != 0) ? ~i_fifo_full & ~(~i_fifo_full - 1) : 0;//the first place-vc that i_fifo_full is 0, will be the only place that non_zero will be 1
	//find the binary number of vc that is not full 
	 ss_1h_to_b #(
       .input_width(prio_num*vc_num)
      ) ss_go_to_sel (
       .i_in(non_zero),
       .o_out(non_zero_binary)
     );
	
	assign o_output_vc = output_vc_q;                                        
	    // Streaming output data is read from FIFO       
	always @( posedge M_AXIS_ACLK )begin                  
	                                                
      if(!M_AXIS_ARESETN) begin                           
	                                                
	    stream_data_out <= {32'hAAAAAAAA,32'h0,rand_32,32'hAAAAAAAA};  
	    output_vc_q     <= rand_output_vc;  
	    delay           <= 0;     
	    tdest           <= rand_dest;             
	  end                                          
	  else if (tx_en | (delay != 0)/*&&  count == 2*/)begin    
	    if (read_pointer == num_of_words -1)begin                                            
	      stream_data_out <= {32'hAAAAAAAA,32'h0,rand_32_header,32'hAAAAAAAA};  
	      tdest           <= rand_dest;
	      if(delay == 2)begin// this delay let us choose the correct vc and avoid the case that the selected vc, is going full one cycle later
	        delay <= 0;
	        if(i_fifo_full[rand_output_vc])
	          output_vc_q <= non_zero_binary;
	        else 
	          output_vc_q     <= rand_output_vc;
	      end
	      else 
           delay <= delay + 1;                   
	    end
	    else if(read_pointer == num_of_words - 2)begin 
	      stream_data_out <= 32'b0;
	      tdest           <= 0;
	      delay           <= 0;        
	    end
	    else begin
          tdest           <= 0;
	      stream_data_out <= {32'hDEAD_BEEF,rand_32,rand_32,32'hDEAD_BEEF};
	    end
	    
	    if(M_AXIS.TVALID)
	      MEM[output_vc_q][mem_pointer[output_vc_q]] <= stream_data_out;
	    
	   // MEM[mem_pointer] <= stream_data_out;
	    
	  end                                          
	end                                             

endmodule