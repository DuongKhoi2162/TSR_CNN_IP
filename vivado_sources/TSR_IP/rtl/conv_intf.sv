`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/07/2024 09:37:43 AM
// Design Name: 
// Module Name: conv_intf
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


interface conv_intf #(parameter OUTPUT_DATA_WIDTH = 16, OUT_CHANNEL = 40, IN_CHANNEL = 3)(input clk);
    logic [OUTPUT_DATA_WIDTH*OUT_CHANNEL-1:0] o_data;
    logic                                     o_valid;
    logic                                     fifo_rd_en;
    logic  [8*IN_CHANNEL-1:0]                  i_data;
    logic                                      i_valid;
    logic                                      fifo_almost_full;
    logic  [15:0]                              weight_wr_data;
    logic  [31:0]                              weight_wr_addr;
    logic                                      weight_wr_en;
    logic                                      rst_n;
endinterface
