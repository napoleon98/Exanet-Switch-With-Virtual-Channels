`timescale 1ns/1ns
`include "ceiling_up_log2.vh"
module ss_1h_to_b #(

 parameter input_width  = 4,
 parameter output_width = `log2(input_width)

)(

 input  [(input_width-1):0]  i_in,
 output [(output_width-1):0] o_out
);

 generate

	if(input_width <= 2)begin

		assign o_out = i_in[0] ? 1'b0 :1'b1;

	end
	else if(input_width <= 4)begin

		assign o_out = 	i_in[0] ? 2'b00 :
				        i_in[1] ? 2'b01 :
				        i_in[2] ? 2'b10 : 
				        i_in[3] ? 2'b11 : 2'b11;

	end
	else if(input_width <= 8) begin

		assign o_out = 	i_in[0] ? 3'b000 :
				i_in[1] ? 3'b001 :
				i_in[2] ? 3'b010 :
				i_in[3] ? 3'b011 :
				i_in[4] ? 3'b100 :
				i_in[5] ? 3'b101 :
				i_in[6] ? 3'b110 : 'b111;

	end
	else if (input_width <= 16) begin
		assign o_out = 	i_in[0]  ? 4'd0 :
			     	i_in[1]  ? 4'd1 :
			     	i_in[2]  ? 4'd2 :
			     	i_in[3]  ? 4'd3 :
			     	i_in[4]  ? 4'd4 :
			     	i_in[5]  ? 4'd5 :
			     	i_in[6]  ? 4'd6 : 
				    i_in[7]  ? 4'd7 :
			     	i_in[8]  ? 4'd8 :
			     	i_in[9]  ? 4'd9 : 4'b1001;
			     /*	i_in[10] ? 4'd10 :
			     	i_in[11] ? 4'd11 :
			     	i_in[12] ? 4'd12 :
			     	i_in[13] ? 4'd13 : 
			     	i_in[14] ? 4'd14 :
			     	i_in[15] ? 4'd15 : 'b1111; */

	end
  endgenerate

 
endmodule


