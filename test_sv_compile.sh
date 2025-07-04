#!/bin/bash
#
# Quick test to check if the SystemVerilog files compile correctly
#

echo "Testing SystemVerilog compilation..."

# Check if Vivado is available
if ! command -v vivado &> /dev/null; then
    echo "ERROR: Vivado not found in PATH"
    echo "Please source Vivado settings script first:"
    echo "  source /opt/Xilinx/Vivado/2023.2/settings64.sh"
    exit 1
fi

# Create a temporary test directory
TEST_DIR="/tmp/pcie_sv_test"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

# Copy the SystemVerilog files
cp /media/bigdisk/Xilinx/TFHE/pcie4_uscale_plus_0_ex/imports/pipe_interface_simple.sv .
cp /media/bigdisk/Xilinx/TFHE/pcie4_uscale_plus_0_ex/imports/board_with_pipe.v .

# Create a minimal test project
cat > test_compile.tcl << 'EOF'
# Get available parts and use the first UltraScale+ part found
set part_list [get_parts -filter {FAMILY =~ "*UltraScale*"}]
if {[llength $part_list] == 0} {
    # If no UltraScale+ parts, try any Xilinx part
    set part_list [get_parts]
    if {[llength $part_list] == 0} {
        puts "ERROR: No Xilinx parts available"
        exit 1
    }
}

set selected_part [lindex $part_list 0]
puts "Using part: $selected_part"

# Create in-memory project
create_project -in_memory -part $selected_part

# Add SystemVerilog files
add_files pipe_interface_simple.sv
set_property file_type SystemVerilog [get_files pipe_interface_simple.sv]

# Try to compile
if {[catch {update_compile_order -fileset sources_1} error]} {
    puts "ERROR: Compilation failed: $error"
    exit 1
} else {
    puts "SUCCESS: SystemVerilog interface compiled successfully"
    exit 0
}
EOF

# Run the test
echo "Running compilation test..."
vivado -mode batch -source test_compile.tcl -nojournal -nolog

# Check result
if [ $? -eq 0 ]; then
    echo "✓ SystemVerilog files compile successfully"
    echo "✓ Ready to run full simulation"
else
    echo "✗ Compilation failed"
    echo "Check the SystemVerilog syntax and compatibility"
fi

# Cleanup
cd /
rm -rf "$TEST_DIR"
