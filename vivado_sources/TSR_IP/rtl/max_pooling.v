`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/10/2024 09:19:24 PM
// Design Name: 
// Module Name: max_pooling
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


module max_pooling #(
    parameter DATA_WIDTH    = 8,
    parameter IN_WIDTH      = 32,
    parameter IN_HEIGHT     = 32,
    parameter IN_CHANNEL    = 3,
    parameter KERNEL_0      = 2,
    parameter KERNEL_1      = 2,
    parameter DILATION_0    = 1,
    parameter DILATION_1    = 1, 
    parameter PADDING_0     = 0,
    parameter PADDING_1     = 0,    
    parameter STRIDE_0      = 2,
    parameter STRIDE_1      = 2
    )(
    o_data,
    o_valid,
    fifo_rd_en, 
    i_data,
    i_valid,
    fifo_almost_full,
    clk,
    rst_n
    );
    localparam OUT_CHANNEL = IN_CHANNEL; 
    output [DATA_WIDTH*OUT_CHANNEL-1:0]     o_data;
    output                                  o_valid; 
    output                                  fifo_rd_en; 
    input  [DATA_WIDTH*IN_CHANNEL-1:0]      i_data;
    input                                   i_valid; 
    input                                   fifo_almost_full; 
    input                                   clk;
    input                                   rst_n;   
    localparam CNT_WIDTH = $clog2(IN_WIDTH)  + (PADDING_1 > 0 ? 2 : 1);
    localparam COUNTER_MAX   = OUT_CHANNEL;
    localparam CROP_PIXEL    = ((IN_WIDTH + 2*PADDING_0 - DILATION_0*(KERNEL_0-1)-1)%(STRIDE_0));
    localparam LB_IN_WIDTH   = CROP_PIXEL ? IN_WIDTH - 1 : IN_WIDTH;
    localparam LB_IN_HEIGHT   = CROP_PIXEL ? IN_WIDTH - 1 : IN_WIDTH;
    genvar i; 
    reg o_valid_reg;
    // Line buffer
    wire [8*KERNEL_0*KERNEL_1*IN_CHANNEL-1:0] line_buffer_data;
    wire                                      line_buffer_valid;
    wire [CNT_WIDTH-1:0]                      row_cnt,col_cnt;
    reg  [CNT_WIDTH-1:0]                      row_crop_px_r,col_crop_px_r;
    wire                                      row_crop_px_limit_r = row_crop_px_r == IN_HEIGHT + PADDING_0 - 1;
    wire                                      col_crop_px_limit_r = col_crop_px_r == IN_WIDTH + PADDING_0 - 1;
    wire row_crop_px, col_crop_px, crop_px;
    wire ln_buffer_fifo_rd_en, ln_buffer_i_valid;//, safety_lock;
    always @ (posedge clk or negedge rst_n) begin
        if(!rst_n) begin 
            row_crop_px_r <= 0; 
        end
        else begin 
            if(i_valid && col_crop_px_limit_r) begin 
            // Register the condition
                if(row_crop_px_limit_r) begin
                    row_crop_px_r <= 0;
                end
                else begin 
                    row_crop_px_r <= row_crop_px_r+1;
                end
            end
        end
     end
     
    always @ (posedge clk or negedge rst_n) begin
        if(!rst_n) begin 
            col_crop_px_r <= 0; 
        end
        else begin 
            if(i_valid) begin 
            // Register the condition
                if(col_crop_px_limit_r) begin
                    col_crop_px_r <= 0;
                end
                else begin 
                    col_crop_px_r <= col_crop_px_r+1;
                end
            end
        end
     end   

     assign crop_px =  CROP_PIXEL ? (row_crop_px | col_crop_px ) : 0;
     assign ln_buffer_i_valid = (crop_px ) ? 0 : i_valid; 
     assign fifo_rd_en = crop_px ? 1 : ln_buffer_fifo_rd_en; 
    //wire crop_px = if pixel is leftover -> crop_px = 0 (define when pixel is left_over, dump signal, config line_buffer as leftover case) //FIXME
    //wire lb_i_valid = i_valid && crop_px; 
     generate 
        if (CROP_PIXEL) begin 
                assign row_crop_px = (row_crop_px_r == IN_WIDTH - 1 && i_valid) ? 1 : 0 ; //replace with external counters
                assign col_crop_px = (col_crop_px_r == IN_HEIGHT - 1 && i_valid) ? 1 : 0;
                assign crop_px =  row_crop_px | col_crop_px;
                assign ln_buffer_i_valid = (crop_px ) ? 0 : i_valid; 
                assign fifo_rd_en = crop_px ? 1 : ln_buffer_fifo_rd_en; 
                /*reg [7:0] frame_cnt;
                always @ (posedge clk or negedge rst_n) begin 
                    if(!rst_n) begin 
                        frame_cnt <= 0;  
                    end
                    else begin 
                        if(fifo_rd_en) begin 
                            frame_cnt <= frame_cnt + 1; 
                        end
                        else if(frame_cnt == IN_WIDTH * IN_HEIGHT) begin
                            frame_cnt <= 0; 
                        end
                    end
                end
                */
        end
        else begin 
            assign ln_buffer_i_valid = i_valid;
            assign fifo_rd_en = ln_buffer_fifo_rd_en;  
        end
     endgenerate
    line_buffer#(
        .DATA_WIDTH       (8),
        .IN_CHANNEL       (IN_CHANNEL),
        .IN_WIDTH         (LB_IN_WIDTH), //config this
        .IN_HEIGHT        (LB_IN_HEIGHT), //config this
        .KERNEL_0         (KERNEL_0),
        .KERNEL_1         (KERNEL_1),
        .DILATION_0       (DILATION_0),
        .DILATION_1       (DILATION_1),
        .PADDING_0        (PADDING_0),
        .PADDING_1        (PADDING_1),
        .STRIDE_0         (STRIDE_0),
        .STRIDE_1         (STRIDE_1)
    ) u_line_buffer (
        .o_data           (line_buffer_data),
        .o_valid          (line_buffer_valid),
        .fifo_rd_en       (ln_buffer_fifo_rd_en),
        .i_data           (i_data),
        .i_valid          (ln_buffer_i_valid),
        .fifo_almost_full (fifo_almost_full),
        .pe_ready         (pe_ready),
        .pe_ack           (pe_ack),
        .clk              (clk),
        .rst_n            (rst_n),
        .dump_col_cnt     (col_cnt),
        .dump_row_cnt     (row_cnt)
    );
    

    
    //Max-pooling calculation
    reg [8*IN_CHANNEL-1:0] mp_data_out;

    generate
        for (i = 0; i < IN_CHANNEL; i = i + 1) begin : gen0
            wire [7:0] max;

            always @ (posedge clk) begin
                if (line_buffer_valid) begin
                    mp_data_out[(i+1)*8-1:i*8] <= max;
                end
            end
            max_comp #(.DATA_WIDTH(DATA_WIDTH)) mp (
                        .o_data(max),
                        .i_data_00(line_buffer_data[(i+1)*8-1:i*8]),
                        .i_data_01(line_buffer_data[(i+1+IN_CHANNEL)*8-1:(i+IN_CHANNEL)*8]),
                        .i_data_10(line_buffer_data[(i+1+2*IN_CHANNEL)*8-1:(i+2*IN_CHANNEL)*8]),
                        .i_data_11(line_buffer_data[(i+1+3*IN_CHANNEL)*8-1:(i+3*IN_CHANNEL)*8])
            );
        end
    endgenerate

       // o_valid
    reg [$clog2(COUNTER_MAX)-1:0] cha_cnt;
    reg valid_fired;

    always @ (posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            cha_cnt <= 0;
        end
        else if (line_buffer_valid) begin
            if(!valid_fired) begin 
                cha_cnt <= cha_cnt == COUNTER_MAX - 1 ? 0 : cha_cnt + 1;
            end
            else cha_cnt <= 0; 
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_fired <= 1'b0;
        end else if (!line_buffer_valid) begin
            valid_fired <= 1'b0; // reset flag when valid deasserts
        end else if ((cha_cnt == COUNTER_MAX - 1) && line_buffer_valid) begin
            valid_fired <= 1'b1; // mark as fired once condition is met
        end
    end
    
    // o_valid logic: only fire once per valid burst
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            o_valid_reg <= 1'b0;
    end else begin
            o_valid_reg <= ((cha_cnt == COUNTER_MAX - 1) && line_buffer_valid && !valid_fired);
    end
    end
    assign o_valid = o_valid_reg;
    //reg o_valid_reg;
    //
    //always @ (posedge clk or negedge rst_n) begin
    //    if (~rst_n) begin
    //        o_valid_reg <= 1'b0;
    //    end
    //    else begin
    //        o_valid_reg <= cha_cnt == COUNTER_MAX - 1 && line_buffer_valid;
    //    end
    //end
    
    //assign o_valid = o_valid_reg;
    assign o_data = mp_data_out;
endmodule
