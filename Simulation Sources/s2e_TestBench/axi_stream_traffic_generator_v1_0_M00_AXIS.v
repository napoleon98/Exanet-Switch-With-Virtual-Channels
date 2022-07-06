`timescale 1 ns / 1 ps

	module axi_stream_traffic_generator_v1_0_M00_AXIS #
	(
		// Users to add parameters here
        	parameter integer NUM_OF_WORDS_WIDTH = 1,
		// User parameters ends
		// Do not modify the parameters beyond this line

		// Width of S_AXIS address bus. The slave accepts the read and write addresses of width C_M_AXIS_TDATA_WIDTH.
		parameter integer C_M_AXIS_TDATA_WIDTH	= 32,
		// Start count is the number of clock cycles the master will wait before initiating/issuing any transaction.
		parameter integer C_M_START_COUNT	= 5,
		
		parameter prio_num               = 2,
        parameter vc_num                 = 2
	)
	(
		// Users to add ports here
        input wire enable,
        input wire [NUM_OF_WORDS_WIDTH-1:0] num_of_words,
        input [prio_num*vc_num-1:0]  i_fifo_full,
        input wire  M_AXIS_TREADY,
		// User ports ends
		// Do not modify the ports beyond this line

		// Global ports
		input wire  M_AXIS_ACLK,
		// 
		input wire  M_AXIS_ARESETN,
		// Master Stream Ports. TVALID indicates that the master is driving a valid transfer, A transfer takes place when both TVALID and TREADY are asserted. 
		output wire  M_AXIS_TVALID,
		// TDATA is the primary payload that is used to provide the data that is passing across the interface from the master.
		output wire [C_M_AXIS_TDATA_WIDTH-1 : 0] M_AXIS_TDATA,
		// TSTRB is the byte qualifier that indicates whether the content of the associated byte of TDATA is processed as a data byte or a position byte.
		output wire [(C_M_AXIS_TDATA_WIDTH/8)-1 : 0] M_AXIS_TSTRB,
		// TLAST indicates the boundary of a packet.
		output wire  M_AXIS_TLAST,
		// output_vc indicates the vc in which the packet is going to be destined
		output [$clog2(vc_num*prio_num)-1:0]          o_output_vc
		// TREADY indicates that the slave can accept a transfer in the current cycle.
		
		
	);                                            
	                                                                                     
	// function called clogb2 that returns an integer which has the                      
	// value of the ceiling of the log base 2.                                           
	function integer clogb2 (input integer bit_depth);                                   
	  begin                                                                              
	    for(clogb2=0; bit_depth>0; clogb2=clogb2+1)                                      
	      bit_depth = bit_depth >> 1;                                                    
	  end                                                                                
	endfunction                                                                         
	                                                                                     
	// WAIT_COUNT_BITS is the width of the wait counter.                                 
	localparam integer WAIT_COUNT_BITS = clogb2(C_M_START_COUNT-1);                      
	                                                                                                                                                                                                        
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
	wire  	tx_en;
	//The master has issued all the streaming data stored in FIFO
	wire  	tx_done;
	
	
	
    reg [31:0] rand_32                                    = 0;
    reg [$clog2(vc_num*prio_num)-1:0]  rand_output_vc     = 0; 
    reg [$clog2(vc_num*prio_num)-1:0]  output_vc_q;
    reg [9:0]  n;// for loop
  
      always @(posedge M_AXIS_ACLK) begin
        rand_32           <= $random();
        rand_output_vc    <= $random();
        /*
        while(i_fifo_full[rand_output_vc])begin
          rand_output_vc    <= $random();
        end
        */
      end  
	// I/O Connections assignments

	assign M_AXIS_TVALID	= axis_tvalid_delay;
	assign M_AXIS_TDATA	= stream_data_out;
	assign M_AXIS_TLAST	= axis_tlast_delay;
	assign M_AXIS_TSTRB	= {(C_M_AXIS_TDATA_WIDTH/8){1'b1}};

	// Control state machine implementation                             
	always @(posedge M_AXIS_ACLK)                                             
	begin                                                                     
	  if (!M_AXIS_ARESETN)                                                    
	  // Synchronous reset (active low)                                       
	    begin                                                                 
	      mst_exec_state <= IDLE;                                             
	      count    <= 0;                                                      
	    end                                                                   
	  else                                                                    
	    case (mst_exec_state)                                                 
	      IDLE:                                                               
	        // The slave starts accepting tdata when                          
	        // there tvalid is asserted to mark the                           
	        // presence of valid streaming data                               
	        //if ( count == 0 )                                                 
	        //  begin                                                           
	          // mst_exec_state  <= SEND_STREAM; // INIT_COUNTER;  
	            
	           mst_exec_state  <= INIT_COUNTER; // INIT_COUNTER;  
	                                        
	        //  end                                                             
	        //else                                                              
	        //  begin                                                           
	        //    mst_exec_state  <= IDLE;                                      
	        //  end                                                             
	                                                                          
	      INIT_COUNTER:  begin                                                     
	        // The slave starts accepting tdata when                          
	        // there tvalid is asserted to mark the                           
	        // presence of valid streaming data                               
	        if ( count == 2 )                               
	          begin                                                           
	            mst_exec_state  <= SEND_STREAM;                               
	          end                                                             
	        else                                                              
	          begin                                                           
	            count <= count + 1;                                           
	            mst_exec_state  <= INIT_COUNTER;                              
	          end                                                             
	      end                                                                  
	      SEND_STREAM:begin
	         count <= 0;                                           
	        // The example design streaming master functionality starts       
	        // when the master drives output tdata from the FIFO and the slave
	        // has finished storing the S_AXIS_TDATA                          
	        if (tx_done)                                                      
	          begin                                                           
	            mst_exec_state <= IDLE;                                       
	          end                                                             
	        else                                                              
	          begin                                                           
	            mst_exec_state <= SEND_STREAM;                                
	          end    
	      end                                                         
	    endcase                                                               
	end                                                                       

	//tvalid generation
	//axis_tvalid is asserted when the control state machine's state is SEND_STREAM and
	//number of output streaming data is less than the NUMBER_OF_OUTPUT_WORDS.
	assign axis_tvalid = (mst_exec_state == SEND_STREAM) && enable;
	                                                                                               
	// AXI tlast generation                                                                        
	// axis_tlast is asserted number of output streaming data is NUMBER_OF_OUTPUT_WORDS-1          
	// (0 to NUMBER_OF_OUTPUT_WORDS-1)                                                             
	assign axis_tlast = (read_pointer == num_of_words-2);                                
	                                                                                                                                                                                           
	// Delay the axis_tvalid and axis_tlast signal by one clock cycle                              
	// to match the latency of M_AXIS_TDATA                                                        
	always @(posedge M_AXIS_ACLK)                                                                  
	begin                                                                                          
	  if (!M_AXIS_ARESETN)                                                                         
	    begin                                                                                      
	      axis_tvalid_delay <= 1'b0;                                                               
	      axis_tlast_delay <= 1'b0;                                                                
	    end                                                                                        
	  else                                                                                         
	    begin                                                                                      
	      axis_tvalid_delay <= axis_tvalid;                                                        
	      axis_tlast_delay <= axis_tlast;                                                          
	    end                                                                                        
	end                                                                                            

	//read_pointer pointer
	//assign tx_done = !enable;
	assign tx_done = !enable | (read_pointer == num_of_words-2); 
	

	always@(posedge M_AXIS_ACLK)                                               
	begin                                                                            
	  if(!M_AXIS_ARESETN)                                                            
	    begin                                                                        
	      read_pointer <= 0;                                                         
	      //tx_done <= 1'b0;                                                           
	    end                                                                          
	  else                                                                           
	    //if (read_pointer < num_of_words - 1)
	      if (read_pointer < num_of_words - 1 && mst_exec_state == SEND_STREAM )                              
	      begin                                                                      
	        if (tx_en)                                                                                                
	          begin                                                                  
	            read_pointer <= read_pointer + 1;                                                                                        
	          end                                                                    
	      end                                                                        
	    else if (read_pointer == (num_of_words -1) && mst_exec_state == SEND_STREAM)//                             
	      begin                                                                      
	           read_pointer <= 0;                                                       
	      end                                                                        
	end                                                                              

	assign tx_en = M_AXIS_TREADY && axis_tvalid_delay;//axis_tvalid; 
	
	genvar i;
	logic non_zero = 0;
	generate 
	  for(i=0;i<prio_num*vc_num;i=i+1)begin
	    if(i_fifo_full[i] !=0)begin
	      
	    end
	  end
	endgenerate
	
       
	     
	
	assign o_output_vc = output_vc_q;                                        
	    // Streaming output data is read from FIFO       
	    always @( posedge M_AXIS_ACLK )                  
	    begin                                            
	      if(!M_AXIS_ARESETN)                            
	        begin                                        
	          stream_data_out <= 32'hAAAAAAA;  
	          output_vc_q     <= rand_output_vc;                    
	        end                                          
	      else if (tx_en &&  count == 2)// && M_AXIS_TSTRB[byte_index]  
	        begin
	          if (read_pointer == num_of_words -1)
	          begin                                        
	               stream_data_out <= 32'hAAAAAAA;
	               output_vc_q     <= rand_output_vc;
	               /*
	               if(i_fifo_full[rand_output_vc])begin
	                 if(!i_fifo_full[0])
	                   output_vc_q <= 0;
	                 else begin
	                  if(!i_fifo_full[1])
                        output_vc_q <= 1;
                        else begin
                          if(!i_fifo_full[2])
                            output_vc_q <= 2;
                        end
	                 end
	               end
	               else begin
	                 output_vc_q     <= rand_output_vc;
	               end
	               */
	          end
	          else if(read_pointer == num_of_words - 2)
	            begin
	              stream_data_out <= 32'b0;
	              
	            end
	            /*
	          else if(read_pointer == 0 )
	            begin
	              stream_data_out <= 32'hAAAAAAA;
	            end
	            */
	          else
	          begin
	              // stream_data_out <= read_pointer + 32'b1;
	              stream_data_out <= {32'hDEAD_BEEF,rand_32,rand_32,32'hDEAD_BEEF};
	          end   
	        end                                          
	    end                                             

endmodule