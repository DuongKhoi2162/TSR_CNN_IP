`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/23/2025 02:45:30 PM
// Design Name: 
// Module Name: top_tb
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

module top_tsr_tb;

logic            o_valid;
logic [6-1:0]    o_data;
logic            axi_rd_data;
logic [8*8-1:0]  axi_wr_data; 
logic [19:0]     axi_wr_addr; 
logic [19:0]     axi_rd_addr;
logic            axi_wr_en; 
logic            axi_rd_en; 
logic [7:0]      axi_wr_strobe; 
logic            clk; 
logic            rst_n; 
logic            weight_load_done;
int              c0 = 0;
int              mx0 = 0;
int              c5 = 0;
reg [63:0]       input_stream[384*2000];
reg [63:0]       weight_stream[14173];
reg [8*40-1:0]   conv0_rs[900];
reg [8*48-1:0]   conv5_rs[11*11];
reg [8*20-1:0]   conv2_rs[15*15];
reg [8*48-1:0]   conv3_rs[13*13];
reg [8*24-1:0]   conv4_rs[13*13];
reg [8*40-1:0]   maxp1_rs[15*15];
reg [7:0]        expected_value[1000]; 
integer total, correct;
int addr_cnt =0;
logic busy;
logic [5:0] output_value; 
int scb_cnt = 0; 

top_tsr  DUT (
            .weight_load_done   (weight_load_done),
            .o_valid            (o_valid),
            .o_data             (o_data),
            .axi_rd_data        (axi_rd_data),
            .axi_wr_data        (axi_wr_data),
            .axi_wr_addr        (axi_wr_addr),
            .axi_rd_addr        (axi_rd_addr),
            .axi_wr_en          (axi_wr_en),
            .axi_rd_en          (axi_rd_en),
            .axi_wr_strobe      (axi_wr_strobe),
            .clk                (clk),
            .rst_n              (rst_n),
            .busy               (busy)
);
initial begin
    forever begin
        #5 clk = !clk;
    end
end

initial begin 
    $readmemh("C://QuantLaneNet-main//weights//weights_2805.mem", weight_stream); 
    $readmemh("C://QuantLaneNet-main//weights//quantize_test_image_bitstream.mem", input_stream); 
end

initial begin 
    $readmemh("C://QuantLaneNet-main//weights//expected_output_1000_padded.mem",expected_value); 
    total = 0;
    correct = 0;
end

initial begin   
    rst_n = 0;
    clk = 0;
    axi_wr_addr = 0; 
    axi_wr_data = 64'h0;
    axi_wr_en = 0; 
    axi_wr_strobe = 0;
    repeat(100) @(negedge clk);
    rst_n = 1;
    @(negedge clk); 
    foreach(weight_stream[i]) begin 
        axi_wr_addr = 3097 + i; //FIXME
        axi_wr_data = weight_stream[i];
        axi_wr_en = 1;
        axi_wr_strobe = 8'h03;
        $display("[WEIGHT] I: Send AXI Transaction with data = %0h, addr = 0x%4h",axi_wr_data,axi_wr_addr); 
        #10;
    end
    //FIXME
    axi_wr_strobe = 8'h00;
    wait(weight_load_done);
    @(negedge clk);
    //FIX INPUT STREAM  
    fork
        begin
            foreach(input_stream[i]) begin 
                axi_wr_addr = addr_cnt;
                axi_wr_data = input_stream[i+384*1000];
                axi_wr_en = 1;
                axi_wr_strobe = 8'h07;
                //$display("[INPUT] I: Send AXI Transaction with data = %0h, addr = 0x%4h",axi_wr_data,axi_wr_addr); 
                addr_cnt = addr_cnt + 1;
                @(negedge clk);
                if(addr_cnt == 384) begin
                    axi_wr_en = 0;
                    addr_cnt = 0;
                    wait(o_valid); 
                    output_value = o_data; 
                    if(output_value == expected_value[total]) correct = correct + 1; 
                    else begin
                        $display("Mismatch at index %0d: Got %0h, Expected %0h", total, output_value, expected_value[total]);
                    end
                    total = total + 1;
                    wait(!o_valid);
                    axi_wr_en = 1; 
                    @(negedge clk);
                    //wait(DUT.DUT.u_enc_5.u_line_buffer.u_control.end_of_frame);
                    //wait(!DUT.DUT.u_enc_5.u_line_buffer.u_control.end_of_frame);
                end
            end
            axi_wr_en = 0;
        end
        /*
        begin 
           automatic int count =0; 
           for(int i = 0; i < 900; i = i+1) begin 
                wait(DUT.DUT.u_fifo_0.wr_en); 
                wait(!DUT.DUT.u_fifo_0.wr_en); 
                count = count +  1;
                $display("[%t], FIFO 0 Execute %d times",$time,count); 
            end 
        end
        begin 
           automatic int count2 =0; 
           for(int i = 0; i < 15*15; i = i+1) begin 
                wait(DUT.DUT.u_fifo_1.wr_en); 
                wait(!DUT.DUT.u_fifo_1.wr_en); 
                count2 = count2 +  1;
                $display("[%t], FIFO 1 Execute %d times",$time,count2); 
            end 
        end
        */
        /*
        begin 
           automatic int count9 =0; 
           for(int i = 0; i < 64; i = i+1) begin 
                wait(DUT.DUT.u_reg_10.wr_en); 
                wait(!DUT.DUT.u_reg_10.wr_en); 
                count9 = count9 +  1;
                $display("[%t], REG BUG Execute %d times",$time,count9); 
            end 
        end
*/
    join
    $display("Accuracy = %0.2f%% (%0d correct out of %0d)", 100.0 * correct / total, correct, total);
    $display("DONE MONITOR");
    $finish;
end
endmodule
