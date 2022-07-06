// =============================================================================
//
//                   Copyright (c) 2019 FORTH-ICS / CARV
//                             All rights reserved
//
// This file contains FORTH proprietary and confidential information and has
// been developed by FORTH-ICS within the EPI-SGA1 Project (GA 826647).
// The permission rights for this file are governed by the EPI Grant Agreement
// and the EPI Consortium Agreement.
//
// ===============================[ INFORMATION ]===============================
//
// Author(s)  : Nikolaos Dimou
// Contact(s) : ndimou@ics.forth.gr
//
// Summary    : fifo
// Created    : XX/XX/2019
// Modified   : 
//
// ===============================[ DESCRIPTION ]===============================
//
// TBA
//
// =============================================================================

module exa_fifo #(
  parameter DEPTH               = 1024,
  parameter DWIDTH              = 32,
  parameter ALL_REGD            = 1,
  parameter DISTURBED           = 1,
  parameter PROG_FULL_ASSERT    = 0,
  parameter PROG_FULL_NEGATE    = 0,
  localparam DEPTH_LOG          = $clog2(DEPTH)

) (
  input   logic               arst_n,
  input   logic               clk,

  input   logic               i_wr_en,
  input   logic [DWIDTH-1:0]  i_wr_data,
  output  logic               o_full,
  output  logic               o_prog_full,
  output  logic [DEPTH_LOG:0] o_wr_words,
  
  input   logic               i_rd_en,
  output  logic [DWIDTH-1:0]  o_rd_data,
  output  logic               o_empty

    );
    
    // memory declaration
    // FIXME place directive for block | distributed if needed
    // FIXME also initializing memeory, that is not correct!
  if (DISTURBED == 1) begin  (* ram_style = "distributed" *) ; end
  logic [DWIDTH-1:0] memory [(1<<$clog2(DEPTH))-1:0] = '{default:0};    
   

  logic [DEPTH_LOG:0] wr_addr_d;
  logic [DEPTH_LOG:0] wr_addr_q;
  logic [DEPTH_LOG:0] rd_addr_d;
  logic [DEPTH_LOG:0] rd_addr_q;
  logic full_d, full_q;
  logic empty_d,empty_q;
     
  logic [DEPTH_LOG:0] wr_words_d;
  assign wr_words_d = DEPTH - wr_addr_d + rd_addr_d;
  
  assign o_wr_words = DEPTH - wr_addr_q + rd_addr_q;
  
  reg prog_full_latch_q;
  always_ff @(posedge clk) begin
    if (~arst_n) begin
      prog_full_latch_q <= 0;
    end
    else begin
      if (wr_words_d == PROG_FULL_ASSERT)
        prog_full_latch_q <= 1;
      else if (wr_words_d == PROG_FULL_NEGATE)
        prog_full_latch_q <= 0;    
    end
  end
  assign o_prog_full = prog_full_latch_q;
    
    
    always_ff @(posedge clk) begin
        if (i_wr_en & ~o_full) begin
            memory[wr_addr_q[DEPTH_LOG-1:0]] <=  i_wr_data;
            //o_rd_data <=  memory[rd_addr_q[DEPTH_LOG-1:0]];
        end    
    end
    assign o_rd_data = memory[rd_addr_q[DEPTH_LOG-1:0]];

    
always_ff @(posedge clk or negedge arst_n) begin
    if (~arst_n) begin
        wr_addr_q <=  0;
        rd_addr_q <=  0;
        empty_q <= 1;
        full_q <= 0;
    end
    else begin
        wr_addr_q <=  wr_addr_d;
        rd_addr_q <=  rd_addr_d;
        empty_q <= empty_d;
        full_q <= full_d;
    end
end

assign wr_addr_d = (i_wr_en & ~o_full) ? wr_addr_q + 1 : wr_addr_q; 
assign rd_addr_d = (i_rd_en & ~o_empty) ? rd_addr_q + 1 : rd_addr_q;
assign empty_d = (wr_addr_d == rd_addr_d);
assign full_d = ({~wr_addr_d[DEPTH_LOG],wr_addr_d[DEPTH_LOG-1:0]}== rd_addr_d);

assign o_full = ALL_REGD ? full_q :
                ({~wr_addr_q[DEPTH_LOG],wr_addr_q[DEPTH_LOG-1:0]}== rd_addr_q);
assign o_empty = ALL_REGD ? empty_q :
                 (wr_addr_q == rd_addr_q);
                 
    
endmodule
