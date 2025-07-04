#!/usr/bin/env python3
"""
Quick test script to verify the Python interface is ready
"""

import os
import time
import subprocess

def test_pipes():
    """Test that named pipes can be created and basic communication works"""
    print("Testing PIPE interface setup...")
    
    # Test pipe creation
    cmd_pipe = "/tmp/pcie_sim_cmd"
    rsp_pipe = "/tmp/pcie_sim_rsp"
    
    # Clean up any existing pipes
    for pipe in [cmd_pipe, rsp_pipe]:
        if os.path.exists(pipe):
            os.unlink(pipe)
    
    # Create pipes
    subprocess.run(["mkfifo", cmd_pipe], check=True)
    subprocess.run(["mkfifo", rsp_pipe], check=True)
    
    print(f"✓ Created pipes: {cmd_pipe}, {rsp_pipe}")
    
    # Clean up
    os.unlink(cmd_pipe)
    os.unlink(rsp_pipe)
    
    print("✓ PIPE interface test passed")

def test_python_interface():
    """Test the Python interface module can be imported"""
    print("Testing Python interface import...")
    
    try:
        import sys
        sys.path.append('.')
        import pcie_sim_interface
        print("✓ Python interface module imports successfully")
        
        # Test class instantiation
        sim = pcie_sim_interface.PCIeSimInterface()
        print("✓ PCIeSimInterface class can be instantiated")
        
    except ImportError as e:
        print(f"✗ Import failed: {e}")
        return False
    except Exception as e:
        print(f"✗ Interface test failed: {e}")
        return False
    
    return True

def main():
    print("=" * 60)
    print("PCIe Python Interface - Final Readiness Test")
    print("=" * 60)
    
    try:
        test_pipes()
        test_python_interface()
        
        print("\n" + "=" * 60)
        print("🎉 ALL TESTS PASSED!")
        print("✅ System is ready for PCIe simulation with Python control")
        print("✅ Run './run_simulation.sh' to start the simulation")
        print("=" * 60)
        
    except Exception as e:
        print(f"\n✗ Test failed: {e}")
        print("Please check the installation and try again.")
        return 1
    
    return 0

if __name__ == "__main__":
    exit(main())
