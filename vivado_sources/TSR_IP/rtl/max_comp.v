`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/12/2024 10:39:46 AM
// Design Name: 
// Module Name: max_comp
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



module max_comp #(

            parameter DATA_WIDTH        = 8
    )(
    o_data,
    i_data_00,
    i_data_01,
    i_data_10,
    i_data_11
    );
    output   [DATA_WIDTH-1:0]               o_data;
    input    [DATA_WIDTH-1:0]               i_data_00;
    input    [DATA_WIDTH-1:0]               i_data_01;
    input    [DATA_WIDTH-1:0]               i_data_10;
    input    [DATA_WIDTH-1:0]               i_data_11;
    
    wire     [DATA_WIDTH-1:0]               o_data_00;
    wire     [DATA_WIDTH-1:0]               o_data_01;
    max_comp_2  #(DATA_WIDTH) comp1
                 (
                 .i_data_00(i_data_00),
                 .i_data_01(i_data_01),
                 .o_data   (o_data_00)
                 );
    max_comp_2  #(DATA_WIDTH) comp2
                 (
                 .i_data_00(i_data_10),
                 .i_data_01(i_data_11),
                 .o_data   (o_data_01)
                 );
    max_comp_2  #(DATA_WIDTH) comp3
                 (
                 .i_data_00(o_data_00),
                 .i_data_01(o_data_01),
                 .o_data   (o_data)
                 );
   
    
endmodule

module max_comp_2 #(parameter DATA_WIDTH = 8)  //just compare 2 values since there's only 2x2 maxpooling in model
        (
        input    [DATA_WIDTH-1:0]               i_data_00,
        input    [DATA_WIDTH-1:0]               i_data_01,
        output   [DATA_WIDTH-1:0]               o_data
        );
        assign   o_data = (i_data_00 > i_data_01) ? i_data_00 : i_data_01; 
endmodule     