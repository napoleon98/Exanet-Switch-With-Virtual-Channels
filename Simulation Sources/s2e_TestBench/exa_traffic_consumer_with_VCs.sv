`timescale 1ns / 1ps

import exanet_crosb_pkg::*;
import exanet_pkg::*;

module exa_traffic_consumer_with_VCs #(
  parameter prio_num             = 2,
  parameter vc_num               = 2

)(
  input           clk,
  input           resetn,
  input [4:0]     i_backpressure,

  exanet.slave    exa

);
  
  
  wire [127:0] axi_traffic_gen_mem [vc_num*prio_num - 1:0][54];
  wire [$clog2(vc_num*prio_num)-1:0]   selected_vc;
  //count how many words have arrived
  reg [127:0] mem [vc_num*prio_num - 1:0][18] ;
  reg header_valid_q;
  reg [31:0] addr = 1;//0;
  reg [31:0] packet_num[vc_num*prio_num - 1:0]          = '{'{0},'{0},'{0},'{0}, '{0}, '{0}};
  reg [4:0] rand_5bit = 0;    //used for backpressuer

  
   
   
   always @(posedge clk) begin
     rand_5bit <= $random();
   end
  
  
  always @(posedge clk) begin
    if (exa.footer_valid & exa.footer_ready)
        addr <= 1;//0;
    else if (exa.payload_valid & exa.payload_ready)
        addr <= addr+1;
  end
  
  //write down the packet
  always @(posedge clk) begin
    if (exa.header_valid & exa.header_ready)begin
      mem[selected_vc][0] <= exa.data;
    end
    else if (exa.payload_valid & exa.payload_ready)//the first time that this condition is met, header is stored in mem..Not payload
      mem[selected_vc][addr] <= exa.data;
    else if (exa.footer_valid & exa.footer_ready)
      mem[selected_vc][17] <= exa.data;
  end
  /*the above lines are used when consumer is used by exa_crosb_s2e_with_VCs_tb */
  assign axi_traffic_gen_mem = exa_crosb_s2e_with_VCs_tb.axi_stream_traffic_generator_v1_0_M00_AXIS_inst.MEM;
  assign selected_vc         = exa_crosb_s2e_with_VCs_tb.s2e_with_VCs.selected_vc;
  
  
  assign exa.header_ready    = rand_5bit >= i_backpressure;
  assign exa.payload_ready   = rand_5bit >= i_backpressure;
  assign exa.footer_ready    = rand_5bit >= i_backpressure;

  
    

  always_ff @(posedge clk) begin
    if (exa.footer_valid & exa.footer_ready) begin   
    
      if(packet_num[selected_vc] == 36)
        packet_num[selected_vc] <= 0;
      else
        packet_num[selected_vc] <= packet_num[selected_vc] + 18;      
      
             
      if ( axi_traffic_gen_mem[selected_vc][packet_num[selected_vc] + 0] != mem[selected_vc][0] ) begin
        $display("error at header!! vc: %d, packet_num %d . axi_traffic_gen_mem %h and mem %h",selected_vc,packet_num[selected_vc],axi_traffic_gen_mem[selected_vc][0 + packet_num[selected_vc]],mem[selected_vc][0]);
        $display("time is %t",$time);
        //$stop();        
      end  
      for(int i=1;i<17;i=i+1)begin
        if(axi_traffic_gen_mem[selected_vc][i + packet_num[selected_vc]] != mem[selected_vc][i])begin
          $display("error at payload!! vc: %d, flit of packet: %d . axi_traffic_gen_mem %h and mem %h",selected_vc,i + packet_num[selected_vc] ,axi_traffic_gen_mem[selected_vc][i + packet_num[selected_vc]],mem[selected_vc][i]);
          $display("footer_valid is %b and footer_ready %b", exa.footer_valid, exa.footer_ready);
          $display("time is %t",$time);
         // $stop();    
        end
      end
      if( axi_traffic_gen_mem[selected_vc][17 + packet_num[selected_vc]] != exa.data)begin
        $display("error at footer!! vc: %d . axi_traffic_gen_mem %h and exa.data %h",selected_vc,axi_traffic_gen_mem[selected_vc][17 + packet_num[selected_vc]],exa.data);
        //$stop();
      end
    end
  end


endmodule
