`timescale 1ns/1ps
import exanet_crosb_pkg::*;
import exanet_pkg::*;
`include "ceiling_up_log2.vh"


module exa_crosb_traffic_consumer_with_VCs #(
	parameter TDEST_WIDTH       = 3,
	parameter input_num         = 4,
	parameter output_num        = 4,
	parameter vc_num            = 4,
	parameter prio_num          = 2,
	
    parameter logVcPrio         = `log2(prio_num*vc_num),
    parameter logOutput         = `log2(output_num),
    parameter logPrio           = `log2(prio_num),
    parameter logVc             = `log2(vc_num),
    parameter dimension_x       = 4,
    parameter dimension_y       = 2,
    parameter dimension_z       = 2   
)(
    input                   clk,
    input                   resetn,
    input [21:0]            i_src_coord,
    input [4:0]             i_backpressure,
    exanet.slave            exa,
    input [logOutput-1 :0]  i_dests_of_each_input[input_num-1:0][prio_num*vc_num-1 :0],
    input  cntrl_info_t     i_cntrl_info,
    input [logOutput-1 :0]  i_consumer_id,
    input [logVcPrio-1:0]   i_selected_output_vc
);





`define DST_X_RANGE 	24:21
`define DST_Y_RANGE 	28:25 
`define DST_Z_RANGE 	32:29 
`define DST_OFF_RANGE 	34:33
`define PATH_RANGE 	    111:109
  
  reg [4:0] rand_5bit = 0;    //used for backpressuer
  always @(posedge clk) begin
    rand_5bit <= $random();
  end

  localparam max_size = 15;
  



  assign exa.header_ready  = (!resetn) ? 0 : (rand_5bit >= i_backpressure);
  assign exa.payload_ready = (!resetn) ? 0 : (rand_5bit >= i_backpressure);
  assign exa.footer_ready  = (!resetn) ? 0 : (rand_5bit >= i_backpressure);


  //count how many words have arrived
  reg [127:0] mem [18] ;
  reg [31:0] addr = 1;
  always @(posedge clk) begin
    if (exa.footer_valid & exa.footer_ready)
        addr <= 1;
    else if (exa.payload_valid & exa.payload_ready)
        addr <= addr+1;
  end
  
  //write down the packet
  always @(posedge clk) begin
    if (exa.header_valid & exa.header_ready)
      mem[0] <= exa.data;
    else if (exa.payload_valid & exa.payload_ready)
      mem[addr] <= exa.data;
    else if (exa.footer_valid & exa.footer_ready)
      mem[17] <= exa.data;
  end
  
  
  //the bellow are used to check the memory of the input generators
  reg [31:0] i;
  /*source_file indicates from which input are coming the data(is the same as o_input_sel from output arbiter)*/
  wire [5:0]   source_file = mem[0][111:104];// exa_header.rsv section of header
  /*each packet has a size of 23, and addr_file is multiple of 23*/
  wire [31:0]  addr_file   = exa.data[127:96]*23; //is in the footer...
  logic [127:0] traffic_gen_mem[input_num] [128*23];/*it was 64*23*/
  reg  [31:0]  pointer      = 0;
  genvar j;
  generate
  for (j = 0 ; j < input_num ; j = j + 1) begin
    assign traffic_gen_mem[j] = exa_crosb_top_with_VCs_tb.traffic_gen[j].traffic_gen.MEM;
  end
  endgenerate
  
  //when the whole packet has arrived, check the following:
  reg [127:0] temp;
  //reg [127:0] source;
  //reg [127:0] timestamp;
  reg [127:0] packet_num;
  reg [127:0] inc_prio;
  reg [127:0] inc_dest;
  reg [127:0] input_vc;
  wire [4  :0] inc_size = (mem[0][61:48]==0) ? 0 : ((mem[0][61:48] - 1)>>4)+1; 
  
  
  wire                   input_port_dimension                          ;
  wire                   output_port_dimension                         ;
  logic [logVcPrio-1:0]  output_vc                                     ;
  reg   [logVcPrio-1:0]  output_vc_q = 0                               ;
  wire  [logPrio - 1 :0] num_of_prio                                   ;


	

  wire [3:0] local_x  = i_src_coord[3:0]; 	

  wire [3:0] local_y  = i_src_coord[7:4]; 	
 
  wire [3:0] local_z  = i_src_coord[11:8]; 	
  
  wire [1:0] local_off= i_src_coord[13:12]; 	
 
  wire [5:0] local_tor= i_src_coord[21:14];  
	
 
  wire [3:0] dst_x    ;

  wire [3:0] dst_y    ;	
 
  wire [3:0] dst_z    ;	

  wire [1:0] dst_off  ;
   
  
  
  assign dst_x        = exa.data[`DST_X_RANGE]  ;
  assign dst_y        = exa.data[`DST_Y_RANGE]  ;
  assign dst_z        = exa.data[`DST_Z_RANGE]  ;
  assign dst_off      = exa.data[`DST_OFF_RANGE];
  
  
  logic  [TDEST_WIDTH-1:0]   tdest_var;
  reg    [TDEST_WIDTH-1:0]   tdest_var_q = 0;
   
  always_comb begin        
    tdest_var     = 0;
   
    if (exa.header_valid) begin
      /*-----------------------------------------------*/
      /*IF this is the Network FPGA Router (INTER-QFDB)*/
      
      //*********************** == 0 IS ADDED JUST FOR TESTING *******************
      if (i_cntrl_info.is_inter_router == 0) begin
        /*first see if its for this QFDB*/
        if ((dst_y == local_y) & (dst_x == local_x) & (dst_z == local_z)) begin
          /*if yes, then route to the apropriate port based on dest FPGA*/
          if (dst_off == 0)
            tdest_var      =  i_cntrl_info.local_port;   //f1
          else if (dst_off == 1)
            tdest_var      =  i_cntrl_info.local_port+1; //f2
          else if (dst_off == 2)
            tdest_var      =  i_cntrl_info.local_port+2; //f3
          else
            tdest_var      =  i_cntrl_info.local_port+3; //f4
         
        end
        
        else if(dst_z > local_z)begin
          tdest_var     =  i_cntrl_info.dest_z_plus ; 
          
        end
        else if(dst_z < local_z)begin
          tdest_var     =  i_cntrl_info.dest_z_minus ; 
          
        end 
     
        //check if the destination is in an upper blade
        else if(dst_y > local_y)begin
        
        //check if wraparaound path is smaller(dimension - 1 because we start counting from 0, and +1 because it needs an extra hop for wraparound)
          if((dst_y - local_y) > (local_y + 1 + dimension_y - 1 - dst_y ))begin
            tdest_var     =  i_cntrl_info.dest_y_minus ;// supposing that if you go to dest_y_minus from 0, you will be drived to the 3 blade/mezz 
            
          end
          else begin 
            tdest_var     =  i_cntrl_info.dest_y_plus;// tdest_var takes the port that goes to the upper QFDB
                     
          end   
        end
        
        //else if the destination is in a lower blade
        else if(dst_y < local_y)begin
        //check if wraparaound path is smaller(dimension - 1 because we start counting from 0, and +1 because it needs an extra hop for wraparound)
          if((local_y - dst_y) > ((dimension_y - 1 - local_y + dst_y + 1)) ) begin 
            tdest_var     =  i_cntrl_info.dest_y_plus ;
                    
          end
          else begin
            tdest_var     =  i_cntrl_info.dest_y_minus ; 
            
          end
        end
        
        //if you are here, the destination is in the same blade, so check if he is in a rigther QFDB 
        else if(dst_x > local_x)begin
        //check if wraparaound path is smaller(dimension - 1 because we start counting from 0, and +1 because it needs an extra hop for wraparound)
          if((dst_x - local_x) > (local_x + 1 + dimension_x - 1 - dst_x ))begin
            tdest_var     =  i_cntrl_info.dest_x_minus ; 
           
          end
          else begin 
            tdest_var     =  i_cntrl_info.dest_x_plus ; 
           
          end
        end
        
        // else
        else if (dst_x < local_x)begin
        //check if wraparaound path is smaller(dimension - 1 because we start counting from 0, and +1 because it needs an extra hop for wraparound)
          if((local_x - dst_x) > ((dimension_x - 1 - local_x + dst_x + 1)))begin
            tdest_var     =  i_cntrl_info.dest_x_plus ; 
           
          end
          else begin
            tdest_var     =  i_cntrl_info.dest_x_minus ; 
            
          end
        end

      end
    end
  end 
  
  always @(posedge clk) begin
    if(exa.header_valid) begin
      tdest_var_q <= tdest_var; 
      
    end
    if(exa.footer_valid & exa.footer_ready)
      output_vc_q <= output_vc;
  end 
  
  
                                 
  
  assign input_port_dimension  = (source_file == i_cntrl_info.dest_z_minus) | (source_file == i_cntrl_info.dest_z_plus) ? 0 :
                                 (source_file == i_cntrl_info.dest_y_minus) | (source_file == i_cntrl_info.dest_y_plus) ? 1 :
                                 (source_file == i_cntrl_info.dest_x_minus) | (source_file == i_cntrl_info.dest_x_plus) ? 2 : 3;

  
  assign output_port_dimension = (tdest_var_q == i_cntrl_info.dest_z_minus) | (tdest_var_q == i_cntrl_info.dest_z_plus) ? 0 :
                                 (tdest_var_q == i_cntrl_info.dest_y_minus) | (tdest_var_q == i_cntrl_info.dest_y_plus) ? 1 :
                                 (tdest_var_q == i_cntrl_info.dest_x_minus) | (tdest_var_q == i_cntrl_info.dest_x_plus) ? 2 : 3;
                                
  /*  The below code is working only for prio_num = 2 */
  
  
 
  
  
  
  assign input_vc              = (exa.footer_valid & exa.footer_ready) ? traffic_gen_mem[source_file][2 + addr_file] : 0;

  assign num_of_prio           = (exa.footer_valid & exa.footer_ready) ? input_vc/vc_num : 0 ;

  always_comb begin
  
    output_vc = 0;
    
    if(exa.footer_valid & exa.footer_ready)begin
      if(input_port_dimension != output_port_dimension)begin
      /*
        if(input_vc > vc_num - 1)begin//if it is a high prio vc..
        
          output_vc = ((input_vc - vc_num + 1) % vc_num) + vc_num;
        end
        else begin
          output_vc = (input_vc + 1) % vc_num;
        end
      */
        output_vc = ((input_vc - num_of_prio*vc_num + 1) % vc_num) + num_of_prio*vc_num;
      end
      else begin
        output_vc = input_vc;
      end
    end
    
  
  end
  
  
 
  always @(posedge clk) begin
    if (exa.footer_valid & exa.footer_ready) begin  
      pointer = 0;

      //$sformat(filename, ".traffic_gen%d.dat", source_file); 
      //fd = $fopen(filename, "r"); 
      //if (fd == 0 ) $stop;
      //$fseek ( fd, 34*23*addr_file, 0 ); 
           
      //$fscanf(fd,"%h",temp);  // tag    
      pointer    = pointer + 1                                      ;
      //$fscanf(fd,"%h",temp);  // pkt counter
      packet_num = traffic_gen_mem[source_file][pointer + addr_file];
      pointer    = pointer + 1                                      ;
      //$fscanf(fd,"%h",temp);  // timestamp  
     // input_vc   = traffic_gen_mem[source_file][pointer + addr_file];
      pointer    = pointer + 1                                      ;  
      //$fscanf(fd,"%h",inc_dest);  // dest  
      inc_dest   = traffic_gen_mem[source_file][pointer + addr_file];
      pointer    = pointer + 1                                      ;  
      //$fscanf(fd,"%h",inc_prio);  // prio  
      inc_prio   = traffic_gen_mem[source_file][pointer + addr_file];
      pointer   = pointer + 1                                       ;  
 
      // $fscanf(fd,"%h",temp);  //header          
      
      traffic_gen_mem[source_file][pointer + addr_file][4:0] = output_vc   ;
        
      temp = traffic_gen_mem[source_file][pointer + addr_file]      ;
      pointer = pointer + 1                                         ;               
      if ( temp != mem[0] ) begin
        $display("error at header!! file: %h  and mem %h",temp,mem[0]);
        $display("souce: %0d . i am consumer %0d . addr in file was %0h",source_file,i_consumer_id,addr_file );
        $display("time is %t",$time); 
        $stop();        
      end  
      
      else begin
        $display("true  header!! file: %h  and mem %h",temp,mem[0]);
        $display("souce: %0d . i am consumer %0d . addr in file was %0h",source_file,i_consumer_id,addr_file );
        $display("time is %t",$time); 
      end
      
      
      if ( tdest_var_q != i_consumer_id ) begin
        $display("error at destination!! file: %h  and mem %h",tdest_var_q,i_consumer_id);
        $display("souce: %0d . i am consumer %0d . addr in file was %0h",source_file,i_consumer_id,addr_file );
        $display("time is %t",$time); 
        $stop();        
      end  
      
      else begin
        $display("true  destination!! file: %h  and mem %h",tdest_var_q,i_consumer_id);
        //$display("souce: %0d . i am consumer %0d . addr in file was %0h",source_file,i_consumer_id,addr_file );
        //$display("time is %t",$time); 
      end
      
      
     
       if ( output_vc != i_selected_output_vc ) begin
         $display("error at output vc!! file: %h  and mem %h",output_vc,i_selected_output_vc);
         $display("souce: %0d . i am consumer %0d . addr in file was %0h",source_file,i_selected_output_vc,addr_file );
         $display("time is %t",$time); 
         $stop();        
       end  
       
       else begin
         $display("true  output vc!! file: %h  and mem %h",output_vc,i_selected_output_vc);
         //$display("souce: %0d . i am consumer %0d . addr in file was %0h",source_file,i_consumer_id,addr_file );
         //$display("time is %t",$time); 
       end
       
            
      
      /*
      if (i_dests_of_each_input[source_file][input_vc] != i_src_coord) begin
        $display("error this is not the correct destination!! file: %0d  and here %0d",i_dests_of_each_input[source_file][input_vc] , i_src_coord);
        $display("source: %0d . i am consumer %0d . addr in file was %h",source_file,i_src_coord,addr_file );
         $display("time is %t",$time);
        $stop();
      end
      else begin
        $display(" True destination is!!file: %0h  and here %0h",i_dests_of_each_input[source_file][input_vc] , i_src_coord);
      end
      */
      if ((inc_prio != prio_num) & (prio_num != 2)) begin
        $display("error this is not the correct prio!! file: %h  and here %h",inc_prio , prio_num);
        $display("souce: %0d . i am consumer %0d . addr in file was %0h",source_file,i_consumer_id,addr_file ); 
        $display("time is %t",$time);
        $stop();
      end
      
      //should take into acount the size of the packet
      for (i = 0 ; i < 16 ; i = i + 1) begin  
        //$fscanf(fd,"%h",temp);
        temp = traffic_gen_mem[source_file][pointer + addr_file];
        pointer = pointer + 1;               
        if (( temp != mem[i+1])&(i<inc_size)) begin //look only on the ones that are actually sent
            $display("error at payload %d!! file: %h  and mem %h",i,temp,mem[i+1]);
            $display("souce: %0d. i am consumer %0d . addr in file was %0h",source_file,i_consumer_id,addr_file ); 
            $display("time is %t",$time);
            $stop();
        end 
        else if(( temp == mem[i+1])&(i<inc_size)) begin
         $display(" True payload %d is!! file: %h  and mem %h",i,temp,mem[i+1]);
        end 
      end
      
      //$fscanf(fd,"%h",temp);
      temp = traffic_gen_mem[source_file][pointer + addr_file];
      pointer = pointer + 1;
      if ( temp != exa.data) begin
        $display("error at footer!! file: %h  and mem %h",temp,exa.data);
        $display("souce: %0d . i am consumer %0d . addr in file was %0h",source_file,i_consumer_id,addr_file ); 
         $display("time is %t",$time);
        $stop();
      end   
      else begin
        // $display(" True footer is!! file: %h  and mem %h",temp,exa.data);
      end
    // $display("packet is correct");
     //$display("time is %t",$time);

     //$fclose(fd);
    end  
  end




endmodule
