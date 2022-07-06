`timescale 1ns/1ns


package exanet_crosb_pkg;

   typedef struct packed {
   	 logic        is_inter_router;     //if 1 then it routes based on inter routing.
   	 logic        is_central_router;   //if 1 then it routes based on Central routing, else based on ofset + addr.
     logic [2:0]  dest_x0_port;        //which port takes you to "0". Only used on inter routing scheme.
     logic [2:0]  dest_x1_port;        //which port takes you to "1". Only used on inter routing scheme.		
     logic [2:0]  dest_x2_port;        //which port takes you to "2". Only used on inter routing scheme.		
     logic [2:0]  dest_x3_port;        //which port takes you to "3". Only used on inter routing scheme.		
     logic [2:0]  dest_y_port;         //which port takes you to mezz router. Only used on inter routing scheme.	
     logic [2:0]  local_port;          //which port takes you to local NI crosb. Only used on inter routing scheme.		
     logic [1:0]  multipath_enable;
    } cntrl_info_t;
    
   typedef struct packed {
     logic [31:0] hdr;
     logic [31:0] pld;
     logic [31:0] ftr;
   } counter_t;
    
    
  
  function [31:0] count_ones;  
      input integer number;  
      integer i ;
      count_ones = 32'd0;
      for (i = 0 ; i < 32 ; i = i +1 ) begin
        count_ones += number[i];
      end
  endfunction  
    


endpackage : exanet_crosb_pkg

interface AXIS(); 

  logic         TVALID;
  logic         TREADY;
  logic [127:0] TDATA;
  logic [4:0]   TDEST;     //5 bits allow for 32ports
  logic         TLAST;
  logic         prio;
  
  modport slave (
    input TVALID,
    output TREADY,
    input TDATA,
    input TDEST,
    input TLAST,
    input prio
  );

  modport master (
    output TVALID,
    input TREADY,
    output TDATA,
    output TDEST,
    output TLAST,
    output prio
  );


endinterface : AXIS