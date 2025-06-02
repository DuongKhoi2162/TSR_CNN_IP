module max_byte_index
#(
    parameter integer NUM_IN = 4,
    parameter integer BYTE_W = 8,
    parameter integer IDX_W  = $clog2(NUM_IN)
)(
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire                         i_valid,
    input  wire [NUM_IN*BYTE_W-1:0]     data_in,
    output wire                         o_valid,
    output wire [IDX_W-1:0]             max_idx
);
    //---------------------------------------------------------
    //  Constants
    //---------------------------------------------------------
    localparam LG_NUM  = (NUM_IN <= 1) ? 1 : $clog2(NUM_IN); // # compare stages
    localparam PAD_NUM = (1 << LG_NUM) - NUM_IN;            // bytes padded to power-of-2

    //---------------------------------------------------------
    //  Stage-0 : slice input word into bytes (combinational)
    //---------------------------------------------------------
    wire [BYTE_W-1:0] st0_val [0:(1<<LG_NUM)-1];
    wire [IDX_W-1:0 ] st0_idx [0:(1<<LG_NUM)-1];

    genvar b;
    generate
        // Real bytes
        for (b = 0; b < NUM_IN; b = b + 1) begin : SLICE
            assign st0_val[b] = data_in[BYTE_W*b +: BYTE_W];
            assign st0_idx[b] = b[IDX_W-1:0];
        end
        // Padding so the tree is perfect
        for (b = NUM_IN; b < (1<<LG_NUM); b = b + 1) begin : SLICE_PAD
            assign st0_val[b] = {BYTE_W{1'b0}};
            assign st0_idx[b] = b[IDX_W-1:0];
        end
    endgenerate

    //---------------------------------------------------------
    //  Pipeline storage: stage_val[L][i] / stage_idx[L][i]
    //---------------------------------------------------------
    // There are LG_NUM+1 register stages (stage 0 captures the sliced bytes).
    //---------------------------------------------------------

    reg [BYTE_W-1:0] stage_val [0:LG_NUM][0:(1<<LG_NUM)-1];
    reg [IDX_W-1:0 ] stage_idx [0:LG_NUM][0:(1<<LG_NUM)-1];

    // Valid signal travels the same number of stages
    reg [LG_NUM:0] valid_pipeline;

    integer i;

    // Capture sliced bytes into stage 0 registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < (1<<LG_NUM); i = i + 1) begin
                stage_val[0][i] <= {BYTE_W{1'b0}};
                stage_idx[0][i] <= {IDX_W{1'b0}};
            end
            valid_pipeline[0] <= 1'b0;
        end else begin
            valid_pipeline[0] <= i_valid;
            if (i_valid) begin
                for (i = 0; i < (1<<LG_NUM); i = i + 1) begin
                    stage_val[0][i] <= st0_val[i];
                    stage_idx[0][i] <= st0_idx[i];
                end
            end
        end
    end

    //---------------------------------------------------------
    //  Generate compare-and-register pipeline stages
    //---------------------------------------------------------
    genvar L, k;
    generate
        for (L = 0; L < LG_NUM; L = L + 1) begin : PIPE
            localparam integer ELEM = (1 << (LG_NUM - L)); // items entering stage L

            // Comparators (combinational)
            for (k = 0; k < (ELEM>>1); k = k + 1) begin : CMP
                wire [BYTE_W-1:0] a_val = stage_val[L][2*k];
                wire [BYTE_W-1:0] b_val = stage_val[L][2*k+1];
                wire [IDX_W-1:0 ] a_idx = stage_idx[L][2*k];
                wire [IDX_W-1:0 ] b_idx = stage_idx[L][2*k+1];

                wire pick_b = (b_val >= a_val);    // right-most wins on tie

                wire [BYTE_W-1:0] w_val = pick_b ? b_val : a_val;
                wire [IDX_W-1:0 ] w_idx = pick_b ? b_idx : a_idx;

                // Register winner into next stage
                always @(posedge clk or negedge rst_n) begin
                    if (!rst_n) begin
                        stage_val[L+1][k] <= {BYTE_W{1'b0}};
                        stage_idx[L+1][k] <= {IDX_W{1'b0}};
                    end else if (valid_pipeline[L]) begin
                        stage_val[L+1][k] <= w_val;
                        stage_idx[L+1][k] <= w_idx;
                    end
                end
            end // CMP

            // Shift the valid bit one stage downstream
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n)
                    valid_pipeline[L+1] <= 1'b0;
                else
                    valid_pipeline[L+1] <= valid_pipeline[L];
            end
        end // PIPE
    endgenerate

    //---------------------------------------------------------
    //  Outputs (stage LG_NUM)
    //---------------------------------------------------------
    assign max_idx = stage_idx[LG_NUM][0];
    assign o_valid = valid_pipeline[LG_NUM];

endmodule