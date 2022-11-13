`timescale 1ns/1ns

module ss_out_rr #(
	 parameter input_num 	= 8
)(
	input				          clk,
	input				          resetn,
	input  [input_num-1 : 0] 	  i_request,		
	output  [input_num-1 :0]   	  o_out,

	input                         go

);


	reg  [input_num-1 : 0] 	masked_grant_vector = 0	;
	reg  [input_num-1 : 0] 	grant_vector	    = 0	;
	wire  [input_num-1 : 0] masked_grant_vector_d	;
	wire  [input_num-1 : 0] grant_vector_d		;
	wire  [input_num-1 : 0] grant_vector_dd		;

	wire [input_num-1 : 0] 	masked_request_vector ; 
	logic [input_num-1 : 0] 	unmasked_request_vector ; 
	
	
	
	
	
	wire [input_num-1 : 0]    reuse_grant;
	
	wire [input_num-1 : 0]    unmasked_request_or_masked_grant;
	logic condition1 = 0;
	logic condition2 = 0;
	
	

	


	wire 			          mux_sel;
	wire			          has_d;
	
	logic  [input_num-1 : 0]  masked_grant_vector_2;//it is used in case that the selected vc/input was not granted

    
	assign unmasked_request_vector 	= i_request;
	
	assign masked_request_vector	= unmasked_request_vector & masked_grant_vector ;
	assign mux_sel 			        = (masked_request_vector == 0);
	assign grant_vector_d 		    = (mux_sel) ? unmasked_request_vector : masked_request_vector ;
	/* CHANGING THE FOLLOWING LINE, RR GRANTS IN THE SAME CYCLE THAT GO SIGNAL IS ASSERTED*/
	//assign o_out                  = (go) ? grant_vector_dd : 0;//grant_vector ;
	assign o_out                  = grant_vector_dd;

	

	generate
	if (input_num <= 2) begin
		assign masked_grant_vector_d = 	grant_vector_d[0] ? 2'b10 :
                     				    grant_vector_d[1] ? 2'b00 : 2'b00;
	end

	else if (input_num <= 4) begin
		assign masked_grant_vector_d = 	grant_vector_d[0] ? 4'b1110 :
                                        grant_vector_d[1] ? 4'b1100 : 
                                        grant_vector_d[2] ? 4'b1000 : 
                                        grant_vector_d[3] ? 4'b0000 : 4'b0000;
	end

	else if (input_num <= 8) begin
		assign masked_grant_vector_d = 	grant_vector_d[0] ? 8'b11111110 :
                                        grant_vector_d[1] ? 8'b11111100 : 
                                        grant_vector_d[2] ? 8'b11111000 : 
                                        grant_vector_d[3] ? 8'b11110000 :
                                        grant_vector_d[4] ? 8'b11100000 : 
                                        grant_vector_d[5] ? 8'b11000000 :
                                        grant_vector_d[6] ? 8'b10000000 : 
                                        grant_vector_d[7] ? 8'b00000000: 8'b00000000;
	end

	else if (input_num <= 16) begin
		assign masked_grant_vector_d = 	grant_vector_d[0]  ? 16'b1111111111111110 :
                                        grant_vector_d[1]  ? 16'b1111111111111100 : 
                                        grant_vector_d[2]  ? 16'b1111111111111000 : 
                                        grant_vector_d[3]  ? 16'b1111111111110000 :
                                        grant_vector_d[4]  ? 16'b1111111111100000 : 
                                        grant_vector_d[5]  ? 16'b1111111111000000 :
                                        grant_vector_d[6]  ? 16'b1111111110000000 :
                                        grant_vector_d[7]  ? 16'b1111111100000000 :
                                        grant_vector_d[8]  ? 16'b1111111000000000 : 
                                        grant_vector_d[9]  ? 16'b1111110000000000 : 
                                        grant_vector_d[10] ? 16'b1111100000000000 :
                                        grant_vector_d[11] ? 16'b1111000000000000 : 
                                        grant_vector_d[12] ? 16'b1110000000000000 :
                                        grant_vector_d[13] ? 16'b1100000000000000 :  
                                        grant_vector_d[14] ? 16'b1000000000000000 :
                                        grant_vector_d[15] ? 16'b0000000000000000: 16'b0000000000000000;
	end

	endgenerate
	assign has_d = (grant_vector_d != 0);

	always @(posedge clk) begin
		if (~resetn)begin 
		  masked_grant_vector <=  0 ;
		 
	    end
		else begin
		  if (go)  masked_grant_vector <=  masked_grant_vector_d;
	    end
	end


	/*generate the output Prio Enforcer */
	
 	generate
	if (input_num <= 2) begin
		assign grant_vector_dd = 	grant_vector_d[0] ? 2'b01 :
                     				grant_vector_d[1] ? 2'b10 : 2'b00;
	end

	else if (input_num <= 4) begin
		assign grant_vector_dd = 	grant_vector_d[0] ? 4'b0001 :
                     				grant_vector_d[1] ? 4'b0010 : 
						            grant_vector_d[2] ? 4'b0100 : 
						            grant_vector_d[3] ? 4'b1000 : 4'b0000;
	end

	else if (input_num <= 8) begin
		assign grant_vector_dd = 	grant_vector_d[0] ? 8'b00000001 :
                     				grant_vector_d[1] ? 8'b00000010 : 
						            grant_vector_d[2] ? 8'b00000100 : 
						            grant_vector_d[3] ? 8'b00001000 :
                     				grant_vector_d[4] ? 8'b00010000 : 
						            grant_vector_d[5] ? 8'b00100000 :
			 			            grant_vector_d[6] ? 8'b01000000 : 
						            grant_vector_d[7] ? 8'b10000000: 8'b00000000;
	end

	else if (input_num <= 16) begin
		assign grant_vector_dd = 	grant_vector_d[0]  ? 16'b0000000000000001 :
                     				grant_vector_d[1]  ? 16'b0000000000000010 : 
						            grant_vector_d[2]  ? 16'b0000000000000100 : 
						            grant_vector_d[3]  ? 16'b0000000000001000 :
                     				grant_vector_d[4]  ? 16'b0000000000010000 : 
						            grant_vector_d[5]  ? 16'b0000000000100000 :
			 			            grant_vector_d[6]  ? 16'b0000000001000000 :
						            grant_vector_d[7]  ? 16'b0000000010000000 :
                     				grant_vector_d[8]  ? 16'b0000000100000000 : 
						            grant_vector_d[9]  ? 16'b0000001000000000 : 
						            grant_vector_d[10] ? 16'b0000010000000000 :
                     				grant_vector_d[11] ? 16'b0000100000000000 : 
						            grant_vector_d[12] ? 16'b0001000000000000 :
			 			            grant_vector_d[13] ? 16'b0010000000000000 :  
						            grant_vector_d[14] ? 16'b0100000000000000 :
						            grant_vector_d[15] ? 16'b1000000000000000: 16'b0000000000000000;
	end

	endgenerate



endmodule

