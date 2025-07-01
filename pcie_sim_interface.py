#!/usr/bin/env python3
"""
PCIe Simulation Python Interface

This script provides a Python interface to communicate with the Xilinx PCIe
simulation via Linux named pipes (FIFOs).

Usage:
    python3 pcie_sim_interface.py

Command Types:
    0x01 - PCIe Configuration Read
    0x02 - PCIe Configuration Write  
    0x03 - Memory Read
    0x04 - Memory Write
    0x10 - Get Link Status
    0x11 - Reset System
    0xFF - Terminate Simulation
"""

import os
import time
import threading
import queue
import signal
import sys
from dataclasses import dataclass
from typing import Optional, Dict, Any

@dataclass
class PCIeCommand:
    """PCIe command structure"""
    cmd_type: int
    address: int
    data: int = 0
    length: int = 4
    tag: int = 0

@dataclass 
class PCIeResponse:
    """PCIe response structure"""
    rsp_type: int
    read_data: int
    tag: int
    status: int
    timestamp: int

class PCIeSimInterface:
    """PCIe Simulation Interface via Linux Pipes"""
    
    def __init__(self, cmd_pipe_path="/tmp/pcie_sim_cmd", rsp_pipe_path="/tmp/pcie_sim_rsp"):
        self.cmd_pipe_path = cmd_pipe_path
        self.rsp_pipe_path = rsp_pipe_path
        self.cmd_pipe = None
        self.rsp_pipe = None
        self.response_queue = queue.Queue()
        self.next_tag = 1
        self.running = False
        self.response_thread = None
        
    def connect(self):
        """Connect to the simulation via named pipes"""
        try:
            print(f"Connecting to PCIe simulation...")
            print(f"Command pipe: {self.cmd_pipe_path}")
            print(f"Response pipe: {self.rsp_pipe_path}")
            
            # Open pipes for communication
            self.cmd_pipe = open(self.cmd_pipe_path, 'w')
            self.rsp_pipe = open(self.rsp_pipe_path, 'r')
            
            self.running = True
            
            # Start response reader thread
            self.response_thread = threading.Thread(target=self._response_reader, daemon=True)
            self.response_thread.start()
            
            print("✓ Connected to PCIe simulation")
            return True
            
        except Exception as e:
            print(f"✗ Failed to connect: {e}")
            return False
    
    def disconnect(self):
        """Disconnect from simulation"""
        self.running = False
        
        if self.cmd_pipe:
            self.cmd_pipe.close()
            self.cmd_pipe = None
            
        if self.rsp_pipe:
            self.rsp_pipe.close()
            self.rsp_pipe = None
            
        print("Disconnected from PCIe simulation")
    
    def _response_reader(self):
        """Background thread to read responses from simulation"""
        while self.running:
            try:
                if self.rsp_pipe:
                    line = self.rsp_pipe.readline().strip()
                    if line:
                        response = self._parse_response(line)
                        if response:
                            self.response_queue.put(response)
                time.sleep(0.001)  # Small delay to prevent busy waiting
            except Exception as e:
                if self.running:
                    print(f"Error reading response: {e}")
                break
    
    def _parse_response(self, response_str: str) -> Optional[PCIeResponse]:
        """Parse response string from simulation"""
        try:
            parts = response_str.split(':')
            if len(parts) >= 5:
                return PCIeResponse(
                    rsp_type=int(parts[0], 16),
                    read_data=int(parts[1], 16),
                    tag=int(parts[2], 16),
                    status=int(parts[3], 16),
                    timestamp=int(parts[4], 16)
                )
        except Exception as e:
            print(f"Error parsing response '{response_str}': {e}")
        return None
    
    def _send_command(self, cmd: PCIeCommand) -> bool:
        """Send command to simulation"""
        try:
            cmd_str = f"{cmd.cmd_type:02x}:{cmd.address:08x}:{cmd.data:08x}:{cmd.length:04x}:{cmd.tag:02x}\n"
            self.cmd_pipe.write(cmd_str)
            self.cmd_pipe.flush()
            return True
        except Exception as e:
            print(f"Error sending command: {e}")
            return False
    
    def _wait_for_response(self, tag: int, timeout: float = 5.0) -> Optional[PCIeResponse]:
        """Wait for response with matching tag"""
        start_time = time.time()
        
        while time.time() - start_time < timeout:
            try:
                response = self.response_queue.get(timeout=0.1)
                if response.tag == tag:
                    return response
                else:
                    # Put back non-matching response
                    self.response_queue.put(response)
            except queue.Empty:
                continue
                
        print(f"Timeout waiting for response with tag {tag}")
        return None
    
    def config_read(self, address: int) -> Optional[int]:
        """Read PCIe configuration register"""
        tag = self.next_tag
        self.next_tag = (self.next_tag + 1) & 0xFF
        
        cmd = PCIeCommand(cmd_type=0x01, address=address, tag=tag)
        
        if not self._send_command(cmd):
            return None
            
        response = self._wait_for_response(tag)
        if response and response.status == 0:
            print(f"Config Read [0x{address:03x}] = 0x{response.read_data:08x}")
            return response.read_data
        else:
            print(f"Config Read [0x{address:03x}] failed")
            return None
    
    def config_write(self, address: int, data: int) -> bool:
        """Write PCIe configuration register"""
        tag = self.next_tag
        self.next_tag = (self.next_tag + 1) & 0xFF
        
        cmd = PCIeCommand(cmd_type=0x02, address=address, data=data, tag=tag)
        
        if not self._send_command(cmd):
            return False
            
        response = self._wait_for_response(tag)
        if response and response.status == 0:
            print(f"Config Write [0x{address:03x}] = 0x{data:08x} ✓")
            return True
        else:
            print(f"Config Write [0x{address:03x}] = 0x{data:08x} ✗")
            return False
    
    def memory_read(self, address: int) -> Optional[int]:
        """Read memory via PCIe"""
        tag = self.next_tag
        self.next_tag = (self.next_tag + 1) & 0xFF
        
        cmd = PCIeCommand(cmd_type=0x03, address=address, tag=tag)
        
        if not self._send_command(cmd):
            return None
            
        response = self._wait_for_response(tag)
        if response and response.status == 0:
            print(f"Memory Read [0x{address:08x}] = 0x{response.read_data:08x}")
            return response.read_data
        else:
            print(f"Memory Read [0x{address:08x}] failed")
            return None
    
    def memory_write(self, address: int, data: int) -> bool:
        """Write memory via PCIe"""
        tag = self.next_tag
        self.next_tag = (self.next_tag + 1) & 0xFF
        
        cmd = PCIeCommand(cmd_type=0x04, address=address, data=data, tag=tag)
        
        if not self._send_command(cmd):
            return False
            
        response = self._wait_for_response(tag)
        if response and response.status == 0:
            print(f"Memory Write [0x{address:08x}] = 0x{data:08x} ✓")
            return True
        else:
            print(f"Memory Write [0x{address:08x}] = 0x{data:08x} ✗")
            return False
    
    def get_link_status(self) -> Optional[int]:
        """Get PCIe link status (LTSSM state)"""
        tag = self.next_tag
        self.next_tag = (self.next_tag + 1) & 0xFF
        
        cmd = PCIeCommand(cmd_type=0x10, address=0, tag=tag)
        
        if not self._send_command(cmd):
            return None
            
        response = self._wait_for_response(tag)
        if response and response.status == 0:
            ltssm_state = response.read_data & 0x3F
            ltssm_names = {
                0x00: "Detect.Quiet",
                0x01: "Detect.Active", 
                0x02: "Polling.Active",
                0x03: "Polling.Compliance",
                0x04: "Polling.Configuration",
                0x05: "Configuration.Linkwidth.Start",
                0x06: "Configuration.Linkwidth.Accept",
                0x07: "Configuration.Lanenum.Accept",
                0x08: "Configuration.Lanenum.Wait",
                0x09: "Configuration.Complete",
                0x0A: "Configuration.Idle",
                0x0B: "Recovery.RcvrLock",
                0x0C: "Recovery.Speed",
                0x0D: "Recovery.RcvrCfg",
                0x0E: "Recovery.Idle",
                0x0F: "L0",
                0x10: "L0s",
                0x11: "L1.Entry",
                0x12: "L1.Idle",
                0x13: "L2.Idle",
                0x14: "L2.TransmitWake",
                0x15: "Disabled",
                0x16: "LoopBack",
                0x17: "Hot Reset"
            }
            state_name = ltssm_names.get(ltssm_state, f"Unknown(0x{ltssm_state:02x})")
            print(f"Link Status: {state_name} (0x{ltssm_state:02x})")
            return ltssm_state
        else:
            print("Get link status failed")
            return None
    
    def reset_system(self) -> bool:
        """Reset the PCIe system"""
        tag = self.next_tag
        self.next_tag = (self.next_tag + 1) & 0xFF
        
        cmd = PCIeCommand(cmd_type=0x11, address=0, tag=tag)
        
        if not self._send_command(cmd):
            return False
            
        response = self._wait_for_response(tag, timeout=10.0)  # Longer timeout for reset
        if response and response.status == 0:
            print("System reset completed ✓")
            return True
        else:
            print("System reset failed ✗")
            return False
    
    def terminate_simulation(self) -> bool:
        """Terminate the simulation"""
        tag = self.next_tag
        self.next_tag = (self.next_tag + 1) & 0xFF
        
        cmd = PCIeCommand(cmd_type=0xFF, address=0, tag=tag)
        
        if not self._send_command(cmd):
            return False
            
        print("Termination command sent to simulation")
        return True

def interactive_mode(sim):
    """Interactive command mode"""
    print("\n=== PCIe Simulation Interactive Mode ===")
    print("Commands:")
    print("  cr <addr>           - Config read (hex address)")
    print("  cw <addr> <data>    - Config write (hex address and data)")
    print("  mr <addr>           - Memory read (hex address)")
    print("  mw <addr> <data>    - Memory write (hex address and data)")
    print("  ls                  - Link status")
    print("  reset               - System reset")
    print("  quit/exit           - Terminate simulation")
    print("  help                - Show this help")
    print()
    
    while True:
        try:
            cmd_line = input("PCIe> ").strip().lower()
            
            if not cmd_line:
                continue
                
            parts = cmd_line.split()
            cmd = parts[0]
            
            if cmd in ['quit', 'exit']:
                sim.terminate_simulation()
                break
            elif cmd == 'help':
                print("Commands: cr <addr>, cw <addr> <data>, mr <addr>, mw <addr> <data>, ls, reset, quit")
            elif cmd == 'cr' and len(parts) == 2:
                addr = int(parts[1], 16)
                sim.config_read(addr)
            elif cmd == 'cw' and len(parts) == 3:
                addr = int(parts[1], 16)
                data = int(parts[2], 16)
                sim.config_write(addr, data)
            elif cmd == 'mr' and len(parts) == 2:
                addr = int(parts[1], 16)
                sim.memory_read(addr)
            elif cmd == 'mw' and len(parts) == 3:
                addr = int(parts[1], 16)
                data = int(parts[2], 16)
                sim.memory_write(addr, data)
            elif cmd == 'ls':
                sim.get_link_status()
            elif cmd == 'reset':
                sim.reset_system()
            else:
                print("Invalid command. Type 'help' for usage.")
                
        except KeyboardInterrupt:
            print("\nTerminating simulation...")
            sim.terminate_simulation()
            break
        except ValueError:
            print("Invalid hex value. Use format: 0x1234 or 1234")
        except Exception as e:
            print(f"Error: {e}")

def demo_sequence(sim):
    """Run a demonstration sequence"""
    print("\n=== Running Demo Sequence ===")
    
    # Wait a bit for simulation to stabilize
    print("Waiting for simulation to stabilize...")
    time.sleep(2)
    
    # Check link status
    print("\n1. Checking PCIe link status...")
    sim.get_link_status()
    
    # Read device/vendor ID
    print("\n2. Reading Device/Vendor ID (Config register 0x00)...")
    device_vendor_id = sim.config_read(0x00)
    
    if device_vendor_id:
        vendor_id = device_vendor_id & 0xFFFF
        device_id = (device_vendor_id >> 16) & 0xFFFF
        print(f"   Vendor ID: 0x{vendor_id:04x}")
        print(f"   Device ID: 0x{device_id:04x}")
    
    # Read command/status register
    print("\n3. Reading Command/Status register (Config register 0x04)...")
    cmd_status = sim.config_read(0x04)
    
    # Try to enable bus master, memory space, and I/O space
    if cmd_status is not None:
        print("\n4. Enabling Bus Master, Memory Space, and I/O Space...")
        new_cmd = (cmd_status & 0xFFFF0000) | 0x0007  # Set bits 0, 1, 2
        sim.config_write(0x04, new_cmd)
        
        # Verify the write
        print("\n5. Verifying command register update...")
        sim.config_read(0x04)
    
    # Read BAR0
    print("\n6. Reading Base Address Register 0 (Config register 0x10)...")
    bar0 = sim.config_read(0x10)
    
    # Try a memory operation if BAR0 is configured
    if bar0 and (bar0 & 0xFFFFFFF0) != 0:
        mem_addr = bar0 & 0xFFFFFFF0
        print(f"\n7. Attempting memory read from BAR0 address 0x{mem_addr:08x}...")
        sim.memory_read(mem_addr)
        
        print(f"\n8. Attempting memory write to BAR0 address 0x{mem_addr:08x}...")
        sim.memory_write(mem_addr, 0xDEADBEEF)
        
        print(f"\n9. Reading back from BAR0 address 0x{mem_addr:08x}...")
        sim.memory_read(mem_addr)
    else:
        print("\n7-9. Skipping memory operations (BAR0 not configured)")
    
    print("\n=== Demo Sequence Complete ===")

def main():
    """Main function"""
    sim = PCIeSimInterface()
    
    # Setup signal handler for clean exit
    def signal_handler(sig, frame):
        print("\nReceived interrupt signal. Terminating simulation...")
        sim.terminate_simulation()
        sim.disconnect()
        sys.exit(0)
    
    signal.signal(signal.SIGINT, signal_handler)
    
    # Connect to simulation
    if not sim.connect():
        print("Failed to connect to simulation. Make sure the simulation is running.")
        return 1
    
    try:
        # Check command line arguments
        if len(sys.argv) > 1 and sys.argv[1] == '--demo':
            demo_sequence(sim)
        else:
            interactive_mode(sim)
    finally:
        sim.disconnect()
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
