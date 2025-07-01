# PCIe Simulation with Python Interface

This project has been modified to support communication between the Xilinx PCIe simulation and Python scripts via Linux named pipes (FIFOs).

## Overview

The original PCIe testbench has been enhanced with:

1. **`pipe_interface.sv`** - SystemVerilog interface for Linux pipe communication
2. **`board_with_pipe.v`** - Modified testbench with Python command processing
3. **`pcie_sim_interface.py`** - Python interface for simulation control
4. **`run_simulation.sh`** - Automated script to setup and run simulation

## Features

### Supported Commands from Python:

- **0x01** - PCIe Configuration Read
- **0x02** - PCIe Configuration Write  
- **0x03** - Memory Read
- **0x04** - Memory Write
- **0x10** - Get Link Status (LTSSM state)
- **0x11** - Reset System
- **0xFF** - Terminate Simulation

### Communication Protocol:

**Command Format (Python → Simulation):**
```
<cmd_type>:<address>:<data>:<length>:<tag>
```

**Response Format (Simulation → Python):**
```
<rsp_type>:<read_data>:<tag>:<status>:<timestamp>
```

## Quick Start

### 1. Setup Environment

Make sure Vivado is in your PATH:
```bash
source /opt/Xilinx/Vivado/2023.2/settings64.sh
```

### 2. Run Simulation

Start the simulation with Python interface:
```bash
./run_simulation.sh
```

For other simulators:
```bash
./run_simulation.sh --questa    # Use Questa/ModelSim
./run_simulation.sh --vcs       # Use VCS
```

### 3. Python Interface

Once simulation is running, open a new terminal and use Python to interact:

**Interactive Mode:**
```bash
python3 pcie_sim_interface.py
```

**Demo Mode:**
```bash
python3 pcie_sim_interface.py --demo
```

## Python Interface Examples

### Interactive Commands:

```
PCIe> cr 00           # Read config register 0x00 (Device/Vendor ID)
PCIe> cw 04 00000007  # Write config register 0x04 (Enable Bus Master, Mem, I/O)
PCIe> mr 10000000     # Read memory at address 0x10000000
PCIe> mw 10000000 deadbeef  # Write 0xDEADBEEF to address 0x10000000
PCIe> ls              # Get link status
PCIe> reset           # Reset the system
PCIe> quit            # Terminate simulation
```

### Programmatic Usage:

```python
from pcie_sim_interface import PCIeSimInterface

# Connect to simulation
sim = PCIeSimInterface()
sim.connect()

# Read Device/Vendor ID
device_vendor_id = sim.config_read(0x00)
print(f"Device/Vendor ID: 0x{device_vendor_id:08x}")

# Enable bus master
sim.config_write(0x04, 0x00000007)

# Check link status  
ltssm_state = sim.get_link_status()

# Cleanup
sim.terminate_simulation()
sim.disconnect()
```

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Python App    │    │  Named Pipes    │    │   Simulation    │
│                 │    │                 │    │                 │
│ pcie_sim_       │◄──►│ /tmp/pcie_sim_  │◄──►│ board_with_     │
│ interface.py    │    │ cmd & _rsp      │    │ pipe.v          │
│                 │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Files Modified/Added

### New Files:
- `imports/pipe_interface.sv` - SystemVerilog PIPE communication interface
- `imports/board_with_pipe.v` - Modified testbench with Python support
- `pcie_sim_interface.py` - Python interface library
- `run_simulation.sh` - Simulation launcher script
- `README_PYTHON.md` - This documentation

### Original Files (unchanged):
- `imports/xilinx_pcie4_uscale_ep.v` - PCIe endpoint
- `imports/board.v` - Original testbench
- All other original project files remain intact

## Communication Pipes

The simulation uses two named pipes for bidirectional communication:

- **Command Pipe:** `/tmp/pcie_sim_cmd` (Python writes, Simulation reads)
- **Response Pipe:** `/tmp/pcie_sim_rsp` (Simulation writes, Python reads)

## Error Handling

- Communication timeouts (default 5 seconds)
- Pipe connection failures
- Invalid command formats
- Simulation error responses

## Troubleshooting

### "Failed to connect" error:
- Make sure simulation is running first
- Check that named pipes exist: `ls -la /tmp/pcie_sim_*`
- Verify Vivado simulation is active

### Simulation hangs:
- Use Ctrl+C to terminate both simulation and Python
- Clean up pipes: `rm -f /tmp/pcie_sim_*`

### Permission errors:
- Ensure script is executable: `chmod +x run_simulation.sh`
- Check pipe permissions: `ls -la /tmp/pcie_sim_*`

## Advanced Usage

### Custom Command Types:

You can extend the command set by modifying the `process_python_command()` task in `board_with_pipe.v` and adding corresponding methods in the Python interface.

### Multiple Python Clients:

The current design supports one Python client at a time. For multiple clients, implement a message queuing system or modify the pipe handling.

### Simulation Debugging:

Enable waveform dumping with:
```bash
./run_simulation.sh +dump_all
```

This creates `board_with_pipe.vcd` for waveform analysis.

## License

This enhancement maintains the original AMD/Xilinx license terms for the PCIe IP components.
