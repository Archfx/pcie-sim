#!/bin/bash
#
# PCIe Simulation Script with Python Interface
# Run this script to start the PCIe simulation with Python communication support
#

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "pcie4_uscale_plus_0_ex.xpr" ]; then
    print_error "This script must be run from the PCIe project directory"
    print_error "Expected to find 'pcie4_uscale_plus_0_ex.xpr' in current directory"
    exit 1
fi

# Create named pipes for communication
print_status "Setting up communication pipes..."
PIPE_DIR="/tmp"
CMD_PIPE="$PIPE_DIR/pcie_sim_cmd"
RSP_PIPE="$PIPE_DIR/pcie_sim_rsp"

# Clean up any existing pipes
rm -f "$CMD_PIPE" "$RSP_PIPE"

# Create new pipes
mkfifo "$CMD_PIPE" 2>/dev/null
mkfifo "$RSP_PIPE" 2>/dev/null

if [ -p "$CMD_PIPE" ] && [ -p "$RSP_PIPE" ]; then
    print_success "Communication pipes created successfully"
    print_status "Command pipe: $CMD_PIPE"
    print_status "Response pipe: $RSP_PIPE"
else
    print_error "Failed to create communication pipes"
    exit 1
fi

# Check for Vivado
if ! command -v vivado &> /dev/null; then
    print_error "Vivado not found in PATH"
    print_error "Please source Vivado settings script first:"
    print_error "  source /opt/Xilinx/Vivado/2023.2/settings64.sh"
    exit 1
fi

# Check if Python3 is available
if ! command -v python3 &> /dev/null; then
    print_error "Python 3 not found"
    exit 1
fi

# Get simulation mode from command line
SIM_MODE="xsim"
if [ "$1" = "--questa" ]; then
    SIM_MODE="questa"
elif [ "$1" = "--modelsim" ]; then
    SIM_MODE="modelsim"
elif [ "$1" = "--vcs" ]; then
    SIM_MODE="vcs"
fi

print_status "Using simulator: $SIM_MODE"

# Cleanup function
cleanup() {
    print_status "Cleaning up..."
    rm -f "$CMD_PIPE" "$RSP_PIPE"
    # Kill any background processes
    jobs -p | xargs -r kill
    exit 0
}

# Set trap for cleanup
trap cleanup SIGINT SIGTERM EXIT

# Function to run simulation with XSim
run_xsim() {
    print_status "Starting XSim simulation..."
    
    # Create simulation files directory if it doesn't exist
    mkdir -p pcie4_uscale_plus_0_ex.sim/sim_1/behav/xsim
    
    # Copy modified testbench to simulation directory
    cp imports/board_with_pipe.v imports/pipe_interface.sv pcie4_uscale_plus_0_ex.sim/sim_1/behav/xsim/
    
    # Generate XSim script
    cat > run_xsim.tcl << EOF
# XSim simulation script for PCIe with Python interface

# Add sources
add_files imports/board_with_pipe.v
add_files imports/pipe_interface.sv

# Set top module
set_property top board_with_pipe [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

# Update compile order
update_compile_order -fileset sim_1

# Launch simulation
launch_simulation -step compile
launch_simulation -step elaborate  
launch_simulation -step simulate

# Add signals to waveform
add_wave {{/board_with_pipe/sys_rst_n}}
add_wave {{/board_with_pipe/cfg_ltssm_state}}
add_wave {{/board_with_pipe/pipe_if/pipe_ready}}
add_wave {{/board_with_pipe/pipe_if/cmd_valid}}
add_wave {{/board_with_pipe/python_cmd_processing}}

# Run simulation
run 1ms

EOF

    # Run Vivado in batch mode
    vivado -mode batch -source run_xsim.tcl pcie4_uscale_plus_0_ex.xpr &
    SIM_PID=$!
    
    print_success "Simulation started (PID: $SIM_PID)"
    return $SIM_PID
}

# Function to run simulation with Questa/ModelSim
run_questa() {
    print_status "Starting Questa/ModelSim simulation..."
    
    # Use pre-generated simulation scripts
    cd pcie4_uscale_plus_0_ex.ip_user_files/sim_scripts/pcie4_uscale_plus_0/questa
    
    # Modify compile.do to include our new files
    cp compile.do compile.do.bak
    cat >> compile.do << EOF

# Add Python interface files
vlog -sv ../../../imports/pipe_interface.sv
vlog ../../../imports/board_with_pipe.v

EOF

    # Run simulation
    vsim -c -do "do compile.do; do elaborate.do; do simulate.do" &
    SIM_PID=$!
    
    cd - > /dev/null
    print_success "Simulation started (PID: $SIM_PID)"
    return $SIM_PID
}

# Start the simulation based on selected simulator
case $SIM_MODE in
    "xsim")
        run_xsim
        ;;
    "questa"|"modelsim")
        run_questa
        ;;
    *)
        print_error "Unsupported simulator: $SIM_MODE"
        exit 1
        ;;
esac

# Wait a bit for simulation to start
print_status "Waiting for simulation to initialize..."
sleep 5

# Check if pipes are accessible (simulation should open them)
timeout=30
count=0
while [ $count -lt $timeout ]; do
    if [ -p "$CMD_PIPE" ] && [ -p "$RSP_PIPE" ]; then
        # Try to check if simulation has opened the pipes
        if lsof "$CMD_PIPE" >/dev/null 2>&1 && lsof "$RSP_PIPE" >/dev/null 2>&1; then
            print_success "Simulation connected to communication pipes"
            break
        fi
    fi
    sleep 1
    ((count++))
    if [ $((count % 5)) -eq 0 ]; then
        print_status "Still waiting for simulation to connect... ($count/$timeout)"
    fi
done

if [ $count -ge $timeout ]; then
    print_warning "Simulation may not have connected to pipes yet"
    print_warning "You can still try running the Python interface"
fi

# Display usage information
print_success "PCIe Simulation with Python Interface is ready!"
echo ""
echo "You can now interact with the simulation using Python:"
echo ""
echo "  # Interactive mode:"
echo "  python3 pcie_sim_interface.py"
echo ""
echo "  # Demo mode:"
echo "  python3 pcie_sim_interface.py --demo"
echo ""
print_status "Simulation will run until terminated by Python command or Ctrl+C"
print_status "Communication pipes:"
print_status "  Command: $CMD_PIPE"
print_status "  Response: $RSP_PIPE"

# Wait for simulation to complete or be interrupted
if [ -n "$SIM_PID" ]; then
    wait $SIM_PID
    print_status "Simulation completed"
else
    # If no PID, just wait for interrupt
    while true; do
        sleep 1
    done
fi
