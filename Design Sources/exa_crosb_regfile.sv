//
`timescale 1ns/1ns

import exanet_crosb_pkg::*;
`include "ceiling_up_log2.vh"

module exa_crosb_regfile #(
    parameter integer input_num     = 4,
    parameter integer output_num    = 4,
	parameter S_AXI_ID_WIDTH        = 12,
	parameter S_AXI_DATA_WIDTH      = 128,
	parameter conf_reg_num          = 1,
	parameter prio_num              = 2,
	parameter S_AXI_ADDR_WIDTH      = `log2(conf_reg_num*16),
	parameter DEBUG                 = "false"
	)(
	// AXI Clock and Reset
	input                           S_AXI_ACLK,
	input                           S_AXI_ARESETN,
	// Memory Read Address Channel
	input [S_AXI_ID_WIDTH-1:0]      S_AXI_ARID,
	input [S_AXI_ADDR_WIDTH-1:0]    S_AXI_ARADDR,
	input [7:0]                     S_AXI_ARLEN,
	input [2:0]                     S_AXI_ARSIZE,
	input [1:0]                     S_AXI_ARBURST,
	input [1:0]                     S_AXI_ARLOCK,
	input [3:0]                     S_AXI_ARCACHE,
	input [2:0]                     S_AXI_ARPROT,
	input                           S_AXI_ARVALID,
	output                          S_AXI_ARREADY,
	// Memory Read Data Channel
	output [S_AXI_ID_WIDTH-1:0]     S_AXI_RID,
	output [S_AXI_DATA_WIDTH-1:0]   S_AXI_RDATA,
	output [1:0]                    S_AXI_RRESP,
	output                          S_AXI_RLAST,
	output                          S_AXI_RVALID,
	input                           S_AXI_RREADY,
	// Memory Write Address Channel
	input [S_AXI_ID_WIDTH-1:0]      S_AXI_AWID,
	input [S_AXI_ADDR_WIDTH-1:0]    S_AXI_AWADDR,
	input [7:0]                     S_AXI_AWLEN,
	input [2:0]                     S_AXI_AWSIZE,
	input [1:0]                     S_AXI_AWBURST,
	input [1:0]                     S_AXI_AWLOCK,
	input [3:0]                     S_AXI_AWCACHE,
	input [2:0]                     S_AXI_AWPROT,
	input wire                      S_AXI_AWVALID,
	output wire                     S_AXI_AWREADY,
	// Memory Write Data Channel
	input [S_AXI_DATA_WIDTH-1:0]    S_AXI_WDATA,
	input [(S_AXI_DATA_WIDTH/8)-1:0]S_AXI_WSTRB,
	input                           S_AXI_WLAST,
	input                           S_AXI_WVALID,
	output                          S_AXI_WREADY,
	//
	// Memory Write Responce Channel
	output [S_AXI_ID_WIDTH-1:0]     S_AXI_BID,
	output [1:0]                    S_AXI_BRESP,
	output                          S_AXI_BVALID,
	input                           S_AXI_BREADY,
	
	//register outputs.	
    (* KEEP = DEBUG *) (* MARK_DEBUG = DEBUG *)
	output cntrl_info_t             o_cntrl_info,	
    (* KEEP = DEBUG *) (* MARK_DEBUG = DEBUG *)
	input counter_t                 i_pkt_counter_input[input_num-1:0][prio_num-1:0],// needs to be changed !!!!!!!!
    (* KEEP = DEBUG *) (* MARK_DEBUG = DEBUG *)
	input counter_t                 i_pkt_counter_output[output_num-1:0][prio_num-1:0] // needs to be changed !!!!!!!!

);

    (* KEEP = DEBUG *) (* MARK_DEBUG = DEBUG *)
	wire 				        reg_we;	
    (* KEEP = DEBUG *) (* MARK_DEBUG = DEBUG *)
	reg  [S_AXI_ADDR_WIDTH-1:0] wr_addr;	//10 bits + 1 for the second list.	
    (* KEEP = DEBUG *) (* MARK_DEBUG = DEBUG *)
	reg  [S_AXI_ID_WIDTH-1:0]   wr_id;	
    (* KEEP = DEBUG *) (* MARK_DEBUG = DEBUG *)
	reg  [1:0]                  wr_resp;	
    (* KEEP = DEBUG *) (* MARK_DEBUG = DEBUG *)
	reg  [S_AXI_ADDR_WIDTH-1:0] rd_addr;	//10 bits + 1 for the second list. could be parametized.	
    (* KEEP = DEBUG *) (* MARK_DEBUG = DEBUG *)
	reg  [S_AXI_ID_WIDTH-1:0]   rd_id;	
    (* KEEP = DEBUG *) (* MARK_DEBUG = DEBUG *)
	reg  [1:0]                  rd_resp;



	
    (* KEEP = DEBUG *) (* MARK_DEBUG = DEBUG *)
	reg [2:0] wr_State;	
    (* KEEP = DEBUG *) (* MARK_DEBUG = DEBUG *)
 	reg [2:0] rd_State;


	// Write FSM
	localparam 	wr_idle    = 4'b001, //1
			    wr_data    = 4'b010, //2
			    wr_ack     = 4'b100; //8

	// Read FSM
	localparam 	rd_idle  = 3'b01,
			    rd_ready = 3'b10;




	//FOR THE RESP, CHECK IF THE ADDR IS 64 BIT ALIGNED,	
    (* KEEP = DEBUG *) (* MARK_DEBUG = DEBUG *)
	wire axi_wr_error = (S_AXI_AWLEN!=0)|(S_AXI_AWADDR[2:0]!=0);	
    (* KEEP = DEBUG *) (* MARK_DEBUG = DEBUG *)
	wire axi_rd_error = (S_AXI_ARLEN!=0)|(S_AXI_ARADDR[2:0]!=0);
	
	/* ----------------- Write Address latch -------------------*/
	always @(posedge S_AXI_ACLK) begin
	if(~ S_AXI_ARESETN) begin
		wr_addr <=  0;
		wr_id   <=  0;
		wr_resp <=  2'b11;
	end
	else if((wr_State[0]) & S_AXI_AWVALID) begin
		/* wr_addr is S_AXI_AWWADR right shifter by 4, in order to be 128 bit aligned.*/
		wr_addr <=  S_AXI_AWADDR >> 4;
		wr_id   <=  S_AXI_AWID;
		wr_resp <=  (axi_wr_error) ? 2'b11 : 2'b00;
	end
	end
	
	/* ----------------- Read Address latch -------------------*/
	always @(posedge S_AXI_ACLK) begin
	if(~ S_AXI_ARESETN) begin
		rd_addr <=  0;
		rd_id   <=  0;
		rd_resp <=  0;
	end
	else if(S_AXI_ARVALID) begin
	    /* wr_addr is S_AXI_ARADDR right shifter by 4, in order to be 128 bit aligned.*/
		rd_addr <=  S_AXI_ARADDR>> 4;
		rd_id   <=  S_AXI_ARID;
		rd_resp <=  (axi_rd_error) ? 2'b11 : 2'b00; 
	end
	end


	/* ----------------- Write Address FSM -------------------*/
	always @(posedge S_AXI_ACLK) begin
	if(~ S_AXI_ARESETN) wr_State <=  wr_idle;
	else begin
		case(wr_State)
		wr_idle :
		begin
			if(S_AXI_AWVALID)
				wr_State <=  wr_data;

			else 
				wr_State <=  wr_idle;
		end
		//
		wr_data :
			 begin
			    if(S_AXI_WVALID)
				wr_State <=  wr_ack;
			    else 
				wr_State <=  wr_data;
			 end
		//
		wr_ack  : 
			 begin
			    if(S_AXI_BREADY)
				 wr_State <=  wr_idle;
			    else wr_State <=  wr_ack;
			 end
		//
		default : wr_State <=  wr_idle;
		//
		endcase
		end
	end

	//
	assign S_AXI_AWREADY = (wr_State[0]);
	assign S_AXI_WREADY  = (wr_State[1]);

	assign S_AXI_BID    = wr_id;
	assign S_AXI_BRESP  = wr_resp;
	assign S_AXI_BVALID = (wr_State[2]);

	
	/* ----------------- Read Address FSM -------------------*/
	always @(posedge S_AXI_ACLK) begin
	if(~ S_AXI_ARESETN) rd_State <=  rd_idle;
	else begin
	case(rd_State)

	rd_idle  : begin
		     if(S_AXI_ARVALID)
		         rd_State <=  rd_ready;
		     else 
			rd_State <=  rd_idle;
		  end
	rd_ready : begin
		     if (S_AXI_RREADY)
			rd_State <=   rd_idle;
		     else 
			rd_State <=  rd_ready;
		  end
	default   : rd_State <=   rd_idle;

	endcase
	end
	end


	
	assign S_AXI_ARREADY 	= rd_State[0];
	assign S_AXI_RID     	= rd_id;
	assign S_AXI_RRESP   	= rd_resp;
	assign S_AXI_RLAST   	= 1'b1;
	assign S_AXI_RVALID  	= rd_State[1]; 

	assign reg_we  	= wr_State[1] & S_AXI_WVALID ;



/*----------------------------------------------------------------------------------*/
/*------------------------------------ INITIATE REGISTERS---------------------------*/
/*----------------------------------------------------------------------------------*/
    //required registers:
    //64bit for inter router               |1
    //64 for port destination              |1
    //64 for enable multipathing           |1
    //16ports*2prios_each*2vals32bit_each (hdr_pld) = 32 for input
    //16ports*2prios_each*1vals32bit_each (ftr)     = 32 for input . 64total
    //16ports*2prios_each*2vals32bit_each (hdr_pld) = 32 for output
    //16ports*2prios_each*1vals32bit_each (ftr)     = 32 for output .64total

    //=256
    localparam static_conf_regs = 3;
    localparam pkt_count_regs   = input_num*4;
	
    (* KEEP = DEBUG *) (* MARK_DEBUG = DEBUG *)
	reg [63:0] cntrl_info_reg [conf_reg_num-1:0] ; // registers of 64bit each

	/*initialize for simulation*/
	// synthesis translate_off
	integer x;
	initial begin		
		for (x = 0 ; x<conf_reg_num ; x = x + 1) begin
			cntrl_info_reg[x] = 0;
		end
	end
    
	// synthesis translate_on	
	
	//i_pkt_counter_output[output_num-1:0][2:0][prio_num-1:0];
	//hdr and pld are stored in one reg . ftr in enother one.
	//so each port needs in total 4 regs, 2 for each prio.
	genvar i;
    generate
    for (i=0 ; i<3 ; i++) begin
      always @(posedge S_AXI_ACLK)begin
        if ((reg_we)&(wr_addr == i)) begin
          if (S_AXI_WSTRB[3:0] == 4'hf)
            cntrl_info_reg[i][31:0]  = S_AXI_WDATA[31:0];
          if (S_AXI_WSTRB[7:4] == 4'hf)
            cntrl_info_reg[i][63:32] = S_AXI_WDATA[63:32]; 
        end
      end    
    end    
    
    int in_offset = static_conf_regs;
    for (i = 0 ; i < pkt_count_regs ; i+=2) begin      
      always @(posedge S_AXI_ACLK)begin
        if (!reg_we) begin
          cntrl_info_reg[in_offset+i][31:  0]   <= i_pkt_counter_input[i>>2][i[1]].hdr; //hdr
          cntrl_info_reg[in_offset+i][63: 32]   <= i_pkt_counter_input[i>>2][i[1]].pld; //pld
          cntrl_info_reg[in_offset+i+1][31:  0] <= i_pkt_counter_input[i>>2][i[1]].ftr; //ftr
        end  
      end    
    end
    
    int out_offset = static_conf_regs + pkt_count_regs;
    for (i = 0 ; i < pkt_count_regs ; i+=2) begin
      int offset = static_conf_regs + pkt_count_regs;
      always @(posedge S_AXI_ACLK)begin
        if (!reg_we) begin
          cntrl_info_reg[out_offset+i][31:  0]   <= i_pkt_counter_output[i>>2][i[1]].hdr; //hdr
          cntrl_info_reg[out_offset+i][63: 32]   <= i_pkt_counter_output[i>>2][i[1]].pld; //pld
          cntrl_info_reg[out_offset+i+1][31:  0] <= i_pkt_counter_output[i>>2][i[1]].ftr; //ftr
        end
      end    
    end
    
	endgenerate


  assign S_AXI_RDATA = {cntrl_info_reg[rd_addr],cntrl_info_reg[rd_addr]} ;


/*----------------------------------------------------------------------------------*/
/*------------------------------- assign register signals---------------------------*/
/*----------------------------------------------------------------------------------*/
	assign o_cntrl_info.is_inter_router   = cntrl_info_reg[0][0]     ;
	assign o_cntrl_info.is_central_router = cntrl_info_reg[0][1]     ;
	assign o_cntrl_info.dest_x_minus      = cntrl_info_reg[1][3:0]   ;
	assign o_cntrl_info.dest_x_plus       = cntrl_info_reg[1][7:4]   ;
	assign o_cntrl_info.dest_y_minus      = cntrl_info_reg[1][11:8]  ;
	assign o_cntrl_info.dest_y_plus       = cntrl_info_reg[1][15:12] ;
	assign o_cntrl_info.dest_z_minus      = cntrl_info_reg[1][19:16] ;
	assign o_cntrl_info.dest_z_plus       = cntrl_info_reg[1][23:20] ;
	//assign o_cntrl_info.dest_y_port       = cntrl_info_reg[1][19:16] ;
	assign o_cntrl_info.local_port        = cntrl_info_reg[1][27:24] ;
	
	assign o_cntrl_info.multipath_enable  = cntrl_info_reg[2][1:0]  ;




endmodule
