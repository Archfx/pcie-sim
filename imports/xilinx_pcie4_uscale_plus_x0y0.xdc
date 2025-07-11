##-----------------------------------------------------------------------------
##
## (c) Copyright 1995, 2007, 2023 Advanced Micro Devices, Inc. All rights reserved.
##
## This file contains confidential and proprietary information
## of AMD, Inc. and is protected under U.S. and
## international copyright and other intellectual property
## laws.
##
## DISCLAIMER
## This disclaimer is not a license and does not grant any
## rights to the materials distributed herewith. Except as
## otherwise provided in a valid license issued to you by
## AMD, and to the maximum extent permitted by applicable
## law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
## WITH ALL FAULTS, AND AMD HEREBY DISCLAIMS ALL WARRANTIES
## AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
## BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
## INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
## (2) AMD shall not be liable (whether in contract or tort,
## including negligence, or under any other theory of
## liability) for any loss or damage of any kind or nature
## related to, arising under or in connection with these
## materials, including for any direct, or any indirect,
## special, incidental, or consequential loss or damage
## (including loss of data, profits, goodwill, or any type of
## loss or damage suffered as a result of any action brought
## by a third party) even if such damage or loss was
## reasonably foreseeable or AMD had been advised of the
## possibility of the same.
##
## CRITICAL APPLICATIONS
## AMD products are not designed or intended to be fail-
## safe, or for use in any application requiring fail-safe
## performance, such as life-support or safety devices or
## systems, Class III medical devices, nuclear facilities,
## applications related to the deployment of airbags, or any
## other applications that could lead to death, personal
## injury, or severe property or environmental damage
## (individually and collectively, "Critical
## Applications"). Customer assumes the sole risk and
## liability of any use of AMD products in Critical
## Applications, subject only to applicable laws and
## regulations governing limitations on product liability.
##
## THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
## PART OF THIS FILE AT ALL TIMES.
##
##-----------------------------------------------------------------------------
##
## Project    : UltraScale+ FPGA PCI Express v4.0 Integrated Block
## File       : xilinx_pcie4_uscale_plus_x0y0.xdc
## Version    : 1.3 
##-----------------------------------------------------------------------------
#
###############################################################################
# Vivado - PCIe GUI / User Configuration 
###############################################################################
#
# Family              # virtexuplusHBM
# Part                # xcvu35p
# Package             # fsvh2892
# Speed grade         # -1
# PCIe Block          # X0Y0
# Xilinx BNo          # 0
#
# Link Speed          # Gen1 - Gb/s
# Link Width          # X1
# AXIST Width         # 64-bit
# AXIST Frequ         # 62.5 MHz = User Clock
# Core Clock          # 250 MHz
# Pipe Clock          # 125 MHz (Gen1) : 250 MHz (Gen2/Gen3/Gen4)
# PLL TYPE            # CPLL
# MSI-X TYPE          # HARD
#
# master_gt_quad_inx  # 0
# master_gt_container # 31
# gt_type             # gtye4
#
#
###############################################################################
# User Time Names / User Time Groups / Time Specs
###############################################################################
create_clock -name sys_clk -period 10 [get_ports sys_clk_p]
# False path constraint on sys_rst_n is now moved to IP level *_impl_*.xdc file. Please check design source/* area for reference.
# set_false_path -from [get_ports sys_rst_n]
set_property PULLUP true [get_ports sys_rst_n]

set_property IOSTANDARD LVCMOS18 [get_ports sys_rst_n]
#
set_property LOC [get_package_pins -filter {PIN_FUNC =~ *_PERSTN0_65}] [get_ports sys_rst_n] 

#
set_property LOC [get_package_pins -of_objects [get_bels [get_sites -filter {NAME =~ *COMMON*} -of_objects [get_iobanks -of_objects [get_sites GTYE4_CHANNEL_X1Y31]]]/REFCLK0P]] [get_ports sys_clk_p]
set_property LOC [get_package_pins -of_objects [get_bels [get_sites -filter {NAME =~ *COMMON*} -of_objects [get_iobanks -of_objects [get_sites GTYE4_CHANNEL_X1Y31]]]/REFCLK0N]] [get_ports sys_clk_n]
#

#


#
#
#
# CLOCK_ROOT LOCKing to Reduce CLOCK SKEW
# Add/Edit  Clock Routing Option to improve clock path skew
#
# BITFILE/BITSTREAM compress options
# ##############################################################################
# Flash Programming Example Settings: These should be modified to match the target board.
# ##############################################################################
#
#
# sys_clk vs TXOUTCLK
set_clock_groups -name async18 -asynchronous -group [get_clocks {sys_clk}] -group [get_clocks -of_objects [get_pins -hierarchical -filter {NAME =~ *gen_channel_container[31].*gen_gtye4_channel_inst[0].GTYE4_CHANNEL_PRIM_INST/TXOUTCLK}]]
#
#
#
#
#
#
# ASYNC CLOCK GROUPINGS
# sys_clk vs pclk
set_clock_groups -name async1 -asynchronous -group [get_clocks {sys_clk}] -group [get_clocks -of_objects [get_pins pcie4_uscale_plus_0_i/inst/pcie4_uscale_plus_0_gt_top_i/diablo_gt.diablo_gt_phy_wrapper/phy_clk_i/bufg_gt_pclk/O]]
#
# sys_clk vs user_clk
set_clock_groups -name async5 -asynchronous -group [get_clocks {sys_clk}] -group [get_clocks -of_objects [get_pins pcie4_uscale_plus_0_i/inst/pcie4_uscale_plus_0_gt_top_i/diablo_gt.diablo_gt_phy_wrapper/phy_clk_i/bufg_gt_userclk/O]]
#
#
# Timing improvement
# Add/Edit Pblock slice constraints for init_ctr module to improve timing
#create_pblock init_ctr_rst; add_cells_to_pblock [get_pblocks init_ctr_rst] [get_cells pcie4_uscale_plus_0_i/inst/pcie4_uscale_plus_0_pcie_4_0_pipe_inst/pcie_4_0_init_ctrl_inst]
# Keep This Logic Left/Right Side Of The PCIe Block (Whichever is near to the FPGA Boundary)
#resize_pblock [get_pblocks init_ctr_rst] -add {SLICE_X220Y240:SLICE_X231Y299}
#
set_clock_groups -name async24 -asynchronous -group [get_clocks -of_objects [get_pins pcie4_uscale_plus_0_i/inst/pcie4_uscale_plus_0_gt_top_i/diablo_gt.diablo_gt_phy_wrapper/phy_clk_i/bufg_gt_intclk/O]] -group [get_clocks {sys_clk}]
#
#create_waiver -type METHODOLOGY -id {LUTAR-1} -user "pcie4_uscale_plus" -desc "user link up is synchroized in the user clk so it is safe to ignore"  -internal -scoped -tags 1024539  -objects [get_cells { pcie_app_uscale_i/PIO_i/len_i[5]_i_4 }] -objects [get_pins { pcie4_uscale_plus_0_i/inst/user_lnk_up_cdc/arststages_ff_reg[0]/CLR pcie4_uscale_plus_0_i/inst/user_lnk_up_cdc/arststages_ff_reg[1]/CLR }] 

#--------------------- Adding waiver --------------------#
create_waiver -type DRC -id {REQP-1839} -tags "1167240" -scope -internal -user "pcie4_uscale_plus" -desc "DRC expects synchronous pins to be provided to BRAM inputs. Since synchronization is present one stage before, it is safe to ignore" -objects [get_cells -hierarchical -filter {NAME =~ {pcie_app_uscale_i/PIO_i/pio_ep/ep_mem/ep_xpm_sdpram/*mem_reg_bram_0}}]
create_waiver -type DRC -id {REQP-1840} -tags "1167240" -scope -internal -user "pcie4_uscale_plus" -desc "DRC expects synchronous pins to be provided to BRAM inputs. Since synchronization is present one stage before, it is safe to ignore" -objects [get_cells -hierarchical -filter {NAME =~ {pcie_app_uscale_i/PIO_i/pio_ep/ep_mem/ep_xpm_sdpram/*mem_reg_bram_0}}]

