# Quick compilation test for board_with_pipe.v
create_project -in_memory -part xcvc1502-nsvg1369-1LHP-i-L

# Add all source files
add_files imports/pipe_interface_simple.sv
add_files imports/board_with_pipe.v
add_files imports/board_common.vh
add_files imports/pci_exp_expect_tasks.vh
add_files imports/pci_exp_usrapp_com.v
add_files imports/pci_exp_usrapp_tx.v
add_files imports/pci_exp_usrapp_rx.v
add_files imports/pci_exp_usrapp_cfg.v
add_files imports/pcie_4_0_rp.v
add_files imports/pcie_app_uscale.v
add_files imports/pio_ep_mem_access.v
add_files imports/pio_ep_xpm_sdpram_wrap.sv
add_files imports/pio_ep.v
add_files imports/pio_intr_ctrl.v
add_files imports/pio_rx_engine.v
add_files imports/pio_to_ctrl.v
add_files imports/pio_tx_engine.v
add_files imports/pio.v
add_files imports/sys_clk_gen_ds.v
add_files imports/sys_clk_gen.v
add_files imports/xilinx_pcie_uscale_rp.v
add_files imports/xilinx_pcie4_uscale_ep.v

# Set SystemVerilog files
set_property file_type SystemVerilog [get_files pipe_interface_simple.sv]

# Set top module
set_property top board_with_pipe [current_fileset]

# Try to compile
if {[catch {update_compile_order -fileset sources_1} error]} {
    puts "ERROR: Compilation failed: $error"
    exit 1
} else {
    puts "SUCCESS: Board with pipe testbench compiled successfully"
    exit 0
}
