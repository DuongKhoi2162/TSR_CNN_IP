# Connect to the 100 MHz differential clock input on VC707
#set_property PACKAGE_PIN AJ14 [get_ports clk_p]
#set_property PACKAGE_PIN AJ13 [get_ports clk_n]
#set_property IOSTANDARD DIFF_SSTL15 [get_ports clk_p clk_n]

# Create differential buffer
#set_property CLOCK_DEDICATED_ROUTE BACKBONE [get_nets clk_p]
create_clock -name clk -period 10.000 [get_ports clk]

# === Reset button (SW9 - Center Push Button) on AJ21 ===
set_property PACKAGE_PIN AV40 [get_ports rst_n]
set_property IOSTANDARD LVCMOS18 [get_ports rst_n]

# === User LEDs ===
set_property PACKAGE_PIN AM39 [get_ports weight_load_done]
set_property IOSTANDARD LVCMOS18 [get_ports weight_load_done]

set_property PACKAGE_PIN AN39 [get_ports busy]
set_property IOSTANDARD LVCMOS18 [get_ports busy]

# === I/O Delays (assume external synchronous delay of 2.5 ns) ===
set_input_delay 0.5 -clock [get_clocks clk] [get_ports axi_wr_data]
set_input_delay 0.5 -clock [get_clocks clk] [get_ports axi_wr_addr]
set_input_delay 0.5 -clock [get_clocks clk] [get_ports axi_rd_addr]
set_input_delay 0.5 -clock [get_clocks clk] [get_ports axi_wr_en]
set_input_delay 0.5 -clock [get_clocks clk] [get_ports axi_rd_en]
set_input_delay 0.5 -clock [get_clocks clk] [get_ports axi_wr_strobe]
set_input_delay 0.5 -clock [get_clocks clk] [get_ports rst_n]

set_output_delay 0.5 -clock [get_clocks clk] [get_ports axi_rd_data]
set_output_delay 0.5 -clock [get_clocks clk] [get_ports o_valid]
set_output_delay 0.5 -clock [get_clocks clk] [get_ports o_data]
set_output_delay 0.5 -clock [get_clocks clk] [get_ports weight_load_done]
set_output_delay 0.5 -clock [get_clocks clk] [get_ports busy]

# === Ignore async reset from timing ===
set_false_path -from [get_ports rst_n]