`timescale 1ns / 1ps

module top_tsr #(
    parameter AXI_ADDR_WIDTH = $clog2('h9_0000 + 1)
)(
    output                          o_valid,
    output      [6-1:0]             o_data,
    output                          weight_load_done,
    output                          busy,
    //output                          wready,
    output reg [63:0]               axi_rd_data,
    input      [63:0]               axi_wr_data,
    input      [AXI_ADDR_WIDTH-1:0] axi_wr_addr,
    input      [AXI_ADDR_WIDTH-1:0] axi_rd_addr,    
    input                           axi_wr_en,
    input                           axi_rd_en,
    input      [7:0]                axi_wr_strobe,
    input                           clk,
    input                           rst_n
);

    genvar i;

    // IP params
    localparam IN_WIDTH    = 32;
    localparam IN_HEIGHT   = 32;
    localparam NUM_WEIGHTS = 56690;
    localparam OUT_WIDTH   = 1;
    localparam OUT_HEIGHT  = 1;

    // AXI addr map
    localparam OFFSET_INPUT  = 0;                                       // 0x0000_0000 ###
    localparam OFFSET_OUTPUT = IN_WIDTH * IN_HEIGHT * 3;                // 0x0000_0C00 ###
    localparam OFFSET_OVALID = OFFSET_OUTPUT + OUT_WIDTH * OUT_HEIGHT;  // 0x0000_0C01 ###
    localparam OFFSET_BUSY   = OFFSET_OVALID + 8;                       // 0x0000_0C09 ###
    localparam OFFSET_RESET  = OFFSET_BUSY + 8;                         // 0x0000_0C11 ###
    localparam OFFSET_WEIGHT = OFFSET_RESET + 8;                        // 0x0000_0C19 ###
                                                                        // HIGH_ADDR: 0x0008_5C60 ###
    localparam OFFSET_CLOCK_CNT = 'h0009_0000;

    // Soft reset
    reg  [3:0] soft_reset_count;
    wire       internal_reset_n = soft_reset_count == 0 && rst_n;
    wire        fifo_weight_empty;
    
    always @ (posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            soft_reset_count <= 0;
        end
    //FIXME
    /*
        else if (soft_reset_count == 0) begin
            if (axi_wr_en && axi_wr_strobe[0] && axi_wr_data[0] && axi_wr_addr == OFFSET_RESET) begin
                soft_reset_count <= soft_reset_count + 1;
            end
            else begin
                soft_reset_count <= soft_reset_count;
            end
        end
        else begin
            soft_reset_count <= soft_reset_count + 1;
        end
    */
    end

    // Input FIFO
    reg  [8*8-1:0] fifo_input_wr_data;
    reg            fifo_input_wr_en;
    wire [8*8-1:0] fifo_input_rd_data;
    wire           fifo_input_empty;
    wire           fifo_input_rd_en;
    wire           fifo_input_almost_full;

    generate
        for (i = 0; i < 8; i = i + 1) begin : gen0
           wire [7:0] fifo_input_wr_data_next =
        (axi_wr_addr < OFFSET_OUTPUT) &&   // address in range
         axi_wr_en                    &&   // write request
        |axi_wr_strobe                     // strobe inactive
         ? axi_wr_data[i*8 +: 8]           // new data from AXI
         : fifo_input_wr_data[i*8 +: 8];   // hold old value
         
            always @ (posedge clk /*or axi_wr_en*/) begin
                //if (axi_wr_addr < OFFSET_OUTPUT && axi_wr_en && |axi_wr_strobe) begin
                    //fifo_input_wr_data[(i+1)*8-1:i*8] <= axi_wr_data[(i+1)*8-1:i*8];
                    fifo_input_wr_data[(i+1)*8-1:i*8] <= fifo_input_wr_data_next;
                    //fifo_input_wr_data[(i+1)*7-1:i*7] <= axi_wr_data[(i+1)*8-1:i*8+1];
                //end
            end
        end
    endgenerate
    wire fifo_input_wr_en_nxt =
        (axi_wr_addr < OFFSET_OUTPUT) &&   // address range
        axi_wr_en                         &&   // write strobe from AXI
       |axi_wr_strobe                     &&   // byte-level strobe must be low
        fifo_weight_empty;                    // FIFO empty flag*/
    always @ (posedge clk or negedge internal_reset_n /*or axi_wr_en*/) begin
        if (~internal_reset_n) begin
            fifo_input_wr_en <= 1'b0;
        end
        else begin
            //fifo_input_wr_en = fifo_input_wr_en_nxt;
            fifo_input_wr_en <= axi_wr_addr < OFFSET_OUTPUT && axi_wr_en && |axi_wr_strobe  && fifo_weight_empty;
        end
    end
    fifo_single_read #(
        .DATA_WIDTH        (8 * 8),
        .DEPTH             (384),
        .ALMOST_FULL_THRES (380)
    ) u_fifo_input (
        .rd_data           (fifo_input_rd_data),
        .empty             (fifo_input_empty),
        .full              (),
        .almost_full       (fifo_input_almost_full),
        .wr_data           (fifo_input_wr_data),
        .wr_en             (fifo_input_wr_en),
        .rd_en             (fifo_input_rd_en),
        .rst_n             (internal_reset_n),
        .clk               (clk)
    );

    // Input FIFO translate
    wire [63:0] fifo_input_rd_data_pad;
    wire [23:0] model_i_data;
    wire        model_fifo_empty;
    wire        model_fifo_rd_en;

    generate
        for (i = 0; i < 8; i = i + 1) begin : gen1
            assign fifo_input_rd_data_pad[(i+1)*8-1:i*8] = {fifo_input_rd_data[(i+1)*8-1:i*8]};
        end
    endgenerate

    fifo_64bits_to_fifo_24bits_input u_translate_input (
        .o_data       (model_i_data),
        .o_empty      (model_fifo_empty),
        .o_fifo_rd_en (fifo_input_rd_en),
        .i_data       (fifo_input_rd_data_pad),
        .i_empty      (fifo_input_empty),
        .i_fifo_rd_en (model_fifo_rd_en),
        .clk          (clk),
        .rst_n        (internal_reset_n)
    );

    // First pixel
    reg [$clog2(IN_WIDTH*IN_HEIGHT)-1:0] pixel_cnt;

    always @ (posedge clk or negedge internal_reset_n) begin
        if (~internal_reset_n) begin
            pixel_cnt <= 0;
        end
        else if (model_fifo_rd_en) begin
            pixel_cnt <= pixel_cnt == IN_HEIGHT * IN_WIDTH - 1 ? 0 : pixel_cnt + 1;
        end
    end

    wire first_pixel = pixel_cnt == 0 && model_fifo_rd_en;

    // Weight FIFO
    wire [63:0] fifo_weight_rd_data;

    wire        fifo_weight_rd_en;
    wire        fifo_weight_almost_full;

    fifo_single_read #(
        .DATA_WIDTH        (64),
        .DEPTH             (32768),
        .ALMOST_FULL_THRES (4096)
    ) u_fifo_weight (
        .rd_data           (fifo_weight_rd_data),
        .empty             (fifo_weight_empty),
        .full              (),
        .almost_full       (fifo_weight_almost_full),
        .wr_data           (axi_wr_data),
        .wr_en             (axi_wr_addr >= OFFSET_WEIGHT && axi_wr_addr < OFFSET_WEIGHT + NUM_WEIGHTS * 2 && axi_wr_en && |axi_wr_strobe ),
        .rd_en             (fifo_weight_rd_en),
        .rst_n             (internal_reset_n),
        .clk               (clk)
    );
    reg         weight_load_r;
    always @ (posedge clk or negedge internal_reset_n) begin
        if(!internal_reset_n) begin 
            weight_load_r <= 0;
        end
        else if(fifo_weight_rd_en) begin 
            weight_load_r <= 1;
        end
    end
    assign weight_load_done = weight_load_r & fifo_weight_empty;
    // Weight FIFO translate
    wire [15:0] weight_wr_data;
    wire [31:0] weight_wr_addr;
    wire        weight_wr_en;

    fifo_64bits_to_mem_16bits_weight #(
        .NUM_WEIGHTS    (NUM_WEIGHTS)
    ) u_translate_weight (
        .weight_wr_data (weight_wr_data),
        .weight_wr_addr (weight_wr_addr),
        .weight_wr_en   (weight_wr_en),
        .fifo_rd_en     (fifo_weight_rd_en),
        .fifo_rd_data   (fifo_weight_rd_data),
        .fifo_empty     (fifo_weight_empty),
        .clk            (clk),
        .rst_n          (internal_reset_n)
    );

    // Weight pipeline registers
    reg [15:0] weight_wr_data_pipeline [0:1];
    reg [31:0] weight_wr_addr_pipeline [0:1];
    reg [0:0]  weight_wr_en_pipeline   [0:1];

    generate
        for (i = 0; i < 2; i = i + 1) begin : gen2
            wire [15:0] wr_data;
            wire [31:0] wr_addr;
            wire [0:0]  wr_en;

            if (i == 0) begin : gen3
                assign wr_data = weight_wr_data;
                assign wr_addr = weight_wr_addr;
                assign wr_en   = weight_wr_en;
            end
            else begin : gen4
                assign wr_data = weight_wr_data_pipeline[i-1];
                assign wr_addr = weight_wr_addr_pipeline[i-1];
                assign wr_en   = weight_wr_en_pipeline[i-1];
            end

            always @ (posedge clk) begin
                if (wr_en) begin
                    weight_wr_data_pipeline[i] <= wr_data;
                    weight_wr_addr_pipeline[i] <= wr_addr;
                end
            end

            always @ (posedge clk or negedge internal_reset_n) begin
                if (~internal_reset_n) begin
                    weight_wr_en_pipeline[i] <= 1'b0;
                end
                else begin
                    weight_wr_en_pipeline[i] <= wr_en;
                end
            end
        end
    endgenerate
    wire o_valid_ip;
    wire dump_o_valid, last_valid;
    // Model
    tsr_model   DUT (
                    .o_data(o_data), 
                    .o_valid(o_valid_ip),
                    .fifo_rd_en(model_fifo_rd_en),
                    .i_data(model_i_data),
                    .i_valid(~model_fifo_empty),
                    .almost_full(0),
                    .weight_wr_data(weight_wr_data_pipeline[1]),
                    .weight_wr_addr(weight_wr_addr_pipeline[1]),
                    .weight_wr_en(weight_wr_en_pipeline[1]),
                    .clk(clk),
                    .rst_n(internal_reset_n),
                    .dump_o_valid(dump_o_valid)
                    //add dump o_valid of line buffter
                    );
    // busy
    reg internal_busy;
    reg o_valid_r;
    always @(posedge clk or negedge internal_reset_n) begin 
        if(!internal_reset_n) begin 
            o_valid_r <= 0; 
        end
        else if(o_valid_ip) begin 
            o_valid_r <= 1; 
        end
        else if(o_valid) begin 
            o_valid_r <= 0; 
        end
    end
    //assign busy = internal_busy & ~o_valid; //FIXME: cnt_en in pe_incha_single
    assign busy = ~model_fifo_empty | o_valid_r;
    assign o_valid = o_valid_r & dump_o_valid; 
    always @ (posedge clk or negedge internal_reset_n) begin
        if (~internal_reset_n) begin
            internal_busy <= 1'b0;
        end
        else if (internal_busy == 1'b0 && first_pixel == 1'b1) begin
            internal_busy <= 1'b1;
        end
        else if (internal_busy == 1'b1 && pixel_cnt == IN_HEIGHT * IN_WIDTH - 1 && model_fifo_rd_en) begin
            internal_busy <= 1'b0;
        end
    end
/*
    // Output FIFOs
    wire [16*NUM_LANES-1:0] cls_fifo_rd_data;
    wire                    cls_fifo_empty;
    wire                    cls_fifo_rd_en;

    fifo_single_read #(
        .DATA_WIDTH        (16 * NUM_LANES),
        .DEPTH             (OUT_WIDTH * 1),
        .ALMOST_FULL_THRES (10)
    ) u_fifo_cls (
        .rd_data           (cls_fifo_rd_data),
        .empty             (cls_fifo_empty),
        .full              (),
        .almost_full       (cls_fifo_almost_full),
        .wr_data           (model_o_data_cls),
        .wr_en             (model_o_valid_cls),
        .rd_en             (cls_fifo_rd_en),
        .rst_n             (internal_reset_n),
        .clk               (clk)
    );

    wire [16*NUM_LANES-1:0] vertical_fifo_rd_data;
    wire                    vertical_fifo_empty;
    wire                    vertical_fifo_rd_en;

    fifo_single_read #(
        .DATA_WIDTH        (16 * NUM_LANES),
        .DEPTH             (OUT_HEIGHT),
        .ALMOST_FULL_THRES (10)
    ) u_fifo_vertical (
        .rd_data           (vertical_fifo_rd_data),
        .empty             (vertical_fifo_empty),
        .full              (),
        .almost_full       (vertical_fifo_almost_full),
        .wr_data           (model_o_data_vertical),
        .wr_en             (model_o_valid_vertical),
        .rd_en             (vertical_fifo_rd_en),
        .rst_n             (internal_reset_n),
        .clk               (clk)
    );

    // Post process
    wire [7:0]                              bram_wr_data;
    wire [$clog2(OUT_WIDTH*OUT_HEIGHT)-1:0] bram_wr_addr;
    wire                                    bram_wr_en;

    post_process #(
        .OUT_WIDTH           (OUT_WIDTH),
        .OUT_HEIGHT          (OUT_HEIGHT),
        .NUM_LANES           (NUM_LANES),
        .DATA_WIDTH          (16),
        .FRAC_BITS           (8)
    ) u_post (
        .bram_wr_data        (bram_wr_data),
        .bram_wr_addr        (bram_wr_addr),
        .bram_wr_en          (bram_wr_en),
        .fifo_rd_en_cls      (cls_fifo_rd_en),
        .fifo_rd_en_vertical (vertical_fifo_rd_en),
        .o_valid             (o_valid),
        .i_data_cls          (cls_fifo_rd_data),
        .i_data_vertical     (vertical_fifo_rd_data),
        .i_valid_cls         (~cls_fifo_empty),
        .i_valid_vertical    (~vertical_fifo_empty),
        .first_pixel         (first_pixel),
        .clk                 (clk),
        .rst_n               (internal_reset_n)
    );

    // Post process BRAM
    wire [63:0]               bram_rd_data;
    wire [AXI_ADDR_WIDTH-1:0] bram_rd_addr      = axi_rd_addr - OFFSET_OUTPUT;
    wire                      bram_within_range = axi_rd_addr >= OFFSET_OUTPUT && axi_rd_addr < OFFSET_OUTPUT + OUT_WIDTH * OUT_HEIGHT;
    wire [7:0]                bram_byte_en      = bram_wr_en << bram_wr_addr[2:0];

    block_ram_multi_word #(
        .DATA_WIDTH      (8),
        .DEPTH           (OUT_WIDTH * OUT_HEIGHT / 8),
        .NUM_WORDS       (8),
        .RAM_STYLE       ("auto"),
        .OUTPUT_REGISTER ("false")
    ) u_bram (
        .rd_data         (bram_rd_data),
        .wr_data         (bram_wr_data),
        .rd_addr         (bram_rd_addr[$clog2(OUT_WIDTH*OUT_HEIGHT)-1:3]),
        .wr_addr         (bram_wr_addr[$clog2(OUT_WIDTH*OUT_HEIGHT)-1:3]),
        .wr_en           (bram_byte_en),
        .rd_en           (axi_rd_en & bram_within_range),
        .clk             (clk)
    );

    // Clock counter
    localparam CLOCK_CNT_IDLE = 0;
    localparam CLOCK_CNT_BUSY = 1;

    reg [0:0] clock_cnt_fsm;

    always @ (posedge clk or negedge internal_reset_n) begin
        if (~internal_reset_n) begin
            clock_cnt_fsm <= CLOCK_CNT_IDLE;
        end
        else begin
            case (clock_cnt_fsm)
                CLOCK_CNT_IDLE : clock_cnt_fsm <= first_pixel ? CLOCK_CNT_BUSY : CLOCK_CNT_IDLE;
                CLOCK_CNT_BUSY : clock_cnt_fsm <= o_valid ? CLOCK_CNT_IDLE : CLOCK_CNT_BUSY;
            endcase
        end
    end

    reg [31:0] clock_cnt;

    always @ (posedge clk) begin
        if (clock_cnt_fsm == CLOCK_CNT_IDLE) begin
            clock_cnt <= first_pixel ? 0 : clock_cnt;
        end
        else if (clock_cnt_fsm == CLOCK_CNT_BUSY) begin
            clock_cnt <= o_valid ? clock_cnt : clock_cnt + 1;
        end
    end

    // axi_rd_data
    always @ (*) begin
        case (axi_rd_addr)
            OFFSET_OVALID    : axi_rd_data <= {{63{1'b0}}, o_valid};
            OFFSET_BUSY      : axi_rd_data <= {{63{1'b0}}, busy};
            OFFSET_CLOCK_CNT : axi_rd_data <= {{32{1'b0}}, clock_cnt};
            default          : axi_rd_data <= bram_within_range ? bram_rd_data : {64{1'b0}};
        endcase
    end

    // busy
    reg internal_busy;
    assign busy = internal_busy & ~o_valid;

    always @ (posedge clk or negedge internal_reset_n) begin
        if (~internal_reset_n) begin
            internal_busy <= 1'b0;
        end
        else if (internal_busy == 1'b0 && first_pixel == 1'b1) begin
            internal_busy <= 1'b1;
        end
        else if (internal_busy == 1'b1 && o_valid == 1'b1) begin
            internal_busy <= 1'b0;
        end
    end

    // Write ready
    assign wready = ~(fifo_input_almost_full | fifo_weight_almost_full);
*/
endmodule
