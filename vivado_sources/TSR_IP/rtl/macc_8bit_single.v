`timescale 1ns / 1ps

module macc_8bit_single #(
    parameter NUM_INPUTS = 20
)(
    o_data,
    o_valid,
    i_data_a,
    i_data_b,
    i_valid,
    clk,
    rst_n
);

    localparam ADDER_LAYERS      = $clog2(NUM_INPUTS);
    localparam OUTPUT_DATA_WIDTH = 17 + ADDER_LAYERS; //FIXME: 16

    output [OUTPUT_DATA_WIDTH-1:0] o_data;
    output                         o_valid;
    input  [8*NUM_INPUTS-1:0]      i_data_a;
    input  [8*NUM_INPUTS-1:0]      i_data_b;
    input                          i_valid;
    input                          clk;
    input                          rst_n;

    genvar i;

    // Multipliers stage
    reg [17*NUM_INPUTS-1:0] mult_data_out; //FIXME:16
    reg                     mult_valid_o;

    always @ (posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            mult_valid_o <= 1'b0;
        end
        else begin
            mult_valid_o <= i_valid;
        end
    end

    generate
        for (i = 0; i < NUM_INPUTS; i = i + 1) begin : gen0
            wire [16:0] mult; //FIXME: 15

            always @ (posedge clk) begin
                if (i_valid) begin
                    mult_data_out[(i+1)*17-1:i*17] <= mult; //FIXME:16
                end
            end

            mult_8bit_single u_mult (
                .y (mult),
                .a (i_data_a[(i+1)*8-1:i*8]),
                .b ({1'b0,i_data_b[(i+1)*8-1:i*8]})
            );
        end
    endgenerate

    // Adder tree
    adder_tree #(
        .DATA_WIDTH (17), //FIXME:16
        .NUM_INPUTS (NUM_INPUTS)
    ) u_adder_tree (
        .o_data     (o_data),
        .o_valid    (o_valid),
        .i_data     (mult_data_out),
        .i_valid    (mult_valid_o),
        .clk        (clk),
        .rst_n      (rst_n)
    );

endmodule

(* use_dsp = "yes" *) module mult_8bit_single (
    output signed [16:0] y,
    input  signed [7:0] a,
    input  signed [8:0] b
);
    assign y = a * b;

endmodule
