`timescale 1ns/1ns

package exanet_pkg;

   typedef struct packed {
   	 logic [15:0]  ecc;		//error correction
	 logic [1:0]   offset;		//offset coordinate
	 logic [5:0]   rsrv;		//reserved
	 logic [41:0]  addr;		//dest mem addres
	 logic [13:0]  size;		//packet size
	 logic [4:0]   pkt_type;		//packet type
	 logic [21:0]  dest_coord;    	//Destination Coordinate
     logic [15:0]  pdid;   		//Protection Domain   
     logic [4:0]   vc;     		//Virtual Channel
    } exanet_header;


   typedef struct packed {
   	 logic [15:0]  ecc;		//error correction
	 logic [7:0]   rsrv2;		//reserved
	 logic [13:0]  rsrv;		//reserved
	 logic [3:0]   resp;		//response
	 logic [13:0]  tid;		//transaction id
	 logic [9:0]   addr;		//dest mem addres
	 logic [13:0]  size;		//packet size
	 logic [4:0]   pkt_type;		//packet type
	 logic [21:0]  dest_coord;    	//Destination Coordinate
     logic [11:0]  seq;   		//Sequence number
     logic [3:0]   pdid;   		//Protection Domain
     logic [4:0]   vc;     		//Virtual Channel	 
    } exanet_ack_header;
    
    
    typedef struct packed {   
      logic [15:0]  ecc;     
      logic [1:0]   flag;           
      logic [7:0]   desired_rate;  
      logic [7:0]   cur_rate;       
      logic [21:0]  src_coord;       
      logic [9:0]   addr;           
      logic [13:0]  fid;      
      logic [4:0]   pkt_type;        
      logic [21:0]  dest_coord;        
      logic [15:0]  pdid;           
      logic [4:0]   vc;           
     } exanet_frp_header;



   typedef struct packed {
   	 logic [31:0]   pld_crc;			//payload error detection
	 logic [7:0]    footer_crc;		//footer error detection
	 logic [11:0]   user_bits;		//user info bits
	 logic [14:0]   ttl;			//time to leave
	 logic [13:0]   seq_num;			//sequence number
	 logic          notif_enable;		//completion notification enable
	 logic          last_p;			//last packet flag
	 logic          first_p;			//first packet flag
	 logic [7:0]    valid_flags;		//
     logic [21:0]   src_coord;   		//source coordinate
     logic [13:0]   tid;     		//transaction ID
    } exanet_footer;

   
   localparam TYPE_RDMA_WRITE 	     = 5'd0;
   localparam TYPE_RDMA_READ_REQUEST = 5'd0;
   localparam TYPE_RDMA_CNTRL_PACKET = 5'd2;
   localparam TYPE_RDMA_COMPL_NOTIFY = 5'd6;
   localparam TYPE_RDMA_RESP		 = 5'd10;

   localparam TYPE_PACK_WRITE	     = 5'd0;
   localparam TYPE_PACK_RESP		 = 5'd10;

   localparam TYPE_FRP		         = 5'd11;
   localparam TYPE_RRP		         = 5'd11;


endpackage : exanet_pkg



interface exanet(); 

  logic header_valid;
  logic header_ready;
  logic payload_valid;
  logic payload_ready;
  logic footer_valid;
  logic footer_ready;
  logic [127:0] data;
  
  modport master (
    output header_valid,
    input header_ready,
    output payload_valid,
    input payload_ready,
    output footer_valid,
    input footer_ready,
    output data
  );

  modport slave(
    input header_valid,
    output header_ready,
    input payload_valid,
    output payload_ready,
    input footer_valid,
    output footer_ready,
    input data
  );


endinterface : exanet



