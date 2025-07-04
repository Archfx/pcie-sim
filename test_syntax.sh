#!/bin/bash
#
# Simple syntax test for SystemVerilog files without requiring a specific part
#

echo "Testing SystemVerilog syntax..."

# Check if Vivado is available
if ! command -v vivado &> /dev/null; then
    echo "ERROR: Vivado not found in PATH"
    echo "Please source Vivado settings script first:"
    echo "  source /opt/Xilinx/Vivado/2023.2/settings64.sh"
    exit 1
fi

# Create a temporary test directory
TEST_DIR="/tmp/pcie_sv_syntax_test"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

# Copy the SystemVerilog files
cp /media/bigdisk/Xilinx/TFHE/pcie4_uscale_plus_0_ex/imports/pipe_interface_simple.sv .

# Create a minimal Tcl script for syntax checking
cat > syntax_test.tcl << 'EOF'
# Simple syntax check without creating a project

# Read and parse the SystemVerilog file
if {[catch {read_verilog -sv pipe_interface_simple.sv} error]} {
    puts "ERROR: SystemVerilog syntax error: $error"
    exit 1
} else {
    puts "SUCCESS: SystemVerilog syntax is valid"
    exit 0
}
EOF

# Run the syntax test
echo "Running syntax check..."
vivado -mode batch -source syntax_test.tcl -nojournal -nolog 2>/dev/null

# Check result
if [ $? -eq 0 ]; then
    echo "✓ SystemVerilog syntax is valid"
    echo "✓ Ready to run simulation"
else
    echo "✗ SystemVerilog syntax check failed"
    echo "Let's try a manual check..."
    
    # Try alternative method using xvlog directly
    echo "Trying direct xvlog compilation..."
    if command -v xvlog &> /dev/null; then
        xvlog -sv pipe_interface_simple.sv 2>&1
        if [ $? -eq 0 ]; then
            echo "✓ xvlog compilation successful"
        else
            echo "✗ xvlog compilation failed"
        fi
    else
        echo "xvlog not available"
    fi
fi

# Cleanup
cd /
rm -rf "$TEST_DIR"
