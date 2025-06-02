`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/08/2024 05:17:03 PM
// Design Name: 
// Module Name: fc
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


module fc   #(
            parameter IN_CHANNEL            = 64,
            parameter OUT_CHANNEL           = 43,
            parameter KERNEL_0              = 1,
            parameter KERNEL_1              = 1, 
            parameter KERNEL_BASE_ADDR      = 53528,  // Num kernel: 2752
            parameter BIAS_BASE_ADDR        = 56628,  // Num bias: 43
            parameter MACC_COEFF_BASE_ADDR  = 56680,
            parameter LAYER_SCALE_BASE_ADDR = 56672
            )
            (
            o_data,
            o_valid,
            fifo_rd_en,
            i_data,
            i_valid,
            fifo_almost_full,
            weight_wr_data,
            weight_wr_addr,
            weight_wr_en,
            clk,
            rst_n
            );
      
            output [8*OUT_CHANNEL-1:0]                 o_data;
            output                                     o_valid;
            output                                     fifo_rd_en;
            input  [8*IN_CHANNEL-1:0]                  i_data;
            input                                      i_valid;
            input                                      fifo_almost_full;
            input  [15:0]                              weight_wr_data;
            input  [31:0]                              weight_wr_addr;
            input                                      weight_wr_en;
            input                                      clk;
            input                                      rst_n;

    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Weight ram write logic
    //FIXME Wrong RAM Write order
    // Kernel
    localparam NUM_KERNEL_WEIGHTS = IN_CHANNEL * OUT_CHANNEL;
    localparam QUOTIENT_WIDTH     = OUT_CHANNEL > IN_CHANNEL ? $clog2(OUT_CHANNEL) : $clog2(IN_CHANNEL);

    wire [31:0]                 kernel_addr     = weight_wr_addr - KERNEL_BASE_ADDR;
    wire [QUOTIENT_WIDTH*2-1:0] kernel_addr_adj = kernel_addr[QUOTIENT_WIDTH*2-1:0];
    wire                        kernel_wr_en    = weight_wr_en && weight_wr_addr >= KERNEL_BASE_ADDR && weight_wr_addr < KERNEL_BASE_ADDR + NUM_KERNEL_WEIGHTS;

    wire [QUOTIENT_WIDTH-1:0]         kernel_ram_addr;
    wire [QUOTIENT_WIDTH-1:0]         kernel_word_en_num;
    wire [7:0]                        kernel_wr_data;
    wire                              kernel_ram_wr_en_;
    wire [OUT_CHANNEL-1:0] kernel_ram_wr_en = kernel_ram_wr_en_ ? 1 << kernel_word_en_num : 0;

    kernel_write_assist #(
        .DIVIDEND_WIDTH (QUOTIENT_WIDTH * 2),
        .DIVISOR        (IN_CHANNEL),
        .DATA_WIDTH     (8)
    ) u_kernel_w (
        .quotient       (kernel_word_en_num),
        .remainder      (kernel_ram_addr),
        .o_data         (kernel_wr_data),
        .o_valid        (kernel_ram_wr_en_),
        .dividend       (kernel_addr_adj),
        .i_data         (weight_wr_data[7:0]),
        .i_valid        (kernel_wr_en),
        .clk            (clk),
        .rst_n          (rst_n)
    );

    // Bias
    wire [31:0]                    bias_wr_addr_ = weight_wr_addr - BIAS_BASE_ADDR;
    wire [$clog2(OUT_CHANNEL)-1:0] bias_wr_addr  = bias_wr_addr_[$clog2(OUT_CHANNEL)-1:0];
    wire                           bias_wr_en    = weight_wr_en && weight_wr_addr >= BIAS_BASE_ADDR && weight_wr_addr < BIAS_BASE_ADDR + OUT_CHANNEL;

    //////////////////////////////////////////////////////////////////////////////////////////////////////////

    // Controller
    wire cnt_en;
    wire cnt_limit;

    pe_controller u_control (
        .cnt_en    (cnt_en),
        .pe_ready  (pe_ready),
        .pe_ack    (pe_ack),
        .cnt_limit (cnt_limit),
        .i_valid   (i_valid),
        .clk       (clk),
        .rst_n     (rst_n)
    );
    assign fifo_rd_en = pe_ready; 
    // Input registers
    reg  [8-1:0] i_data_reg[0:IN_CHANNEL-1];
    wire [8-1:0] i_data_reg_in[0:IN_CHANNEL-1];

    genvar j,i;
    generate
        wire [8*IN_CHANNEL-1:0] input_pt = i_data[8*IN_CHANNEL-1:0];
        for (j = 0; j < IN_CHANNEL; j = j + 1) begin : gen1
                assign i_data_reg_in[j][7:0] = input_pt[(j+1)*8-1:j*8];
            end

        for (i = 0; i < IN_CHANNEL; i = i + 1) begin : gen2
            always @ (posedge clk) begin
                if (pe_ack) begin
                    i_data_reg[i] <= i_data_reg_in[i];
                end
                else if (cnt_en) begin
                    i_data_reg[i] <= i == IN_CHANNEL - 1 ? i_data_reg[i] : i_data_reg[i+1];
                end
            end
        end
    endgenerate

    // Kernel ram
    wire [8*OUT_CHANNEL-1:0] kernel;
    reg  [$clog2(IN_CHANNEL)-1:0]       kernel_cnt;

    assign cnt_limit = kernel_cnt == IN_CHANNEL - 1;

    always @ (posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            kernel_cnt <= 0;
        end
        else if (cnt_en) begin
            kernel_cnt <= cnt_limit ? 0 : kernel_cnt + 1;
        end
    end

    block_ram_multi_word #(
        .DATA_WIDTH      (8),
        .DEPTH           (IN_CHANNEL),
        .NUM_WORDS       ( OUT_CHANNEL),
        .RAM_STYLE       ("auto"),
        .OUTPUT_REGISTER ("true")
    ) u_kernel (
        .rd_data         (kernel),
        .wr_data         (kernel_wr_data),
        .rd_addr         (kernel_cnt),
        .wr_addr         (kernel_ram_addr[$clog2(IN_CHANNEL)-1:0]),
        .wr_en           (kernel_ram_wr_en),
        .rd_en           (1'b1),
        .clk             (clk)
    );

    // Bias ram
    reg [15:0] bias_ram[0:OUT_CHANNEL-1];

    always @ (posedge clk) begin
        if (bias_wr_en) begin
            bias_ram[bias_wr_addr] <= weight_wr_data;
        end
    end

    // MACC co-efficient reg
    reg signed [15:0] macc_coeff;

    always @ (posedge clk) begin
        if (weight_wr_en && weight_wr_addr == MACC_COEFF_BASE_ADDR) begin
            macc_coeff <= weight_wr_data;
        end
    end

    // MACC and later stages valid
    reg  macc_valid_i;
    wire macc_valid_o;
    reg  macc_valid_o_reg;
    reg  coeff_valid;

    always @ (posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            macc_valid_i <= 1'b0;
            macc_valid_o_reg <= 1'b0;
            coeff_valid <= 1'b0;
        end
        else begin
            macc_valid_i <= cnt_en;
            macc_valid_o_reg <= macc_valid_o;
            coeff_valid <= macc_valid_o_reg;
        end
    end

    ////////////////////////////////////////////////////////////////////////////////////////////////

    // BRAM output pipeline register because Vivado won't stop screaming about it
    reg [8-1:0]            i_data_reg_pipeline;
    reg                    macc_valid_i_pipeline;

    always @ (posedge clk) begin
        if (macc_valid_i) begin
            i_data_reg_pipeline <= i_data_reg[0];
        end
    end

    always @ (posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            macc_valid_i_pipeline <= 1'b0;
        end
        else begin
            macc_valid_i_pipeline <= macc_valid_i;
        end
    end

    ////////////////////////////////////////////////////////////////////////////////////////////////

    // In channel counter
    reg [$clog2(IN_CHANNEL)-1:0] in_cha_cnt;
    wire                         in_cha_cnt_limit = in_cha_cnt == IN_CHANNEL - 1;

    always @ (posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            in_cha_cnt <= 0;
        end
        else if (macc_valid_o_reg) begin
            in_cha_cnt <= in_cha_cnt_limit ? 0 : in_cha_cnt + 1;
        end
    end

    // Bias accum valid
    reg accum_in_sel;
    reg bias_valid_0;
    reg bias_valid_1;

    always @ (posedge clk) begin
        accum_in_sel <= macc_valid_o_reg && in_cha_cnt == 0;
    end

    always @ (posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            bias_valid_0 <= 1'b0;
            bias_valid_1 <= 1'b0;
        end
        else begin
            bias_valid_0 <= macc_valid_o_reg && in_cha_cnt_limit;
            bias_valid_1 <= bias_valid_0;
        end
    end

    // Layer scale reg
    wire signed [15:0] layer_scale;
    wire               bias_sum_trunc_valid;
    wire               dequant_valid;

    // MACC
    localparam MACC_OUTPUT_DATA_WIDTH = 16;

    wire [MACC_OUTPUT_DATA_WIDTH*OUT_CHANNEL-1:0] macc_data_out;

    macc_8bit_single_1_to_n #(
        .NUM_INPUTS   (1),
        .NUM_MACC     (OUT_CHANNEL)
    ) u_macc (
        .o_data       (macc_data_out),
        .o_valid      (macc_valid_o),
        .input_n      (kernel),
        .input_common (i_data_reg_pipeline),
        .i_valid      (macc_valid_i_pipeline),
        .clk          (clk),
        .rst_n        (rst_n)
    );

    generate
        for (i = 0; i < OUT_CHANNEL; i = i + 1) begin : gen4
            // MACC output reg
            reg signed [MACC_OUTPUT_DATA_WIDTH-1:0] macc_data_out_reg;

            always @ (posedge clk) begin
                if (macc_valid_o) begin
                    macc_data_out_reg <= macc_data_out[(i+1)*MACC_OUTPUT_DATA_WIDTH-1:i*MACC_OUTPUT_DATA_WIDTH];
                end
            end

            // MACC co-efficient
            reg signed [MACC_OUTPUT_DATA_WIDTH+16-1:0] coeff_prod;

            always @ (posedge clk) begin
                if (macc_valid_o_reg) begin
                    coeff_prod <= macc_coeff * macc_data_out_reg;
                end
            end

            // In channel accum / bias //16
            //FIXME
            localparam BIAS_SUM_WIDTH = MACC_OUTPUT_DATA_WIDTH + 16 + IN_CHANNEL;

            reg signed [BIAS_SUM_WIDTH-1:0] bias_sum;
            //define bias formatf, confirm the accum_in + coeff_prod first
            wire signed [BIAS_SUM_WIDTH-1:0] accum_in = accum_in_sel ? {{BIAS_SUM_WIDTH-10{bias_ram[i][15]}}, bias_ram[i], {10{1'b0}}} : bias_sum;

            always @ (posedge clk) begin
                //FIXMEbias_sum <= coeff_prod + accum_in;
                bias_sum <= coeff_prod + accum_in;
                
            end

            assign o_data[(i+1)*8-1:i*8] = bias_sum[23:16] + (bias_sum[15] & |bias_sum[14:12]); //FIXME
            assign o_valid = bias_valid_1;
            end            
    endgenerate

endmodule
       
