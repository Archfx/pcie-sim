#!/bin/bash
# Test simulation startup with pipe interface

echo "Testing simulation startup with pipes..."

# Ensure pipes exist
mkfifo /tmp/pcie_sim_cmd /tmp/pcie_sim_rsp 2>/dev/null

# Create a simple TCL script to test simulation startup
cat > test_sim_startup.tcl << 'EOF'
create_project -in_memory -part xcvc1502-nsvg1369-1LHP-i-L

# Add all necessary files
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

set_property file_type SystemVerilog [get_files pipe_interface_simple.sv]
set_property top board_with_pipe [current_fileset]

# Test simulation setup without running
update_compile_order -fileset sources_1

puts "SUCCESS: Simulation setup completed successfully"
exit 0
EOF

# Run the test
timeout 60 vivado -mode batch -source test_sim_startup.tcl > sim_test.log 2>&1

if grep -q "SUCCESS" sim_test.log; then
    echo "✓ Simulation setup test passed"
    echo "✓ Ready for full simulation run"
else
    echo "✗ Simulation setup failed"
    echo "Last 10 lines of log:"
    tail -10 sim_test.log
fi

# Cleanup
rm -f test_sim_startup.tcl sim_test.log
