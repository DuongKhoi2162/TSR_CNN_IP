`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/22/2025 05:44:23 PM
// Design Name: 
// Module Name: reg_buffer
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

module reg_buffer #(
    parameter DATA_WIDTH = 8*43
) (
    input                     clk,
    input                     rst_n,
    input                     wr_en,
    input                     rd_en,
    input   [DATA_WIDTH-1:0]  wr_data,
    output  [DATA_WIDTH-1:0]  rd_data,
    output                    empty      // == !valid
);

    //----------------------------------------------------------------------
    // state
    //----------------------------------------------------------------------
    reg        valid_q;   // “has_data”  in the original code
    reg [DATA_WIDTH-1:0] data_q;

    //----------------------------------------------------------------------
    // sequential
    //----------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_q <= 1'b0;
            data_q  <= 0;
        end else begin
            // write path
            if (wr_en) begin
                data_q <= wr_data;
            end

            // valid flag update
            //   • set on write
            //   • clear on read (if no simultaneous write)
            valid_q <= wr_en | (valid_q & ~rd_en);
        end
    end

    //----------------------------------------------------------------------
    // outputs
    //----------------------------------------------------------------------
    assign rd_data = data_q;
    assign empty   = ~valid_q;

endmodule