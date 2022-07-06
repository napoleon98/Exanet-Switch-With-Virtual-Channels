`timescale 1ns/1ps
import exanet_crosb_pkg::*;
import exanet_pkg::*;



module exa_crosb_traffic_consumer_with_VCs #(
	
	parameter input_num  = 4,
	parameter output_num = 4,
	parameter vc_num     = 4,
	parameter prio_num   = 2
)(
    input           clk,
    input           resetn,
    input [21:0]    i_src_coord,
    input [4:0]     i_backpressure,
    exanet.slave    exa
);

  
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
  wire [5:0]   source_file = mem[0][111:104];
  /*each packet has a size of 23, and addr_file is multiple of 23*/
  wire [31:0]  addr_file   = exa.data[127:96]*23; //is in the footer...
  wire [127:0] traffic_gen_mem[input_num] [128*23];/*it was 64*23*/
  reg  [31:0]  pointer      = 0;
  genvar j;
  generate
  for (j = 0 ; j < input_num ; j = j + 1) begin
    assign traffic_gen_mem[j] = exa_crosb_top_with_VCs_tb.traffic_gen[j].traffic_gen_0.MEM;
  end
  endgenerate
  
  //when the whole packet has arrived, check the following:
  reg [127:0] temp;
  //reg [127:0] source;
  //reg [127:0] timestamp;
  reg [127:0] packet_num;
  reg [127:0] inc_prio;
  reg [127:0] inc_dest;
  wire [4  :0] inc_size = (mem[0][61:48]==0) ? 0 : ((mem[0][61:48] - 1)>>4)+1; ;
  
 
  always @(posedge clk) begin
    if (exa.footer_valid & exa.footer_ready) begin  
      pointer = 0;

      //$sformat(filename, ".traffic_gen%d.dat", source_file); 
      //fd = $fopen(filename, "r"); 
      //if (fd == 0 ) $stop;
      //$fseek ( fd, 34*23*addr_file, 0 ); 
           
      //$fscanf(fd,"%h",temp);  // tag    
      pointer = pointer + 1;
      //$fscanf(fd,"%h",temp);  // pkt counter
      packet_num = traffic_gen_mem[source_file][pointer + addr_file];
      pointer = pointer + 1;
      //$fscanf(fd,"%h",temp);  // timestamp  
      pointer = pointer + 1;  
      //$fscanf(fd,"%h",inc_dest);  // dest  
      inc_dest = traffic_gen_mem[source_file][pointer + addr_file];
      pointer = pointer + 1;  
      //$fscanf(fd,"%h",inc_prio);  // prio  
      inc_prio = traffic_gen_mem[source_file][pointer + addr_file];
      pointer = pointer + 1;  
 
      // $fscanf(fd,"%h",temp);  //header            
      temp = traffic_gen_mem[source_file][pointer + addr_file];
      pointer = pointer + 1;               
      if ( temp != mem[0] ) begin
        $display("error at header!! file: %h  and mem %h",temp,mem[0]);
        $display("souce: %0d . i am consumer %0d . addr in file was %0h",source_file,i_src_coord,addr_file );
         $display("time is %t",$time); 
        $stop();        
      end  
      /*
      else begin
        $display("true  header!! file: %h  and mem %h",temp,mem[0]);
        $display("souce: %0d . i am consumer %0d . addr in file was %0h",source_file,i_src_coord,addr_file );
        $display("time is %t",$time); 
      end
      */
      if (inc_dest != i_src_coord) begin
        $display("error this is not the correct destination!! file: %0h  and here %0h",inc_dest , i_src_coord);
        $display("souce: %0d . i am consumer %0d . addr in file was %h",source_file,i_src_coord,addr_file );
         $display("time is %t",$time);
        $stop();
      end
      else begin
        //$display(" True t destination is!!file: %0h  and here %0h",inc_dest , i_src_coord);
      end
      if ((inc_prio != prio_num) & (prio_num != 2)) begin
        $display("error this is not the correct prio!! file: %h  and here %h",inc_prio , prio_num);
        $display("souce: %0d . i am consumer %0d . addr in file was %0h",source_file,i_src_coord,addr_file ); 
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
            $display("souce: %0d. i am consumer %0d . addr in file was %0h",source_file,i_src_coord,addr_file ); 
             $display("time is %t",$time);
            $stop();
        end 
        else begin
         // $display(" True payload %d is!! file: %h  and mem %h",i,temp,mem[i+1]);
        end 
      end
      
      //$fscanf(fd,"%h",temp);
      temp = traffic_gen_mem[source_file][pointer + addr_file];
      pointer = pointer + 1;
      if ( temp != exa.data) begin
        $display("error at footer!! file: %h  and mem %h",temp,exa.data);
        $display("souce: %0d . i am consumer %0d . addr in file was %0h",source_file,i_src_coord,addr_file ); 
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
