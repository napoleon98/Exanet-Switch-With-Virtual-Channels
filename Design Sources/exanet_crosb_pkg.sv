`timescale 1ns/1ns


package exanet_crosb_pkg;

   typedef struct packed {
   	 logic        is_inter_router;     //if 1 then it routes based on inter routing.
   	 logic        is_central_router;   //if 1 then it routes based on Central routing, else based on ofset + addr.
     logic [3:0]  dest_x_plus;        
     logic [3:0]  dest_x_minus;        
     logic [3:0]  dest_y_plus;        
     logic [3:0]  dest_y_minus;  
     logic [3:0]  dest_z_plus;
     logic [3:0]  dest_z_minus;// Are minus/plus needed ??..if you change it, change and the regfile as well !!     		                                	
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