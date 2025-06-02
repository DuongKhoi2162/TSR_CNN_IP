`timescale 1ns / 1ps
   parameter INPUT_DATA_WIDTH  = 8;
   parameter OUTPUT_DATA_WIDTH = 8;
   parameter OUT_CHANNEL       = 3; 
   parameter IN_CHANNEL        = 4;
   parameter IN_WIDTH          = 1;
   parameter IN_HEIGHT         = 1;
   parameter KERNEL_SIZE       = 1;
   parameter PADDING           = 0;
   parameter DILATION          = 1;
   parameter STRIDE            = 1;

module conv_tb;
   logic clk; 
   //parameter to config 
   
   //interface
   conv_intf #(
              .OUTPUT_DATA_WIDTH    (OUTPUT_DATA_WIDTH),
              .OUT_CHANNEL          (OUT_CHANNEL), 
              .IN_CHANNEL           (IN_CHANNEL)
              ) intf(clk); 
   //dut 
   //test with first layer
   conv #(
        .UNROLL_MODE           ("incha"), 
        .IN_WIDTH              (IN_WIDTH),        
        .IN_HEIGHT             (IN_HEIGHT), 
        .OUTPUT_MODE           ("relu"), 
        .COMPUTE_FACTOR        ("single"), 
        .KERNEL_0              (KERNEL_SIZE), 
        .KERNEL_1              (KERNEL_SIZE),
        .PADDING_0             (PADDING), 
        .PADDING_1             (PADDING),
        .DILATION_0            (DILATION), 
        .DILATION_1            (DILATION),
        .STRIDE_0              (STRIDE),
        .STRIDE_1              (STRIDE), 
        .IN_CHANNEL            (IN_CHANNEL), 
        .OUT_CHANNEL           (OUT_CHANNEL),
        .KERNEL_BASE_ADDR      (0),  //
        .BIAS_BASE_ADDR        (75960),  //will be gen-ed by script
        .MACC_COEFF_BASE_ADDR  (76304),  //will be gen-ed by script
        .LAYER_SCALE_BASE_ADDR ()
    ) u_enc_0 (
        .o_data                (intf.o_data),
        .o_valid               (intf.o_valid),
        .fifo_rd_en            (intf.fifo_rd_en),
        .i_data                (intf.i_data),
        .i_valid               (intf.i_valid),
        .fifo_almost_full      (1'b0),
        .weight_wr_data        (intf.weight_wr_data),
        .weight_wr_addr        (intf.weight_wr_addr),
        .weight_wr_en          (intf.weight_wr_en),
        .clk                   (clk),
        .rst_n                 (intf.rst_n)
    );
   //test program 
    test testconv(intf); 
    
    initial begin
        clk = 0; 
        forever begin
            #10 clk = ~clk; 
        end
    end
endmodule

program automatic test(conv_intf intf);
    bit set_up_path = 0;
    int count = 0; 
    int rs_count = 0;
    int windows_c = 0; 
    string image_path, weight_path, bias_path, coeff_path, first_window_path, result_path, result_weight_path, result_bias_path;
    reg [OUTPUT_DATA_WIDTH*OUT_CHANNEL-1:0]                         sim_rs         [0:((IN_WIDTH-KERNEL_SIZE+1+PADDING)*(IN_HEIGHT-KERNEL_SIZE+1+PADDING))-1]; //array to store result, 320 = 8bit*40(no of outchannel), 900 = 30*30 (output high & weight)
    reg [IN_CHANNEL*INPUT_DATA_WIDTH-1:0]                           windows_info   [0:(IN_HEIGHT*IN_WIDTH-1)]; //array storing input image, 24 = 8bit*3(no of inputchannel), 1024 = 8(datawidth)*3(kernel0)*3(kernel1)*3(inchannel)*40(outchannel)
    reg [15:0]                                                      sim_kernel     [0:(KERNEL_SIZE*KERNEL_SIZE*IN_CHANNEL*OUT_CHANNEL-1)]; //array storing weights, 16 = datawidth, 1080 = 3*3*3*40 (kernel0*kernel1*inchannel*outchannel) 
    reg [15:0]                                                      sim_bias       [0:OUT_CHANNEL-1]; //array storing biases, 16 = datawidth, 40 = outchannel
    reg [15:0]                                                      sim_coeff      [1];//9; //array storing coeff value
    reg [(KERNEL_SIZE*KERNEL_SIZE*IN_CHANNEL*INPUT_DATA_WIDTH)-1:0] test_kernel ; //test 1 kernel 
    reg [(KERNEL_SIZE*KERNEL_SIZE*IN_CHANNEL*INPUT_DATA_WIDTH)-1:0] img_data       [OUT_CHANNEL-1:0]; //test 
    int img_c = 0; 
    
    initial begin
         image_path = $sformatf("input_image_binary.txt"); 
         weight_path = $sformatf("kernel_binary.txt"); 
         bias_path   = $sformatf("new_bias.txt"); 
         coeff_path  = $sformatf("new_mac_coeff.txt"); 
         first_window_path = $sformatf("rs_first_window.txt");
         result_weight_path = $sformatf("rs_weight.txt"); 
         result_bias_path   = $sformatf("rs_bias.txt"); 
         result_path   = $sformatf("rs_final.txt"); 
         set_up_path = 1;
    end 
    
    initial begin
       wait(set_up_path);
       set_up_path = 0;  
      // $readmemb(image_path, windows_info); //create from img to bin colab file
       $readmemb(weight_path, sim_kernel);  //create from python code
       $readmemb(bias_path, sim_bias); //create from python code
      // $readmemb(coeff_path, sim_coeff); //create from python code 
     end

     initial begin
        intf.rst_n <= 0;
        #20;
        intf.rst_n <= 1; 
        //Ư#20; 
        // Write Kernel Weights
        for (int i = 0; i < OUT_CHANNEL; i = i + 1) begin //40
            for (int j = 0; j < IN_CHANNEL * KERNEL_SIZE * KERNEL_SIZE; j = j + 1) begin
                intf.weight_wr_data = sim_kernel[(i * 3 * 3 * 3) + j]; // Example weight data
                intf.weight_wr_addr = 0 + (i * 3 * 3 * 3) + j;
                intf.weight_wr_en = 1;
                #20; // Wait for a clock edge
            end
                
        end

        // Write Biases
        for (int i = 0; i < OUT_CHANNEL; i = i + 1) begin
            intf.weight_wr_data = sim_bias[i]; // Example bias data
            intf.weight_wr_addr = 75960 + i;
            intf.weight_wr_en = 1;
            #20; // Wait for a clock edge
        end
          
        intf.weight_wr_data = sim_coeff[0]; // Example bias data
        intf.weight_wr_addr = 76304;
        #20; // Wait for a clock edge
        intf.weight_wr_en = 0; 
        intf.i_valid <= 1; 
        #20; 
        $writememb(result_weight_path,u_enc_0.gen0.gen1.u_pe_incha_single.u_kernel.ram);
        //$writememb(bias_weight_path,u_enc_0.gen0.gen1.u_pe_incha_single.u_bias.ram);
        //$writememh("write_coeff.txt",u_enc_0.gen0.gen1.u_pe_incha_single.macc_coeff);

     fork    
        begin
            repeat(IN_HEIGHT*IN_WIDTH) begin 
                intf.i_data <= windows_info[count];  
                #20;
                count = count + 1;
            end
            repeat((IN_HEIGHT - KERNEL_SIZE + 1 + PADDING)*(IN_WIDTH - KERNEL_SIZE + 1 + PADDING)) begin 
                wait(intf.o_valid); 
                sim_rs[rs_count] = intf.o_data;  //write output to textfile
                rs_count = rs_count + 1; 
                wait(!intf.o_valid);
            end  
        end
        
        begin
            repeat(OUT_CHANNEL) begin
                wait(u_enc_0.u_line_buffer.o_valid);
                img_data[img_c] = u_enc_0.u_line_buffer.o_data; //write first sliding window 
                #20; 
                img_c = img_c + 1;
            end
         end
        join   
        $writememb(first_window_path,img_data);          
        $writememb(result_path,sim_rs);   
      $display("DONE"); 
   end
   
endprogram
