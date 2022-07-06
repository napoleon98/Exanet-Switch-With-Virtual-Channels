`define PKT_VC_RANGE          4:0   //  5 bits
`define PKT_PROT_ID_RANGE    20:5   // 16 bits
`define PKT_DST_COORD_RANGE  42:21  // 22 bits
`define PKT_TYPE_RANGE       47:43  //  5 bits
`define PKT_SIZE_RANGE       61:48  // 14 bits
`define PKT_DST_VA_RANGE    105:62  // 44 bits
`define PKT_HDR_RFU_RANGE   113:106 //  8 bits
`define PKT_HDR_CRC_RANGE   127:112 // 16 bits
//
`define PKT_CHANEL_ID_RANGE  13:0   // 14 bits
`define PKT_SRC_COORD_RANGE  35:14  // 22 bits
`define PKT_USER_RANGE       95:36  // 54 bits
`define PKT_CRC_RANGE       127:96  // 32 bits
//


`define EDMA_WR_TYPE  	  	5'd0	
`define EDMA_CNTRL_TYPE     	5'd2	
`define EDMA_CON_TYPE       	5'd6
`define EDMA_RESP_TYPE       	5'd10

`define PCKTZER_TYPE    	5'd0
`define PCKTZER_RR_TYPE		5'd1	

`define REQ_AXIR_TYPE       	5'd3
`define REQ_AXIW_TYPE       	5'd9				
`define ACK_AXIW_TYPE       	5'd11		
`define ACK_AXIR_TYPE       	5'd11	


`define HVMBOX_ACK_TYPE     	5'd10
`define RT_MBOX_RESP_TYPE   	5'd10
	
`define FLOW_RATE_TYPE       	5'd18	


