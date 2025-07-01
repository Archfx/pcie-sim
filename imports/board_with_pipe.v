//-----------------------------------------------------------------------------
//
// (c) Copyright 1995, 2007, 2023 Advanced Micro Devices, Inc. All rights reserved.
//
// Project    : UltraScale+ FPGA PCI Express v4.0 with Python Communication
// File       : board_with_pipe.v
// Version    : 1.3 
// Description: Top level testbench with Python PIPE communication interface
//
//------------------------------------------------------------------------------

`timescale 1ns/1ns

`include "board_common.vh"

module board_with_pipe;

  parameter          REF_CLK_FREQ       = 0 ;      // 0 - 100 MHz, 1 - 125 MHz,  2 - 250 MHz
  parameter    [4:0] LINK_WIDTH         = 5'd1;
  `ifdef LINKSPEED
  localparam   [3:0] LINK_SPEED_US      = 4'h`LINKSPEED;
  `else
  localparam   [3:0] LINK_SPEED_US      = 4'h1;
  `endif
  localparam   [1:0] LINK_SPEED         = (LINK_SPEED_US == 4'h8) ? 2'h3 :
                                          (LINK_SPEED_US == 4'h4) ? 2'h2 :
                                          (LINK_SPEED_US == 4'h2) ? 2'h1 : 2'h0;

  localparam         REF_CLK_HALF_CYCLE = (REF_CLK_FREQ == 0) ? 5000 :
                                          (REF_CLK_FREQ == 1) ? 4000 :
                                          (REF_CLK_FREQ == 2) ? 2000 : 0;

  localparam   MAX_PAYLOAD_SIZE = 3; 
  localparam      [2:0] PF0_DEV_CAP_MAX_PAYLOAD_SIZE = (MAX_PAYLOAD_SIZE == 0) ? 3'b000 :
                                                      (MAX_PAYLOAD_SIZE == 1) ? 3'b001 :
                                                      (MAX_PAYLOAD_SIZE == 2) ? 3'b010 : 3'b011;
 
  localparam EXT_PIPE_SIM = "FALSE";
  localparam MSI_INT  = 32 ;
  localparam  PL_LINK_CAP_MAX_LINK_WIDTH   = 4'h1;
  localparam AXI4_CQ_TUSER_WIDTH          = 88;
  localparam AXI4_CC_TUSER_WIDTH          = 33;
  localparam AXI4_RQ_TUSER_WIDTH          = 62; 
  localparam AXI4_RC_TUSER_WIDTH          = 75;
  localparam AXI4_CC_TREADY_WIDTH         = 4 ;
  localparam AXI4_RQ_TREADY_WIDTH         = 4 ; 
  localparam AXI4_DATA_WIDTH              = 64;
  localparam AXI4_TKEEP_WIDTH            = 4; 

  integer            i;

  // System-level clock and reset
  reg                sys_rst_n;

  wire               ep_sys_clk_p;
  wire               ep_sys_clk_n;
  wire               rp_sys_clk_p;
  wire               rp_sys_clk_n;

  // PCI-Express Serial Interconnect
  wire  [(LINK_WIDTH-1):0]  ep_pci_exp_txn;
  wire  [(LINK_WIDTH-1):0]  ep_pci_exp_txp;
  wire  [(LINK_WIDTH-1):0]  rp_pci_exp_txn;
  wire  [(LINK_WIDTH-1):0]  rp_pci_exp_txp;
  wire  [14:0] rp_txn;
  wire  [14:0] rp_txp;

  // Ltssm debug signal
  wire [5:0]     cfg_ltssm_state;
  assign cfg_ltssm_state   =  board_with_pipe.EP.pcie4_uscale_plus_0_i.inst.cfg_ltssm_state;

  // Python PIPE communication interface
  pipe_interface pipe_if();
  
  // Command processing variables
  reg python_cmd_processing = 1'b0;
  reg [31:0] python_read_data;
  reg [7:0] python_response_status;
  
  // Include PCIe test tasks
  `include "pci_exp_expect_tasks.vh"

  sys_clk_gen_ds # (
    .halfcycle(REF_CLK_HALF_CYCLE),
    .offset(0)
  )
  CLK_GEN_RP (
    .sys_clk_p(rp_sys_clk_p),
    .sys_clk_n(rp_sys_clk_n)
  );

  sys_clk_gen_ds # (
    .halfcycle(REF_CLK_HALF_CYCLE),
    .offset(0)
  )
  CLK_GEN_EP (
    .sys_clk_p(ep_sys_clk_p),
    .sys_clk_n(ep_sys_clk_n)
  );

  //------------------------------------------------------------------------------//
  // Generate system-level reset
  //------------------------------------------------------------------------------//
  initial begin
    $display("[%t] : System Reset Is Asserted...", $realtime);
    sys_rst_n = 1'b0;
    repeat (500) @(posedge rp_sys_clk_p);
    $display("[%t] : System Reset Is De-asserted...", $realtime);
    sys_rst_n = 1'b1;
  end

  //------------------------------------------------------------------------------//
  // Simulation endpoint with PIO Slave
  //------------------------------------------------------------------------------//
  xilinx_pcie4_uscale_ep 
  EP (
    // SYS Inteface
    .sys_clk_n(ep_sys_clk_n),
    .sys_clk_p(ep_sys_clk_p),
    .sys_rst_n(sys_rst_n),

    // PCI-Express Serial Interface
    .pci_exp_txn(ep_pci_exp_txn),
    .pci_exp_txp(ep_pci_exp_txp),
    .pci_exp_rxn(rp_pci_exp_txn),
    .pci_exp_rxp(rp_pci_exp_txp)
  );

  //------------------------------------------------------------------------------//
  // Simulation Root Port Model
  //------------------------------------------------------------------------------//
  xilinx_pcie4_uscale_rp # (
    .PF0_DEV_CAP_MAX_PAYLOAD_SIZE(PF0_DEV_CAP_MAX_PAYLOAD_SIZE)) RP (

    // SYS Inteface
    .sys_clk_n(rp_sys_clk_n),
    .sys_clk_p(rp_sys_clk_p),
    .sys_rst_n(sys_rst_n),

    // PCI-Express Serial Interface
    .pci_exp_txn({rp_txn,rp_pci_exp_txn}),
    .pci_exp_txp({rp_txp,rp_pci_exp_txp}),
    .pci_exp_rxn({15'b0,ep_pci_exp_txn}),
    .pci_exp_rxp({15'b0,ep_pci_exp_txp})
  );

  //------------------------------------------------------------------------------//
  // Python PIPE Communication Handler
  //------------------------------------------------------------------------------//
  initial begin
    // Initialize PIPE interface
    pipe_if.init_pipes();
    
    // Wait for system initialization
    wait(sys_rst_n);
    repeat(1000) @(posedge rp_sys_clk_p);
    
    // Initialize PCIe system
    TSK_SYSTEM_INITIALIZATION;
    
    $display("[%t] : PCIe system initialized. Ready for Python commands.", $realtime);
    
    // Main command processing loop
    forever begin
      // Check for commands from Python
      pipe_if.read_command();
      
      if (pipe_if.cmd_valid) begin
        python_cmd_processing = 1'b1;
        process_python_command();
        pipe_if.cmd_valid = 1'b0;
        python_cmd_processing = 1'b0;
      end
      
      // Small delay to prevent busy waiting
      #1000; // 1us delay
    end
  end

  //------------------------------------------------------------------------------//
  // Process Python Commands
  //------------------------------------------------------------------------------//
  task process_python_command();
    pipe_interface::pipe_rsp_t response;
    
    response.tag = pipe_if.current_cmd.tag;
    response.timestamp = $realtime;
    response.status = 8'h00; // Success by default
    
    case (pipe_if.current_cmd.cmd_type)
      8'h01: begin // PCIe Configuration Read
        $display("[%t] : Python CMD: Config Read - Addr: 0x%08x", $realtime, pipe_if.current_cmd.address);
        TSK_TX_TYPE0_CONFIGURATION_READ(pipe_if.current_cmd.tag, pipe_if.current_cmd.address[11:0], 4'hF);
        TSK_WAIT_FOR_READ_DATA;
        response.rsp_type = 8'h01;
        response.read_data = P_READ_DATA;
        $display("[%t] : Python RSP: Config Read Data: 0x%08x", $realtime, response.read_data);
      end
      
      8'h02: begin // PCIe Configuration Write
        $display("[%t] : Python CMD: Config Write - Addr: 0x%08x, Data: 0x%08x", 
                $realtime, pipe_if.current_cmd.address, pipe_if.current_cmd.data);
        TSK_TX_TYPE0_CONFIGURATION_WRITE(pipe_if.current_cmd.tag, pipe_if.current_cmd.address[11:0], 
                                        pipe_if.current_cmd.data, 4'hF);
        response.rsp_type = 8'h02;
        response.read_data = 32'h00000000;
      end
      
      8'h03: begin // Memory Read
        $display("[%t] : Python CMD: Memory Read - Addr: 0x%08x, Length: %d", 
                $realtime, pipe_if.current_cmd.address, pipe_if.current_cmd.length);
        TSK_TX_MEMORY_READ_32(pipe_if.current_cmd.tag, pipe_if.current_cmd.address, 4'hF);
        TSK_WAIT_FOR_READ_DATA;
        response.rsp_type = 8'h03;
        response.read_data = P_READ_DATA;
        $display("[%t] : Python RSP: Memory Read Data: 0x%08x", $realtime, response.read_data);
      end
      
      8'h04: begin // Memory Write
        $display("[%t] : Python CMD: Memory Write - Addr: 0x%08x, Data: 0x%08x", 
                $realtime, pipe_if.current_cmd.address, pipe_if.current_cmd.data);
        TSK_TX_MEMORY_WRITE_32(pipe_if.current_cmd.tag, pipe_if.current_cmd.address, 
                              pipe_if.current_cmd.data, 4'hF);
        response.rsp_type = 8'h04;
        response.read_data = 32'h00000000;
      end
      
      8'h10: begin // Get Link Status
        response.rsp_type = 8'h10;
        response.read_data = {26'h0, cfg_ltssm_state};
        $display("[%t] : Python RSP: Link Status (LTSSM): 0x%02x", $realtime, cfg_ltssm_state);
      end
      
      8'h11: begin // Reset System
        $display("[%t] : Python CMD: System Reset", $realtime);
        sys_rst_n = 1'b0;
        repeat(100) @(posedge rp_sys_clk_p);
        sys_rst_n = 1'b1;
        repeat(1000) @(posedge rp_sys_clk_p);
        TSK_SYSTEM_INITIALIZATION;
        response.rsp_type = 8'h11;
        response.read_data = 32'h00000000;
      end
      
      8'hFF: begin // Terminate simulation
        $display("[%t] : Python CMD: Terminate Simulation", $realtime);
        response.rsp_type = 8'hFF;
        response.read_data = 32'h00000000;
        pipe_if.send_response(response);
        pipe_if.cleanup_pipes();
        $display("[%t] : Simulation terminated by Python command", $realtime);
        $finish;
      end
      
      default: begin
        $display("[%t] : Python CMD: Unknown command type: 0x%02x", $realtime, pipe_if.current_cmd.cmd_type);
        response.rsp_type = 8'hEE; // Error response
        response.read_data = 32'hDEADBEEF;
        response.status = 8'h01; // Error status
      end
    endcase
    
    // Send response back to Python
    pipe_if.send_response(response);
  endtask

  //------------------------------------------------------------------------------//
  // Simulation timeout and cleanup
  //------------------------------------------------------------------------------//
  initial begin
    #50000000;  // 50ms timeout (increased for Python interaction)
    $display("[%t] : Simulation timeout. Cleaning up PIPE interface...", $realtime);
    pipe_if.cleanup_pipes();
    $display("[%t] : TEST FAILED - TIMEOUT", $realtime);
    #100;
    $finish;
  end

  //------------------------------------------------------------------------------//
  // Waveform dump
  //------------------------------------------------------------------------------//
  initial begin
    if ($test$plusargs ("dump_all")) begin
      `ifdef NCV // Cadence TRN dump
        $recordsetup("design=board_with_pipe",
                     "compress",
                     "wrapsize=100M",
                     "version=1",
                     "run=1");
        $recordvars();
      `elsif VCS //Synopsys VPD dump
        $vcdplusfile("board_with_pipe.vpd");
        $vcdpluson;
        $vcdplusglitchon;
        $vcdplusflush;
      `else
        // Verilog VC dump
        $dumpfile("board_with_pipe.vcd");
        $dumpvars(0, board_with_pipe);
      `endif
    end
  end

endmodule // board_with_pipe
