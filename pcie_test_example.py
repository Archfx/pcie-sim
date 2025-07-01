#!/usr/bin/env python3
"""
Simple PCIe Test Example

This script demonstrates basic PCIe operations using the Python interface
to the Xilinx PCIe simulation.
"""

import sys
import time
from pcie_sim_interface import PCIeSimInterface

def main():
    """Simple PCIe test example"""
    
    # Create interface
    sim = PCIeSimInterface()
    
    # Connect to simulation
    print("Connecting to PCIe simulation...")
    if not sim.connect():
        print("ERROR: Failed to connect to simulation")
        print("Make sure the simulation is running with: ./run_simulation.sh")
        return 1
    
    try:
        print("Connected successfully!\n")
        
        # Wait for simulation to stabilize
        time.sleep(2)
        
        # Test 1: Check Link Status
        print("=== Test 1: Link Status ===")
        ltssm = sim.get_link_status()
        if ltssm is None:
            print("Failed to get link status")
            return 1
        
        # Test 2: Read Device/Vendor ID
        print("\n=== Test 2: Device/Vendor ID ===")
        dev_ven_id = sim.config_read(0x00)
        if dev_ven_id is None:
            print("Failed to read device/vendor ID")
            return 1
        
        vendor_id = dev_ven_id & 0xFFFF
        device_id = (dev_ven_id >> 16) & 0xFFFF
        print(f"Vendor ID: 0x{vendor_id:04X} ({'Xilinx' if vendor_id == 0x10EE else 'Unknown'})")
        print(f"Device ID: 0x{device_id:04X}")
        
        # Test 3: Read and modify command register
        print("\n=== Test 3: Command Register ===")
        cmd_reg = sim.config_read(0x04)
        if cmd_reg is None:
            print("Failed to read command register")
            return 1
            
        print(f"Current command register: 0x{cmd_reg:08X}")
        
        # Enable Bus Master, Memory Space, and I/O Space
        new_cmd = (cmd_reg & 0xFFFF0000) | 0x0007
        print(f"Enabling Bus Master, Memory, and I/O Space...")
        if sim.config_write(0x04, new_cmd):
            # Verify the change
            updated_cmd = sim.config_read(0x04)
            if updated_cmd is not None:
                print(f"Updated command register: 0x{updated_cmd:08X}")
        
        # Test 4: Read BARs
        print("\n=== Test 4: Base Address Registers ===")
        for i in range(6):
            bar_addr = 0x10 + (i * 4)
            bar_val = sim.config_read(bar_addr)
            if bar_val is not None:
                print(f"BAR{i} (0x{bar_addr:02X}): 0x{bar_val:08X}")
                
                # Check if it's a memory BAR and configured
                if bar_val != 0 and (bar_val & 0x1) == 0:  # Memory BAR
                    mem_addr = bar_val & 0xFFFFFFF0
                    if mem_addr != 0:
                        print(f"  -> Memory BAR at 0x{mem_addr:08X}")
        
        # Test 5: Simple memory test (if BAR0 is available)
        print("\n=== Test 5: Memory Access Test ===")
        bar0 = sim.config_read(0x10)
        if bar0 and (bar0 & 0xFFFFFFF0) != 0 and (bar0 & 0x1) == 0:
            mem_base = bar0 & 0xFFFFFFF0
            test_addr = mem_base
            test_data = 0x12345678
            
            print(f"Testing memory at 0x{test_addr:08X}")
            
            # Write test pattern
            if sim.memory_write(test_addr, test_data):
                # Read back
                read_data = sim.memory_read(test_addr)
                if read_data is not None:
                    if read_data == test_data:
                        print(f"✓ Memory test PASSED (wrote 0x{test_data:08X}, read 0x{read_data:08X})")
                    else:
                        print(f"✗ Memory test FAILED (wrote 0x{test_data:08X}, read 0x{read_data:08X})")
                else:
                    print("✗ Memory read failed")
            else:
                print("✗ Memory write failed")
        else:
            print("Skipping memory test (BAR0 not configured)")
        
        print("\n=== All Tests Complete ===")
        print("Simulation is still running. Use Ctrl+C to terminate or:")
        print("  python3 pcie_sim_interface.py")
        print("to enter interactive mode.")
        
    except KeyboardInterrupt:
        print("\nTest interrupted by user")
    except Exception as e:
        print(f"Test failed with error: {e}")
        return 1
    finally:
        sim.disconnect()
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
