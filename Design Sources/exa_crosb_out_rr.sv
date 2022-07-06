`timescale 1ns/1ns

module ss_out_rr #(
	 parameter input_num 	= 8
)(
	input				          clk,
	input				          resetn,
	input  [input_num-1 : 0] 	  i_request,		
	output  [input_num-1 :0]   	  o_out,
	output				          o_has,
	input                         go
	//input                         in_arbiter
	//input                         grant_from_output_arbiter // This input is used from input arbiter module, in order to indicate that its request was granted, so the next masks can change.
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
	
	
	//assign unmasked_request_or_masked_grant =  unmasked_request_vector | masked_grant_vector ; 
	//assign reuse_grant =   grant_vector_dd & i_request; //it helps to check if a previous grant could be used nov..we check if current request has 1, in position that was granted before

	


	wire 			          mux_sel;
	wire			          has_d;
	reg			              has_q;
	
	logic  [input_num-1 : 0]  masked_grant_vector_2;//it is used in case that the selected vc/input was not granted

    //assign unmasked_request_vector  = (go) ? i_request : unmasked_request_vector_q;//letting unmasked_request to be i_request all the time, there was problem with changes in masked_request
	assign unmasked_request_vector 	= i_request;
	/*if previous selected vc/input was not granted and go is asserted, use masked_grant_vector_2, else use masked_grant_vector */
	//assign masked_request_vector	= (go & !grant_from_output_arbiter_q) ? (unmasked_request_vector & masked_grant_vector_2)  : (unmasked_request_vector & masked_grant_vector) ; /*(go) ? unmasked_request_vector & masked_grant_vector : ((grant_from_output_arbiter & !drop_grant_from_output_arbiter_q) ? unmasked_request_vector & masked_grant_vector : masked_request_vector); *///unmasked_request_vector & masked_grant_vector ;
	assign masked_request_vector	= unmasked_request_vector & masked_grant_vector ;
	assign mux_sel 			        = (masked_request_vector == 0);
	assign grant_vector_d 		    = (mux_sel) ? unmasked_request_vector : masked_request_vector ;
	/* CHANGING THE FOLLOWING LINE, RR GRANTS IN THE SAME CYCLE THAT GO SIGNAL IS ASSERTED*/
	//assign o_out                  = (go) ? grant_vector_dd : 0;//grant_vector ;
	assign o_out                  = grant_vector_dd;
	assign o_has	                = has_q;
	
	/*if previous selected vc/input was not granted and go is asserted, check if a new request was generated and cannot be granted by masked_grant_vector*/
	/*
	always_comb begin
	  if(!grant_from_output_arbiter_q & go)begin*/
	  /*if this condition is true, it means that there is a request in a position that current masked_grant_vector cannot  be used to grant it
	    This position is surely lower than the previous granted, so new masked_grant_vector_2 is 0, letting this req to be granted immediately*/
	 /*   if(unmasked_request_or_masked_grant > masked_grant_vector)
	      masked_grant_vector_2 = 0;
	    else
	      masked_grant_vector_2 = masked_grant_vector;
	  end
	  else
	     masked_grant_vector_2 = masked_grant_vector;
	end

	always @(posedge clk) begin
		if (~resetn) 
			grant_vector <=  0 ;
		else
		      if (go) grant_vector <=  grant_vector_dd;
	end

	always @(posedge clk) begin
		if (~resetn) 
			has_q <=  0 ;
		else
			if (go)  has_q <=  has_d;
			else     has_q <=  0;
	end
*/
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
		/*
		  if(in_arbiter)begin // the following code is related only with round robin in input and output arbiter
		    if(go)begin
		      first_go    <= 0;
		      
		    end
		    //if(!first_go & ((go & !grant_from_output_arbiter_q) | (go & !grant_from_output_arbiter_q & (reuse_grant != 0))))
		      unmasked_request_vector_q <= unmasked_request_vector;
		 */ /*
		    if(grant_from_output_arbiter)
		      grant_from_output_arbiter_q <= grant_from_output_arbiter;
		    if(go)
		      grant_from_output_arbiter_q <= 0; 
		      
		    if(go)
		      unmasked_request_vector_q <= unmasked_request_vector;
		  

		    grant_from_output_arbiter_qq <= grant_from_output_arbiter_q;*/
		  /*Don't change masked_grant_vector, unless grant from output arbiter comes*/
		  //drop_grant_from_output_arbiter_q <= grant_from_output_arbiter;
	        /*if(grant_from_output_arbiter & !drop_grant_from_output_arbiter_q)  masked_grant_vector <=  masked_grant_vector_d;
	      end// end of if (in arbiter)
	      else
	        if (go)  masked_grant_vector <=  masked_grant_vector_d;
	        */
	        /*
	      if (grant_from_output_arbiter_q & !grant_from_output_arbiter_qq)  
	        masked_grant_vector <=  masked_grant_vector_d;  
	      */
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

	//assign unmasked_request_vector 	= go ? i_request : i_request_q;//(first_go | (go & grant_from_output_arbiter_q)) ? i_request : (((go & (grant_vector_dd & i_request)) != 0) ? i_request_q : i_request);//i_request;
	/*
	always_comb begin
	  if(in_arbiter)begin // the following code is related only with round robin in input and output arbiter
	    if(first_go | (go & grant_from_output_arbiter_q))begin//if is the first go or our request has been granted, change your request to current one
	      unmasked_request_vector = i_request;
	      condition1 = 1;
	    end
	    else begin // if it is not the first go and the next go has come, while the previous request has not been granted..
	      if(go & (reuse_grant == 0))begin
	        //.. check if the previous grant could be used now..
	         unmasked_request_vector = i_request;//********UNCOMMENT******* i_request_q;//if the grant cannot be used, change your request, so you can grant a new request..
	         condition2 = 1;
    	  end
	      else begin
	        unmasked_request_vector = unmasked_request_vector;//******** UNCOMMENT******
	        condition2 = 0;
	        condition1 = 0;
	      end
	      //unmasked_request_vector = unmasked_request_vector;
	    end// end of else of if(first_go | (go & grant_from_output_arbiter_q))
      end// end of if(in_arbiter)
      else
        unmasked_request_vector = i_request;
	end*/
	/*
	logic condition_3;
	assign condition_3 = (go & !grant_from_output_arbiter_q & (reuse_grant == 0));
	always_comb begin
	  if(in_arbiter)begin
	    if(first_go | (go & grant_from_output_arbiter_q) | (go & !grant_from_output_arbiter_q & (reuse_grant == 0))) begin
	      unmasked_request_vector = i_request;
	      condition1 = 0;
	    end
	    else begin
	      unmasked_request_vector = unmasked_request_vector_q;//whenever unmasked_request_vector should not change, drive it with its previous value that is saved in a register.  
	      condition1 = 1;
	    end
	  end
	  else 
	    unmasked_request_vector = i_request;
	end
	*/
	/* CHANGING THE FOLLOWING LINE, RR GRANTS IN THE SAME CYCLE THAT GO SIGNAL IS ASSERTED*/
	//assign o_out 			= go ? grant_vector_dd : 0;//grant_vector ;