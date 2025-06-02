`timescale 1ns / 1ps

module tsr_model (
    output [7:0]      o_data,
    output            o_valid,
    output            fifo_rd_en,
    output            dump_o_valid,
    output            last_valid,
    input  [8*3-1:0]  i_data,
    input             i_valid,
    input             almost_full,
    input  [15:0]     weight_wr_data,
    input  [31:0]     weight_wr_addr,
    input             weight_wr_en,
    input             clk,
    input             rst_n
);

    // Conv 0
    wire [8*40-1:0] o_data_0;
    wire o_valid_0;
    wire fifo_almost_full_0;

    conv #(
        .UNROLL_MODE           ("incha"),
        .IN_WIDTH              (32),
        .IN_HEIGHT             (32),
        .OUTPUT_MODE           ("relu"),
        .COMPUTE_FACTOR        ("single"),
        .KERNEL_0              (3),
        .KERNEL_1              (3),
        .PADDING_0             (0),
        .PADDING_1             (0),
        .DILATION_0            (1),
        .DILATION_1            (1),
        .STRIDE_0              (1),
        .STRIDE_1              (1),
        .IN_CHANNEL            (3),
        .OUT_CHANNEL           (40),
        .KERNEL_BASE_ADDR      (0),  // Num kernel: 1080
        .BIAS_BASE_ADDR        (56280),  // Num bias: 40
        .MACC_COEFF_BASE_ADDR  (56671),  // Num macc_coeff: 1
        .LAYER_SCALE_BASE_ADDR ()
    ) u_enc_0 (
        .o_data                (o_data_0),
        .o_valid               (o_valid_0),
        .fifo_rd_en            (fifo_rd_en),
        .i_data                (i_data),
        .i_valid               (i_valid),
        .fifo_almost_full      (1'b0),
        .weight_wr_data        (weight_wr_data),
        .weight_wr_addr        (weight_wr_addr),
        .weight_wr_en          (weight_wr_en),
        .clk                   (clk),
        .rst_n                 (rst_n)

    );
    wire [8*40-1:0] fifo_rd_data_0;
    wire fifo_empty_0;
    wire fifo_rd_en_0;

    fifo_single_read #(
        .DATA_WIDTH        (8 * 40),
        .DEPTH             (60),
        .ALMOST_FULL_THRES (10)
    ) u_fifo_0 (
        .rd_data           (fifo_rd_data_0),
        .empty             (fifo_empty_0),
        .full              (),
        .almost_full       (fifo_almost_full_0),
        .wr_data           (o_data_0),
        .wr_en             (o_valid_0),
        .rd_en             (fifo_rd_en_0),
        .rst_n             (rst_n),
        .clk               (clk)
    );

    // MaxPool 1
    wire [8*40-1:0] o_data_1;
    wire o_valid_1;
    wire fifo_almost_full_1;

    max_pooling #(
        .DATA_WIDTH               (8),
        .IN_WIDTH                 (30),
        .IN_HEIGHT                (30),
        .IN_CHANNEL               (40),
        .PADDING_0                (0),
        .PADDING_1                (0),
        .DILATION_0               (1),
        .DILATION_1               (1),
        .STRIDE_0                 (2),
        .STRIDE_1                 (2)
    ) u_max_1 (
        .o_data                   (o_data_1),
        .o_valid                  (o_valid_1),
        .fifo_rd_en               (fifo_rd_en_0),
        .i_data                   (fifo_rd_data_0),
        .i_valid                  (~fifo_empty_0),
        .fifo_almost_full         (1'b0),
        .clk                      (clk),
        .rst_n                    (rst_n)
    );

    wire [8*40-1:0] fifo_rd_data_1;
    wire fifo_empty_1;
    wire fifo_rd_en_1;

    fifo_single_read #(
        .DATA_WIDTH        (8 * 40),
        .DEPTH             (15),
        .ALMOST_FULL_THRES (10)
    ) u_fifo_1 (
        .rd_data           (fifo_rd_data_1),
        .empty             (fifo_empty_1),
        .full              (),
        .almost_full       (fifo_almost_full_1),
        .wr_data           (o_data_1),
        .wr_en             (o_valid_1),
        .rd_en             (fifo_rd_en_1),
        .rst_n             (rst_n),
        .clk               (clk)
    );

    // Conv 2
    wire [8*20-1:0] o_data_2;
    wire o_valid_2;
    wire fifo_almost_full_2;

    conv #(
        .UNROLL_MODE           ("incha"),
        .IN_WIDTH              (15),
        .IN_HEIGHT             (15),
        .OUTPUT_MODE           ("no_relu"),
        .COMPUTE_FACTOR        ("single"),
        .KERNEL_0              (1),
        .KERNEL_1              (1),
        .PADDING_0             (0),
        .PADDING_1             (0),
        .DILATION_0            (1),
        .DILATION_1            (1),
        .STRIDE_0              (1),
        .STRIDE_1              (1),
        .IN_CHANNEL            (40),
        .OUT_CHANNEL           (20),
        .KERNEL_BASE_ADDR      (1080),  // Num kernel: 800
        .BIAS_BASE_ADDR        (56320),  // Num bias: 20
        .MACC_COEFF_BASE_ADDR  (56672),  // Num macc_coeff: 1
        .LAYER_SCALE_BASE_ADDR ()
    ) u_enc_2 (
        .o_data                (o_data_2),
        .o_valid               (o_valid_2),
        .fifo_rd_en            (fifo_rd_en_1),
        .i_data                (fifo_rd_data_1),
        .i_valid               (~fifo_empty_1),
        .fifo_almost_full      (1'b0),
        .weight_wr_data        (weight_wr_data),
        .weight_wr_addr        (weight_wr_addr),
        .weight_wr_en          (weight_wr_en),
        .clk                   (clk),
        .rst_n                 (rst_n)
    );

    wire [8*20-1:0] fifo_rd_data_2;
    wire fifo_empty_2;
    wire fifo_rd_en_2;

    fifo_single_read #(
        .DATA_WIDTH        (8 * 20),
        .DEPTH             (30),
        .ALMOST_FULL_THRES (10)
    ) u_fifo_2 (
        .rd_data           (fifo_rd_data_2),
        .empty             (fifo_empty_2),
        .full              (),
        .almost_full       (fifo_almost_full_2),
        .wr_data           (o_data_2),
        .wr_en             (o_valid_2),
        .rd_en             (fifo_rd_en_2),
        .rst_n             (rst_n),
        .clk               (clk)
    );

    // Conv 3
    wire [8*48-1:0] o_data_3;
    wire o_valid_3;
    wire fifo_almost_full_3;

    conv #(
        .UNROLL_MODE           ("incha"),
        .IN_WIDTH              (15),
        .IN_HEIGHT             (15),
        .OUTPUT_MODE           ("no_relu"),
        .COMPUTE_FACTOR        ("single"),
        .KERNEL_0              (3),
        .KERNEL_1              (3),
        .PADDING_0             (0),
        .PADDING_1             (0),
        .DILATION_0            (1),
        .DILATION_1            (1),
        .STRIDE_0              (1),
        .STRIDE_1              (1),
        .IN_CHANNEL            (20),
        .OUT_CHANNEL           (48),
        .KERNEL_BASE_ADDR      (1880),  // Num kernel: 8640
        .BIAS_BASE_ADDR        (56340),  // Num bias: 48
        .MACC_COEFF_BASE_ADDR  (56673),  // Num macc_coeff: 1
        .LAYER_SCALE_BASE_ADDR ()
    ) u_enc_3 (
        .o_data                (o_data_3),
        .o_valid               (o_valid_3),
        .fifo_rd_en            (fifo_rd_en_2),
        .i_data                (fifo_rd_data_2),
        .i_valid               (~fifo_empty_2),
        .fifo_almost_full      (1'b0),
        .weight_wr_data        (weight_wr_data),
        .weight_wr_addr        (weight_wr_addr),
        .weight_wr_en          (weight_wr_en),
        .clk                   (clk),
        .rst_n                 (rst_n)
    );

    wire [8*48-1:0] fifo_rd_data_3;
    wire fifo_empty_3;
    wire fifo_rd_en_3;

    fifo_single_read #(
        .DATA_WIDTH        (8 * 48),
        .DEPTH             (13),
        .ALMOST_FULL_THRES (10)
    ) u_fifo_3 (
        .rd_data           (fifo_rd_data_3),
        .empty             (fifo_empty_3),
        .full              (),
        .almost_full       (fifo_almost_full_3),
        .wr_data           (o_data_3),
        .wr_en             (o_valid_3),
        .rd_en             (fifo_rd_en_3),
        .rst_n             (rst_n),
        .clk               (clk)
    );

    // Conv 4
    wire [8*24-1:0] o_data_4;
    wire o_valid_4;
    wire fifo_almost_full_4;

    conv #(
        .UNROLL_MODE           ("incha"),
        .IN_WIDTH              (13),
        .IN_HEIGHT             (13),
        .OUTPUT_MODE           ("no_relu"),
        .COMPUTE_FACTOR        ("single"),
        .KERNEL_0              (1),
        .KERNEL_1              (1),
        .PADDING_0             (0),
        .PADDING_1             (0),
        .DILATION_0            (1),
        .DILATION_1            (1),
        .STRIDE_0              (1),
        .STRIDE_1              (1),
        .IN_CHANNEL            (48),
        .OUT_CHANNEL           (24),
        .KERNEL_BASE_ADDR      (10520),  // Num kernel: 1152
        .BIAS_BASE_ADDR        (56388),  // Num bias: 24
        .MACC_COEFF_BASE_ADDR  (56674),  // Num macc_coeff: 1
        .LAYER_SCALE_BASE_ADDR ()
    ) u_enc_4 (
        .o_data                (o_data_4),
        .o_valid               (o_valid_4),
        .fifo_rd_en            (fifo_rd_en_3),
        .i_data                (fifo_rd_data_3),
        .i_valid               (~fifo_empty_3),
        .fifo_almost_full      (1'b0),
        .weight_wr_data        (weight_wr_data),
        .weight_wr_addr        (weight_wr_addr),
        .weight_wr_en          (weight_wr_en),
        .clk                   (clk),
        .rst_n                 (rst_n)
    );

    wire [8*24-1:0] fifo_rd_data_4;
    wire fifo_empty_4;
    wire fifo_rd_en_4;

    fifo_single_read #(
        .DATA_WIDTH        (8 * 24),
        .DEPTH             (26),
        .ALMOST_FULL_THRES (10)
    ) u_fifo_4 (
        .rd_data           (fifo_rd_data_4),
        .empty             (fifo_empty_4),
        .full              (),
        .almost_full       (fifo_almost_full_4),
        .wr_data           (o_data_4),
        .wr_en             (o_valid_4),
        .rd_en             (fifo_rd_en_4),
        .rst_n             (rst_n),
        .clk               (clk)
    );

    // Conv 5
    wire [8*48-1:0] o_data_5;
    wire o_valid_5;
    wire fifo_almost_full_5;

    conv #(
        .UNROLL_MODE           ("incha"),
        .IN_WIDTH              (13),
        .IN_HEIGHT             (13),
        .OUTPUT_MODE           ("relu"),
        .COMPUTE_FACTOR        ("single"),
        .KERNEL_0              (3),
        .KERNEL_1              (3),
        .PADDING_0             (0),
        .PADDING_1             (0),
        .DILATION_0            (1),
        .DILATION_1            (1),
        .STRIDE_0              (1),
        .STRIDE_1              (1),
        .IN_CHANNEL            (24),
        .OUT_CHANNEL           (48),
        .KERNEL_BASE_ADDR      (11672),  // Num kernel: 10368
        .BIAS_BASE_ADDR        (56412),  // Num bias: 48
        .MACC_COEFF_BASE_ADDR  (56675),  // Num macc_coeff: 1
        .LAYER_SCALE_BASE_ADDR ()
    ) u_enc_5 (
        .o_data                (o_data_5),
        .o_valid               (o_valid_5),
        .fifo_rd_en            (fifo_rd_en_4),
        .i_data                (fifo_rd_data_4),
        .i_valid               (~fifo_empty_4),
        .fifo_almost_full      (1'b0),
        .weight_wr_data        (weight_wr_data),
        .weight_wr_addr        (weight_wr_addr),
        .weight_wr_en          (weight_wr_en),
        .clk                   (clk),
        .rst_n                 (rst_n),
        .dump_o_valid          (dump_o_valid)
    );

    wire [8*48-1:0] fifo_rd_data_5;
    wire fifo_empty_5;
    wire fifo_rd_en_5;

    fifo_single_read #(
        .DATA_WIDTH        (8 * 48),
        .DEPTH             (11),
        .ALMOST_FULL_THRES (10)
    ) u_fifo_5 (
        .rd_data           (fifo_rd_data_5),
        .empty             (fifo_empty_5),
        .full              (),
        .almost_full       (fifo_almost_full_5),
        .wr_data           (o_data_5),
        .wr_en             (o_valid_5),
        .rd_en             (fifo_rd_en_5),
        .rst_n             (rst_n),
        .clk               (clk)
    );

    // MaxPool 6
    wire [8*48-1:0] o_data_6;
    wire o_valid_6;
    wire fifo_almost_full_6;

    max_pooling #(
        .DATA_WIDTH               (8),
        .IN_WIDTH                 (11),
        .IN_HEIGHT                (11),
        .IN_CHANNEL               (48),
        .PADDING_0                (0),
        .PADDING_1                (0),
        .DILATION_0               (1),
        .DILATION_1               (1),
        .STRIDE_0                 (2),
        .STRIDE_1                 (2)
    ) u_max_6 (
        .o_data                   (o_data_6),
        .o_valid                  (o_valid_6),
        .fifo_rd_en               (fifo_rd_en_5),
        .i_data                   (fifo_rd_data_5),
        .i_valid                  (~fifo_empty_5),
        .fifo_almost_full         (1'b0),
        .clk                      (clk),
        .rst_n                    (rst_n)
    );

    wire [8*48-1:0] fifo_rd_data_6;
    wire fifo_empty_6;
    wire fifo_rd_en_6;

    fifo_single_read #(
        .DATA_WIDTH        (8 * 48),
        .DEPTH             (5),
        .ALMOST_FULL_THRES (10)
    ) u_fifo_6 (
        .rd_data           (fifo_rd_data_6),
        .empty             (fifo_empty_6),
        .full              (),
        .almost_full       (fifo_almost_full_6),
        .wr_data           (o_data_6),
        .wr_en             (o_valid_6),
        .rd_en             (fifo_rd_en_6),
        .rst_n             (rst_n),
        .clk               (clk)
    );

    // Conv 7
    wire [8*24-1:0] o_data_7;
    wire o_valid_7;
    wire fifo_almost_full_7;

    conv #(
        .UNROLL_MODE           ("incha"),
        .IN_WIDTH              (5),
        .IN_HEIGHT             (5),
        .OUTPUT_MODE           ("no_relu"),
        .COMPUTE_FACTOR        ("single"),
        .KERNEL_0              (1),
        .KERNEL_1              (1),
        .PADDING_0             (0),
        .PADDING_1             (0),
        .DILATION_0            (1),
        .DILATION_1            (1),
        .STRIDE_0              (1),
        .STRIDE_1              (1),
        .IN_CHANNEL            (48),
        .OUT_CHANNEL           (24),
        .KERNEL_BASE_ADDR      (22040),  // Num kernel: 1152
        .BIAS_BASE_ADDR        (56460),  // Num bias: 24
        .MACC_COEFF_BASE_ADDR  (56676),  // Num macc_coeff: 1
        .LAYER_SCALE_BASE_ADDR ()
    ) u_enc_7 (
        .o_data                (o_data_7),
        .o_valid               (o_valid_7),
        .fifo_rd_en            (fifo_rd_en_6),
        .i_data                (fifo_rd_data_6),
        .i_valid               (~fifo_empty_6),
        .fifo_almost_full      (1'b0),
        .weight_wr_data        (weight_wr_data),
        .weight_wr_addr        (weight_wr_addr),
        .weight_wr_en          (weight_wr_en),
        .clk                   (clk),
        .rst_n                 (rst_n)
    );

    wire [8*24-1:0] fifo_rd_data_7;
    wire fifo_empty_7;
    wire fifo_rd_en_7;

    fifo_single_read #(
        .DATA_WIDTH        (8 * 24),
        .DEPTH             (5),
        .ALMOST_FULL_THRES (10)
    ) u_fifo_7 (
        .rd_data           (fifo_rd_data_7),
        .empty             (fifo_empty_7),
        .full              (),
        .almost_full       (fifo_almost_full_7),
        .wr_data           (o_data_7),
        .wr_en             (o_valid_7),
        .rd_en             (fifo_rd_en_7),
        .rst_n             (rst_n),
        .clk               (clk)
    );

    // Conv 8
    wire [8*48-1:0] o_data_8;
    wire o_valid_8;
    wire fifo_almost_full_8;

    conv #(
        .UNROLL_MODE           ("incha"),
        .IN_WIDTH              (5),
        .IN_HEIGHT             (5),
        .OUTPUT_MODE           ("no_relu"),
        .COMPUTE_FACTOR        ("single"),
        .KERNEL_0              (3),
        .KERNEL_1              (3),
        .PADDING_0             (0),
        .PADDING_1             (0),
        .DILATION_0            (1),
        .DILATION_1            (1),
        .STRIDE_0              (1),
        .STRIDE_1              (1),
        .IN_CHANNEL            (24),
        .OUT_CHANNEL           (48),
        .KERNEL_BASE_ADDR      (23192),  // Num kernel: 10368
        .BIAS_BASE_ADDR        (56484),  // Num bias: 48
        .MACC_COEFF_BASE_ADDR  (56677),  // Num macc_coeff: 1
        .LAYER_SCALE_BASE_ADDR ()
    ) u_enc_8 (
        .o_data                (o_data_8),
        .o_valid               (o_valid_8),
        .fifo_rd_en            (fifo_rd_en_7),
        .i_data                (fifo_rd_data_7),
        .i_valid               (~fifo_empty_7),
        .fifo_almost_full      (1'b0),
        .weight_wr_data        (weight_wr_data),
        .weight_wr_addr        (weight_wr_addr),
        .weight_wr_en          (weight_wr_en),
        .clk                   (clk),
        .rst_n                 (rst_n)
    );

    wire [8*48-1:0] fifo_rd_data_8;
    wire fifo_empty_8;
    wire fifo_rd_en_8;

    fifo_single_read #(
        .DATA_WIDTH        (8 * 48),
        .DEPTH             (3),
        .ALMOST_FULL_THRES (10)
    ) u_fifo_8 (
        .rd_data           (fifo_rd_data_8),
        .empty             (fifo_empty_8),
        .full              (),
        .almost_full       (fifo_almost_full_8),
        .wr_data           (o_data_8),
        .wr_en             (o_valid_8),
        .rd_en             (fifo_rd_en_8),
        .rst_n             (rst_n),
        .clk               (clk)
    );

    // Conv 9
    wire [8*32-1:0] o_data_9;
    wire o_valid_9;
    wire fifo_almost_full_9;

    conv #(
        .UNROLL_MODE           ("incha"),
        .IN_WIDTH              (3),
        .IN_HEIGHT             (3),
        .OUTPUT_MODE           ("no_relu"),
        .COMPUTE_FACTOR        ("single"),
        .KERNEL_0              (1),
        .KERNEL_1              (1),
        .PADDING_0             (0),
        .PADDING_1             (0),
        .DILATION_0            (1),
        .DILATION_1            (1),
        .STRIDE_0              (1),
        .STRIDE_1              (1),
        .IN_CHANNEL            (48),
        .OUT_CHANNEL           (32),
        .KERNEL_BASE_ADDR      (33560),  // Num kernel: 1536
        .BIAS_BASE_ADDR        (56532),  // Num bias: 32
        .MACC_COEFF_BASE_ADDR  (56678),  // Num macc_coeff: 1
        .LAYER_SCALE_BASE_ADDR ()
    ) u_enc_9 (
        .o_data                (o_data_9),
        .o_valid               (o_valid_9),
        .fifo_rd_en            (fifo_rd_en_8),
        .i_data                (fifo_rd_data_8),
        .i_valid               (~fifo_empty_8),
        .fifo_almost_full      (1'b0),
        .weight_wr_data        (weight_wr_data),
        .weight_wr_addr        (weight_wr_addr),
        .weight_wr_en          (weight_wr_en),
        .clk                   (clk),
        .rst_n                 (rst_n)
    );

    wire [8*32-1:0] fifo_rd_data_9;
    wire fifo_empty_9;
    wire fifo_rd_en_9;

    fifo_single_read #(
        .DATA_WIDTH        (8 * 32),
        .DEPTH             (3),
        .ALMOST_FULL_THRES (10)
    ) u_fifo_9 (
        .rd_data           (fifo_rd_data_9),
        .empty             (fifo_empty_9),
        .full              (),
        .almost_full       (fifo_almost_full_9),
        .wr_data           (o_data_9),
        .wr_en             (o_valid_9),
        .rd_en             (fifo_rd_en_9),
        .rst_n             (rst_n),
        .clk               (clk)
    );

    // Conv 10
    wire [8*64-1:0] o_data_10;
    wire o_valid_10;
    wire fifo_almost_full_10;

    conv #(
        .UNROLL_MODE           ("incha"),
        .IN_WIDTH              (3),
        .IN_HEIGHT             (3),
        .OUTPUT_MODE           ("relu"),
        .COMPUTE_FACTOR        ("single"),
        .KERNEL_0              (3),
        .KERNEL_1              (3),
        .PADDING_0             (0),
        .PADDING_1             (0),
        .DILATION_0            (1),
        .DILATION_1            (1),
        .STRIDE_0              (1),
        .STRIDE_1              (1),
        .IN_CHANNEL            (32),
        .OUT_CHANNEL           (64),
        .KERNEL_BASE_ADDR      (35096),  // Num kernel: 18432
        .BIAS_BASE_ADDR        (56564),  // Num bias: 64
        .MACC_COEFF_BASE_ADDR  (56679),  // Num macc_coeff: 1
        .LAYER_SCALE_BASE_ADDR ()
    ) u_enc_10 (
        .o_data                (o_data_10),
        .o_valid               (o_valid_10),
        .fifo_rd_en            (fifo_rd_en_9),
        .i_data                (fifo_rd_data_9),
        .i_valid               (~fifo_empty_9),
        .fifo_almost_full      (1'b0),
        .weight_wr_data        (weight_wr_data),
        .weight_wr_addr        (weight_wr_addr),
        .weight_wr_en          (weight_wr_en),
        .clk                   (clk),
        .rst_n                 (rst_n)
    );

    wire [8*64-1:0] fifo_rd_data_10;
    wire fifo_empty_10;
    wire fifo_rd_en_10;
//FIXME
 /*   fifo_single_read #(
        .DATA_WIDTH        (8 * 64),
        .DEPTH             (2),
        .ALMOST_FULL_THRES (10)
    ) u_fifo_10 (
        .rd_data           (fifo_rd_data_10),
        .empty             (fifo_empty_10),
        .full              (),
        .almost_full       (fifo_almost_full_10),
        .wr_data           (o_data_10),
        .wr_en             (o_valid_10),
        .rd_en             (fifo_rd_en_10),
        .rst_n             (rst_n),
        .clk               (clk)
    );
*/
reg_buffer #(
    .DATA_WIDTH(8*64)
) u_reg_10 (
    .clk(clk),
    .rst_n(rst_n),
    .wr_en(o_valid_10),
    .rd_en(fifo_rd_en_10),
    .wr_data(o_data_10),
    .rd_data(fifo_rd_data_10),
    .empty(fifo_empty_10)      // == !valid
);
    // Fully connected 11
    wire [8*43-1:0] o_data_11;
    wire o_valid_11;
    wire fifo_almost_full_11;

    fc #(
        .IN_CHANNEL               (64),
        .OUT_CHANNEL              (43),
        .KERNEL_BASE_ADDR         (53528),  // Num kernel: 2752
        .BIAS_BASE_ADDR           (56628),  // Num bias: 43
        .MACC_COEFF_BASE_ADDR      (56680),
        .LAYER_SCALE_BASE_ADD     ()
    ) u_fc_11 (
        .o_data                (o_data_11),
        .o_valid               (o_valid_11),
        .fifo_rd_en            (fifo_rd_en_10),
        .i_data                (fifo_rd_data_10),
        .i_valid               (~fifo_empty_10),
        .fifo_almost_full      (1'b0),
        .weight_wr_data        (weight_wr_data),
        .weight_wr_addr        (weight_wr_addr),
        .weight_wr_en          (weight_wr_en),
        .clk                   (clk),
        .rst_n                 (rst_n)
    );
    
    max_byte_index #(
                    .NUM_IN(43),
                    .BYTE_W(8)
    ) 
    pos_decoder (
    .clk(clk),
    .rst_n(rst_n),
    .i_valid(o_valid_11),
    .data_in(o_data_11),
    .o_valid(o_valid),
    .max_idx(o_data)
);

endmodule
