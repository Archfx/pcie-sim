//-----------------------------------------------------------------------------
//
// (c) Copyright 1995, 2007, 2023 Advanced Micro Devices, Inc. All rights reserved.
//
// This file contains confidential and proprietary information
// of AMD, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
//
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// AMD, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND AMD HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) AMD shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or AMD had been advised of the
// possibility of the same.
//
// CRITICAL APPLICATIONS
// AMD products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of AMD products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
//
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
//
//-----------------------------------------------------------------------------
//
// Project    : UltraScale+ FPGA PCI Express v4.0 Integrated Block
// File       : sample_tests.vh
// Version    : 1.3 
//-----------------------------------------------------------------------------
//
//------------------------------------------------------------------------------

else if(testname == "sample_smoke_test0")
begin


    TSK_SIMULATION_TIMEOUT(5050);

    //System Initialization
    TSK_SYSTEM_INITIALIZATION;




    
    $display("[%t] : Expected Device/Vendor ID = %x", $realtime, DEV_VEN_ID); 
    
    //--------------------------------------------------------------------------
    // Read core configuration space via PCIe fabric interface
    //--------------------------------------------------------------------------

    $display("[%t] : Reading from PCI/PCI-Express Configuration Register 0x00", $realtime);

    TSK_TX_TYPE0_CONFIGURATION_READ(DEFAULT_TAG, 12'h0, 4'hF);
    TSK_WAIT_FOR_READ_DATA;
    if  (P_READ_DATA != DEV_VEN_ID) begin
        $display("[%t] : TEST FAILED --- Data Error Mismatch, Write Data %x != Read Data %x", $realtime, 
                                    DEV_VEN_ID, P_READ_DATA);
    end
    else begin
        $display("[%t] : TEST PASSED --- Device/Vendor ID %x successfully received", $realtime, P_READ_DATA);
        $display("[%t] : Test Completed Successfully",$realtime);
    end

    //--------------------------------------------------------------------------
    // Direct Root Port to allow upstream traffic by enabling Mem, I/O and
    // BusMstr in the command register
    //--------------------------------------------------------------------------

    board_with_pipe.RP.cfg_usrapp.TSK_READ_CFG_DW(32'h00000001);
    board_with_pipe.RP.cfg_usrapp.TSK_WRITE_CFG_DW(32'h00000001, 32'h00000007, 4'b1110);
    board_with_pipe.RP.cfg_usrapp.TSK_READ_CFG_DW(32'h00000001);
    

  $finish;
end


else if(testname == "sample_smoke_test1")
begin

    // This test use tlp expectation tasks.

    TSK_SIMULATION_TIMEOUT(5050);

    // System Initialization
    TSK_SYSTEM_INITIALIZATION;
    // Program BARs (Required so Completer ID at the Endpoint is updated)
    TSK_BAR_INIT;

fork
  begin
    //--------------------------------------------------------------------------
    // Read core configuration space via PCIe fabric interface
    //--------------------------------------------------------------------------

    $display("[%t] : Reading from PCI/PCI-Express Configuration Register 0x00", $realtime);

    TSK_TX_TYPE0_CONFIGURATION_READ(DEFAULT_TAG, 12'h0, 4'hF);
    DEFAULT_TAG = DEFAULT_TAG + 1;
    TSK_TX_CLK_EAT(100);
  end
    //---------------------------------------------------------------------------
    // List Rx TLP expections
    //---------------------------------------------------------------------------
  begin
    test_vars[0] = 0;                                                                                                                         
                                          
    $display("[%t] : Expected Device/Vendor ID = %x", $realtime, DEV_VEN_ID);                                              

    expect_cpld_payload[0] = DEV_VEN_ID[31:24];
    expect_cpld_payload[1] = DEV_VEN_ID[23:16];
    expect_cpld_payload[2] = DEV_VEN_ID[15:8];
    expect_cpld_payload[3] = DEV_VEN_ID[7:0];
    @(posedge pcie_rq_tag_vld);
    exp_tag = pcie_rq_tag;

    board_with_pipe.RP.com_usrapp.TSK_EXPECT_CPLD(
      3'h0, //traffic_class;
      1'b0, //td;
      1'b0, //ep;
      2'h0, //attr;
      10'h1, //length;
      board_with_pipe.RP.tx_usrapp.EP_BUS_DEV_FNS, //completer_id;
      3'h0, //completion_status;
      1'b0, //bcm;
      12'h4, //byte_count;
      board_with_pipe.RP.tx_usrapp.RP_BUS_DEV_FNS, //requester_id;
      exp_tag ,
      7'b0, //address_low;
      expect_status //expect_status;
    );

    if (expect_status) 
      test_vars[0] = test_vars[0] + 1;      
  end
join
  
  expect_finish_check = 1;

  if (test_vars[0] == 1) begin
    $display("[%t] : TEST PASSED --- Finished transmission of PCI-Express TLPs", $realtime);
    $display("[%t] : Test Completed Successfully",$realtime);
  end else begin
    $display("[%t] : TEST FAILED --- Haven't Received All Expected TLPs", $realtime);

    //--------------------------------------------------------------------------
    // Direct Root Port to allow upstream traffic by enabling Mem, I/O and
    // BusMstr in the command register
    //--------------------------------------------------------------------------

    board_with_pipe.RP.cfg_usrapp.TSK_READ_CFG_DW(32'h00000001);
    board_with_pipe.RP.cfg_usrapp.TSK_WRITE_CFG_DW(32'h00000001, 32'h00000007, 4'b1110);
    board_with_pipe.RP.cfg_usrapp.TSK_READ_CFG_DW(32'h00000001);

  end

  $finish;
end
else if(testname == "pio_writeReadBack_test0")
begin

    // This test performs a 32 bit write to a 32 bit Memory space and performs a read back

    board_with_pipe.RP.tx_usrapp.TSK_SIMULATION_TIMEOUT(10050);

    board_with_pipe.RP.tx_usrapp.TSK_SYSTEM_INITIALIZATION;

    board_with_pipe.RP.tx_usrapp.TSK_BAR_INIT;
        
    //--------------------------------------------------------------------------
    // Direct Root Port to allow upstream traffic by enabling Mem, I/O and
    // BusMstr in the command register
    //--------------------------------------------------------------------------

    board_with_pipe.RP.cfg_usrapp.TSK_READ_CFG_DW(32'h00000001);
    board_with_pipe.RP.cfg_usrapp.TSK_WRITE_CFG_DW(32'h00000001, 32'h00000007, 4'b1110);
    board_with_pipe.RP.cfg_usrapp.TSK_READ_CFG_DW(32'h00000001);

//--------------------------------------------------------------------------
// Event : Testing BARs
//--------------------------------------------------------------------------

        for (board_with_pipe.RP.tx_usrapp.ii = 0; board_with_pipe.RP.tx_usrapp.ii <= 6; board_with_pipe.RP.tx_usrapp.ii =
            board_with_pipe.RP.tx_usrapp.ii + 1) begin
            if (board_with_pipe.RP.tx_usrapp.BAR_INIT_P_BAR_ENABLED[board_with_pipe.RP.tx_usrapp.ii] > 2'b00) // bar is enabled
               case(board_with_pipe.RP.tx_usrapp.BAR_INIT_P_BAR_ENABLED[board_with_pipe.RP.tx_usrapp.ii])
                   2'b01 : // IO SPACE
                        begin

                          $display("[%t] : Transmitting TLPs to IO Space BAR %x", $realtime, board_with_pipe.RP.tx_usrapp.ii);

                          //--------------------------------------------------------------------------
                          // Event : IO Write bit TLP
                          //--------------------------------------------------------------------------


                          board_with_pipe.RP.tx_usrapp.TSK_TX_IO_WRITE(board_with_pipe.RP.tx_usrapp.DEFAULT_TAG,
                             board_with_pipe.RP.tx_usrapp.BAR_INIT_P_BAR[board_with_pipe.RP.tx_usrapp.ii][31:0], 4'hF, 32'hdead_beef);
                             @(posedge pcie_rq_tag_vld);
                             exp_tag = pcie_rq_tag;


                          board_with_pipe.RP.com_usrapp.TSK_EXPECT_CPL(3'h0, 1'b0, 1'b0, 2'b0,
                             board_with_pipe.RP.tx_usrapp.EP_BUS_DEV_FNS, 3'h0, 1'b0, 12'h4,
                             board_with_pipe.RP.tx_usrapp.RP_BUS_DEV_FNS, exp_tag,
                             board_with_pipe.RP.tx_usrapp.BAR_INIT_P_BAR[board_with_pipe.RP.tx_usrapp.ii][31:0], test_vars[0]);

                          board_with_pipe.RP.tx_usrapp.TSK_TX_CLK_EAT(10);
                          board_with_pipe.RP.tx_usrapp.DEFAULT_TAG = board_with_pipe.RP.tx_usrapp.DEFAULT_TAG + 1;

                          //--------------------------------------------------------------------------
                          // Event : IO Read bit TLP
                          //--------------------------------------------------------------------------


                          // make sure P_READ_DATA has known initial value
                          board_with_pipe.RP.tx_usrapp.P_READ_DATA = 32'hffff_ffff;
                          fork
                             board_with_pipe.RP.tx_usrapp.TSK_TX_IO_READ(board_with_pipe.RP.tx_usrapp.DEFAULT_TAG,
                                board_with_pipe.RP.tx_usrapp.BAR_INIT_P_BAR[board_with_pipe.RP.tx_usrapp.ii][31:0], 4'hF);
                             board_with_pipe.RP.tx_usrapp.TSK_WAIT_FOR_READ_DATA;
                          join
                          if  (board_with_pipe.RP.tx_usrapp.P_READ_DATA != 32'hdead_beef)
                             begin
                               testError=1'b1;
                               $display("[%t] : Test FAILED --- Data Error Mismatch, Write Data %x != Read Data %x",
                                   $realtime, 32'hdead_beef, board_with_pipe.RP.tx_usrapp.P_READ_DATA);
                             end
                          else
                             begin
                               $display("[%t] : Test PASS --- Write Data: %x successfully received",
                                   $realtime, board_with_pipe.RP.tx_usrapp.P_READ_DATA);
                             end


                          board_with_pipe.RP.tx_usrapp.TSK_TX_CLK_EAT(10);
                          board_with_pipe.RP.tx_usrapp.DEFAULT_TAG = board_with_pipe.RP.tx_usrapp.DEFAULT_TAG + 1;


                        end

                   2'b10 : // MEM 32 SPACE
                        begin


// PIO_READWRITE_TEST CASE for C_AXIS_WIDTH == 64 

//$display("[%t] : Transmitting TLPs to Memory 32 Space BAR %x at address %x", $realtime,
                          //    board_with_pipe.RP.tx_usrapp.ii, board_with_pipe.RP.tx_usrapp.BAR_INIT_P_BAR[board_with_pipe.RP.tx_usrapp.ii][31:0]+8'h10+(board_with_pipe.RP.tx_usrapp.ii*8'h20));
                          $display("[%t] : Transmitting TLPs to Memory 32 Space BAR %x", $realtime,
                              board_with_pipe.RP.tx_usrapp.ii);

                          //--------------------------------------------------------------------------
                          // Event : Memory Write 32 bit TLP
                          //--------------------------------------------------------------------------


                          board_with_pipe.RP.tx_usrapp.DATA_STORE[0] = {board_with_pipe.RP.tx_usrapp.ii,4'h4};//8'h04;
                          board_with_pipe.RP.tx_usrapp.DATA_STORE[1] = {board_with_pipe.RP.tx_usrapp.ii,4'h3};//8'h03;
                          board_with_pipe.RP.tx_usrapp.DATA_STORE[2] = {board_with_pipe.RP.tx_usrapp.ii,4'h2};//8'h02;
                          board_with_pipe.RP.tx_usrapp.DATA_STORE[3] = {board_with_pipe.RP.tx_usrapp.ii,4'h1};//8'h01;
                          
                          // Default 1DW PIO
                          board_with_pipe.RP.tx_usrapp.TSK_TX_MEMORY_WRITE_32(board_with_pipe.RP.tx_usrapp.DEFAULT_TAG,
                                                                    board_with_pipe.RP.tx_usrapp.DEFAULT_TC, 11'd1,
                                                                    board_with_pipe.RP.tx_usrapp.BAR_INIT_P_BAR[board_with_pipe.RP.tx_usrapp.ii][31:0]+8'h10+(board_with_pipe.RP.tx_usrapp.ii*8'h40),
                                                                    4'h0, 4'hF, 1'b0);
                          board_with_pipe.RP.tx_usrapp.TSK_TX_CLK_EAT(100);
                          board_with_pipe.RP.tx_usrapp.DEFAULT_TAG = board_with_pipe.RP.tx_usrapp.DEFAULT_TAG + 1;

                          //--------------------------------------------------------------------------
                          // Event : Memory Read 32 bit TLP
                          //--------------------------------------------------------------------------


                          // make sure P_READ_DATA has known initial value
                          board_with_pipe.RP.tx_usrapp.P_READ_DATA = 32'hffff_ffff;
                          
                          // Default 1DW PIO
                          fork
                             board_with_pipe.RP.tx_usrapp.TSK_TX_MEMORY_READ_32(board_with_pipe.RP.tx_usrapp.DEFAULT_TAG,
                                                                      board_with_pipe.RP.tx_usrapp.DEFAULT_TC, 11'd1,
                                                                      board_with_pipe.RP.tx_usrapp.BAR_INIT_P_BAR[board_with_pipe.RP.tx_usrapp.ii][31:0]+8'h10+(board_with_pipe.RP.tx_usrapp.ii*8'h40),
                                                                      4'h0, 4'hF);
                             board_with_pipe.RP.tx_usrapp.TSK_WAIT_FOR_READ_DATA;
                          join

                          if  (board_with_pipe.RP.tx_usrapp.P_READ_DATA != {board_with_pipe.RP.tx_usrapp.DATA_STORE[3],
                                                                  board_with_pipe.RP.tx_usrapp.DATA_STORE[2],
                                                                  board_with_pipe.RP.tx_usrapp.DATA_STORE[1],
                                                                  board_with_pipe.RP.tx_usrapp.DATA_STORE[0] })
                          begin
                             testError=1'b1;
                             $display("[%t] : Test FAIL --- Data Error Mismatch, Write Data %x != Read Data %x",
                                      $realtime, {board_with_pipe.RP.tx_usrapp.DATA_STORE[3],board_with_pipe.RP.tx_usrapp.DATA_STORE[2],
                                                  board_with_pipe.RP.tx_usrapp.DATA_STORE[1],board_with_pipe.RP.tx_usrapp.DATA_STORE[0]},
                                      board_with_pipe.RP.tx_usrapp.P_READ_DATA);

                          end
                          else begin
                             $display("[%t] : Test PASS --- 1DW Write Data: %x successfully received",
                                      $realtime, board_with_pipe.RP.tx_usrapp.P_READ_DATA);
                          end

                          board_with_pipe.RP.tx_usrapp.TSK_TX_CLK_EAT(10);
                          board_with_pipe.RP.tx_usrapp.DEFAULT_TAG = board_with_pipe.RP.tx_usrapp.DEFAULT_TAG + 1;

                          // Optional 2DW PIO
                          board_with_pipe.RP.tx_usrapp.DATA_STORE[0] = {board_with_pipe.RP.tx_usrapp.ii+4'hA,4'h4};//8'h04;
                          board_with_pipe.RP.tx_usrapp.DATA_STORE[1] = {board_with_pipe.RP.tx_usrapp.ii+4'hA,4'h3};//8'h03;
                          board_with_pipe.RP.tx_usrapp.DATA_STORE[2] = {board_with_pipe.RP.tx_usrapp.ii+4'hA,4'h2};//8'h02;
                          board_with_pipe.RP.tx_usrapp.DATA_STORE[3] = {board_with_pipe.RP.tx_usrapp.ii+4'hA,4'h1};//8'h01;
                          
                                                    
                          board_with_pipe.RP.tx_usrapp.TSK_TX_MEMORY_WRITE_32(board_with_pipe.RP.tx_usrapp.DEFAULT_TAG,
                                                                    board_with_pipe.RP.tx_usrapp.DEFAULT_TC, 11'd2,
                                                                    board_with_pipe.RP.tx_usrapp.BAR_INIT_P_BAR[board_with_pipe.RP.tx_usrapp.ii][31:0]+8'h14+(board_with_pipe.RP.tx_usrapp.ii*8'h40),
                                                                    4'hF, 4'hF, 1'b0);
                          board_with_pipe.RP.tx_usrapp.TSK_TX_CLK_EAT(100);
                          board_with_pipe.RP.tx_usrapp.DEFAULT_TAG = board_with_pipe.RP.tx_usrapp.DEFAULT_TAG + 1;                   
                          
 
                          fork
                             board_with_pipe.RP.tx_usrapp.TSK_TX_MEMORY_READ_32(board_with_pipe.RP.tx_usrapp.DEFAULT_TAG,
                                                                      board_with_pipe.RP.tx_usrapp.DEFAULT_TC, 11'd2,
                                                                      board_with_pipe.RP.tx_usrapp.BAR_INIT_P_BAR[board_with_pipe.RP.tx_usrapp.ii][31:0]+8'h14+(board_with_pipe.RP.tx_usrapp.ii*8'h40),
                                                                      4'hF, 4'hF);
                             board_with_pipe.RP.tx_usrapp.TSK_WAIT_FOR_READ_DATA;
                          join
                          if  ( (board_with_pipe.RP.tx_usrapp.P_READ_DATA   != {board_with_pipe.RP.tx_usrapp.DATA_STORE[3],
                                                                      board_with_pipe.RP.tx_usrapp.DATA_STORE[2],
                                                                      board_with_pipe.RP.tx_usrapp.DATA_STORE[1],
                                                                      board_with_pipe.RP.tx_usrapp.DATA_STORE[0] })
                                 ||
                                (board_with_pipe.RP.tx_usrapp.P_READ_DATA_2 != {board_with_pipe.RP.tx_usrapp.DATA_STORE[3],
                                                                      board_with_pipe.RP.tx_usrapp.DATA_STORE[2],
                                                                      board_with_pipe.RP.tx_usrapp.DATA_STORE[1],
                                                                      board_with_pipe.RP.tx_usrapp.DATA_STORE[0] }) )
                          begin
                             testError=1'b1;
                             $display("[%t] : Test FAIL --- Data Error Mismatch, Write Data %x != Read Data %x",
                                       $realtime, {board_with_pipe.RP.tx_usrapp.DATA_STORE[3],board_with_pipe.RP.tx_usrapp.DATA_STORE[2],
                                                   board_with_pipe.RP.tx_usrapp.DATA_STORE[1],board_with_pipe.RP.tx_usrapp.DATA_STORE[0],
                                                   board_with_pipe.RP.tx_usrapp.DATA_STORE[3],board_with_pipe.RP.tx_usrapp.DATA_STORE[2],
                                                   board_with_pipe.RP.tx_usrapp.DATA_STORE[1],board_with_pipe.RP.tx_usrapp.DATA_STORE[0]},
                                                   {board_with_pipe.RP.tx_usrapp.P_READ_DATA,board_with_pipe.RP.tx_usrapp.P_READ_DATA_2});

                          end
                          else begin
                             $display("[%t] : Test PASS --- 2DW Write Data: %x successfully received",
                                      $realtime, {board_with_pipe.RP.tx_usrapp.P_READ_DATA,board_with_pipe.RP.tx_usrapp.P_READ_DATA_2});
                          end

                          board_with_pipe.RP.tx_usrapp.TSK_TX_CLK_EAT(10);
                          board_with_pipe.RP.tx_usrapp.DEFAULT_TAG = board_with_pipe.RP.tx_usrapp.DEFAULT_TAG + 1;

			  // Optional 192 DW PIO
                          board_with_pipe.RP.tx_usrapp.DATA_STORE[0] = {board_with_pipe.RP.tx_usrapp.ii+4'hB,4'h4};//8'hB4;
                          board_with_pipe.RP.tx_usrapp.DATA_STORE[1] = {board_with_pipe.RP.tx_usrapp.ii+4'hB,4'h3};//8'hB3;
                          board_with_pipe.RP.tx_usrapp.DATA_STORE[2] = {board_with_pipe.RP.tx_usrapp.ii+4'hB,4'h2};//8'hB2;
                          board_with_pipe.RP.tx_usrapp.DATA_STORE[3] = {board_with_pipe.RP.tx_usrapp.ii+4'hB,4'h1};//8'hB1;
                                                  
                          /*board_with_pipe.RP.tx_usrapp.TSK_TX_MEMORY_WRITE_32(board_with_pipe.RP.tx_usrapp.DEFAULT_TAG,
                                                                    board_with_pipe.RP.tx_usrapp.DEFAULT_TC, 11'd100,
                                                                    board_with_pipe.RP.tx_usrapp.BAR_INIT_P_BAR[board_with_pipe.RP.tx_usrapp.ii][31:0]+8'h20+(board_with_pipe.RP.tx_usrapp.ii*8'h40),
                                                                    4'hF, 4'hF, 1'b0);*/
                          board_with_pipe.RP.tx_usrapp.TSK_TX_MEMORY_WRITE_32(board_with_pipe.RP.tx_usrapp.DEFAULT_TAG,
                                                                    board_with_pipe.RP.tx_usrapp.DEFAULT_TC, 
                                                                    board_with_pipe.RP.tx_usrapp.dw_length,
                                                                    board_with_pipe.RP.tx_usrapp.BAR_INIT_P_BAR[board_with_pipe.RP.tx_usrapp.ii][31:0]+8'h20+(board_with_pipe.RP.tx_usrapp.ii*8'h40),
                                                                    4'hF, 4'hF, 1'b0);
                          board_with_pipe.RP.tx_usrapp.TSK_TX_CLK_EAT(100);
                          board_with_pipe.RP.tx_usrapp.DEFAULT_TAG = board_with_pipe.RP.tx_usrapp.DEFAULT_TAG + 1;                   
                          
 
                          fork
                             /*board_with_pipe.RP.tx_usrapp.TSK_TX_MEMORY_READ_32(board_with_pipe.RP.tx_usrapp.DEFAULT_TAG,
                                                                      board_with_pipe.RP.tx_usrapp.DEFAULT_TC, 11'd100,
                                                                      board_with_pipe.RP.tx_usrapp.BAR_INIT_P_BAR[board_with_pipe.RP.tx_usrapp.ii][31:0]+8'h20+(board_with_pipe.RP.tx_usrapp.ii*8'h40),
                                                                      4'hF, 4'hF);*/
                              
                             board_with_pipe.RP.tx_usrapp.TSK_TX_MEMORY_READ_32(board_with_pipe.RP.tx_usrapp.DEFAULT_TAG,
                                                                      board_with_pipe.RP.tx_usrapp.DEFAULT_TC, 
                                                                      board_with_pipe.RP.tx_usrapp.dw_length,
                                                                      board_with_pipe.RP.tx_usrapp.BAR_INIT_P_BAR[board_with_pipe.RP.tx_usrapp.ii][31:0]+8'h20+(board_with_pipe.RP.tx_usrapp.ii*8'h40),
                                                                      4'hF, 4'hF); 
                             board_with_pipe.RP.tx_usrapp.TSK_WAIT_FOR_READ_DATA;
                          join
                          if  ( (board_with_pipe.RP.tx_usrapp.P_READ_DATA   != {board_with_pipe.RP.tx_usrapp.DATA_STORE[3],
                                                                      board_with_pipe.RP.tx_usrapp.DATA_STORE[2],
                                                                      board_with_pipe.RP.tx_usrapp.DATA_STORE[1],
                                                                      board_with_pipe.RP.tx_usrapp.DATA_STORE[0] })
                                 ||
                                (board_with_pipe.RP.tx_usrapp.P_READ_DATA_2 != {board_with_pipe.RP.tx_usrapp.DATA_STORE[3],
                                                                      board_with_pipe.RP.tx_usrapp.DATA_STORE[2],
                                                                      board_with_pipe.RP.tx_usrapp.DATA_STORE[1],
                                                                      board_with_pipe.RP.tx_usrapp.DATA_STORE[0] }) )
                          begin
                             testError=1'b1;
                             $display("[%t] : Test FAIL --- Data Error Mismatch, Write Data %x != Read Data %x",
                                       $realtime, {board_with_pipe.RP.tx_usrapp.DATA_STORE[3],board_with_pipe.RP.tx_usrapp.DATA_STORE[2],
                                                   board_with_pipe.RP.tx_usrapp.DATA_STORE[1],board_with_pipe.RP.tx_usrapp.DATA_STORE[0],
                                                   board_with_pipe.RP.tx_usrapp.DATA_STORE[3],board_with_pipe.RP.tx_usrapp.DATA_STORE[2],
                                                   board_with_pipe.RP.tx_usrapp.DATA_STORE[1],board_with_pipe.RP.tx_usrapp.DATA_STORE[0]},
                                                   {board_with_pipe.RP.tx_usrapp.P_READ_DATA,board_with_pipe.RP.tx_usrapp.P_READ_DATA_2});

                          end
                          else begin
                             //$display("[%t] : Test PASS --- 192 DW Write Data: %x successfully received",
                             $display("[%t] : Test PASS --- %d DW Write Data: %x successfully received",
                                      $realtime, {board_with_pipe.RP.tx_usrapp.dw_length}, {board_with_pipe.RP.tx_usrapp.P_READ_DATA,board_with_pipe.RP.tx_usrapp.P_READ_DATA_2});
                          end

                          board_with_pipe.RP.tx_usrapp.TSK_TX_CLK_EAT(10);
                          board_with_pipe.RP.tx_usrapp.DEFAULT_TAG = board_with_pipe.RP.tx_usrapp.DEFAULT_TAG + 1; 

	



                          
	   

                     end
                2'b11 : // MEM 64 SPACE
                     begin


                          //$display("[%t] : Transmitting TLPs to Memory 64 Space BAR %x at address %x", $realtime,
                          //    board_with_pipe.RP.tx_usrapp.ii, board_with_pipe.RP.tx_usrapp.BAR_INIT_P_BAR[board_with_pipe.RP.tx_usrapp.ii][31:0]+8'h20+(board_with_pipe.RP.tx_usrapp.ii*8'h20));
                          $display("[%t] : Transmitting TLPs to Memory 64 Space BAR %x", $realtime,
                              board_with_pipe.RP.tx_usrapp.ii);


                          //--------------------------------------------------------------------------
                          // Event : Memory Write 64 bit TLP
                          //--------------------------------------------------------------------------


                          board_with_pipe.RP.tx_usrapp.DATA_STORE[0] = {board_with_pipe.RP.tx_usrapp.ii+6,4'h4};//8'h64;
                          board_with_pipe.RP.tx_usrapp.DATA_STORE[1] = {board_with_pipe.RP.tx_usrapp.ii+6,4'h3};//8'h63;
                          board_with_pipe.RP.tx_usrapp.DATA_STORE[2] = {board_with_pipe.RP.tx_usrapp.ii+6,4'h2};//8'h62;
                          board_with_pipe.RP.tx_usrapp.DATA_STORE[3] = {board_with_pipe.RP.tx_usrapp.ii+6,4'h1};//8'h61;
                          board_with_pipe.RP.tx_usrapp.DATA_STORE[4] = {board_with_pipe.RP.tx_usrapp.ii+6,4'h8};//8'h74;
                          board_with_pipe.RP.tx_usrapp.DATA_STORE[5] = {board_with_pipe.RP.tx_usrapp.ii+6,4'h7};//8'h73;
                          board_with_pipe.RP.tx_usrapp.DATA_STORE[6] = {board_with_pipe.RP.tx_usrapp.ii+6,4'h6};//8'h72;
                          board_with_pipe.RP.tx_usrapp.DATA_STORE[7] = {board_with_pipe.RP.tx_usrapp.ii+6,4'h5};//8'h71;

                          // Default 1DW PIO
                          board_with_pipe.RP.tx_usrapp.TSK_TX_MEMORY_WRITE_64(board_with_pipe.RP.tx_usrapp.DEFAULT_TAG,
                                                                    board_with_pipe.RP.tx_usrapp.DEFAULT_TC, 10'd1,
                                                                   {board_with_pipe.RP.tx_usrapp.BAR_INIT_P_BAR[board_with_pipe.RP.tx_usrapp.ii+1][31:0],
                                                                    board_with_pipe.RP.tx_usrapp.BAR_INIT_P_BAR[board_with_pipe.RP.tx_usrapp.ii][31:0]+8'h20+(board_with_pipe.RP.tx_usrapp.ii*8'h20)},
                                                                    4'h0, 4'hF, 1'b0);
                          board_with_pipe.RP.tx_usrapp.TSK_TX_CLK_EAT(10);
                          board_with_pipe.RP.tx_usrapp.DEFAULT_TAG = board_with_pipe.RP.tx_usrapp.DEFAULT_TAG + 1;

                          //--------------------------------------------------------------------------
                          // Event : Memory Read 64 bit TLP
                          //--------------------------------------------------------------------------


                          // make sure P_READ_DATA has known initial value
                          board_with_pipe.RP.tx_usrapp.P_READ_DATA = 32'hffff_ffff;

                          // Default 1DW PIO
                          fork
                             board_with_pipe.RP.tx_usrapp.TSK_TX_MEMORY_READ_64(board_with_pipe.RP.tx_usrapp.DEFAULT_TAG,
                                                                      board_with_pipe.RP.tx_usrapp.DEFAULT_TC, 10'd1,
                                                                     {board_with_pipe.RP.tx_usrapp.BAR_INIT_P_BAR[board_with_pipe.RP.tx_usrapp.ii+1][31:0],
                                                                      board_with_pipe.RP.tx_usrapp.BAR_INIT_P_BAR[board_with_pipe.RP.tx_usrapp.ii][31:0]+8'h20+(board_with_pipe.RP.tx_usrapp.ii*8'h20)},
                                                                      4'h0, 4'hF);
                             board_with_pipe.RP.tx_usrapp.TSK_WAIT_FOR_READ_DATA;
                          join

                          if  (board_with_pipe.RP.tx_usrapp.P_READ_DATA != {board_with_pipe.RP.tx_usrapp.DATA_STORE[3],
                                                                  board_with_pipe.RP.tx_usrapp.DATA_STORE[2],
                                                                  board_with_pipe.RP.tx_usrapp.DATA_STORE[1],
                                                                  board_with_pipe.RP.tx_usrapp.DATA_STORE[0] })
                          begin
                              testError=1'b1;
                              $display("[%t] : Test FAILED --- Data Error Mismatch, Write Data %x != Read Data %x",
                                       $realtime, {board_with_pipe.RP.tx_usrapp.DATA_STORE[3],
                                                   board_with_pipe.RP.tx_usrapp.DATA_STORE[2], board_with_pipe.RP.tx_usrapp.DATA_STORE[1],
                                                   board_with_pipe.RP.tx_usrapp.DATA_STORE[0]},board_with_pipe.RP.tx_usrapp.P_READ_DATA);

                          end
                          else begin
                              $display("[%t] : Test PASS --- 1DW Write Data: %x successfully received",
                                       $realtime, board_with_pipe.RP.tx_usrapp.P_READ_DATA);
                          end

                          board_with_pipe.RP.tx_usrapp.TSK_TX_CLK_EAT(10);
                          board_with_pipe.RP.tx_usrapp.DEFAULT_TAG = board_with_pipe.RP.tx_usrapp.DEFAULT_TAG + 1;

                          // Optional 2DW PIO
                          board_with_pipe.RP.tx_usrapp.DATA_STORE[0] = {board_with_pipe.RP.tx_usrapp.ii+4'hA,4'h4};//8'h04;
                          board_with_pipe.RP.tx_usrapp.DATA_STORE[1] = {board_with_pipe.RP.tx_usrapp.ii+4'hA,4'h3};//8'h03;
                          board_with_pipe.RP.tx_usrapp.DATA_STORE[2] = {board_with_pipe.RP.tx_usrapp.ii+4'hA,4'h2};//8'h02;
                          board_with_pipe.RP.tx_usrapp.DATA_STORE[3] = {board_with_pipe.RP.tx_usrapp.ii+4'hA,4'h1};//8'h01;
                          board_with_pipe.RP.tx_usrapp.DATA_STORE[4] = {board_with_pipe.RP.tx_usrapp.ii+4'hA,4'h8};//8'h14;
                          board_with_pipe.RP.tx_usrapp.DATA_STORE[5] = {board_with_pipe.RP.tx_usrapp.ii+4'hA,4'h7};//8'h13;
                          board_with_pipe.RP.tx_usrapp.DATA_STORE[6] = {board_with_pipe.RP.tx_usrapp.ii+4'hA,4'h6};//8'h12;
                          board_with_pipe.RP.tx_usrapp.DATA_STORE[7] = {board_with_pipe.RP.tx_usrapp.ii+4'hA,4'h5};//8'h11;
 
                          board_with_pipe.RP.tx_usrapp.TSK_TX_MEMORY_WRITE_64(board_with_pipe.RP.tx_usrapp.DEFAULT_TAG,
                                                                    board_with_pipe.RP.tx_usrapp.DEFAULT_TC, 10'd2,
                                                                   {board_with_pipe.RP.tx_usrapp.BAR_INIT_P_BAR[board_with_pipe.RP.tx_usrapp.ii+1][31:0],
                                                                    board_with_pipe.RP.tx_usrapp.BAR_INIT_P_BAR[board_with_pipe.RP.tx_usrapp.ii][31:0]+8'h24+(board_with_pipe.RP.tx_usrapp.ii*8'h20)},
                                                                    4'hF, 4'hF, 1'b0);
                          board_with_pipe.RP.tx_usrapp.TSK_TX_CLK_EAT(10);
                          board_with_pipe.RP.tx_usrapp.DEFAULT_TAG = board_with_pipe.RP.tx_usrapp.DEFAULT_TAG + 1;
 
                          fork
                             board_with_pipe.RP.tx_usrapp.TSK_TX_MEMORY_READ_64(board_with_pipe.RP.tx_usrapp.DEFAULT_TAG,
                                                                      board_with_pipe.RP.tx_usrapp.DEFAULT_TC, 10'd2,
                                                                     {board_with_pipe.RP.tx_usrapp.BAR_INIT_P_BAR[board_with_pipe.RP.tx_usrapp.ii+1][31:0],
                                                                      board_with_pipe.RP.tx_usrapp.BAR_INIT_P_BAR[board_with_pipe.RP.tx_usrapp.ii][31:0]+8'h24+(board_with_pipe.RP.tx_usrapp.ii*8'h20)},
                                                                      4'hF, 4'hF);
                             board_with_pipe.RP.tx_usrapp.TSK_WAIT_FOR_READ_DATA;
                          join

                          if  ( (board_with_pipe.RP.tx_usrapp.P_READ_DATA   != {board_with_pipe.RP.tx_usrapp.DATA_STORE[7],
                                                                      board_with_pipe.RP.tx_usrapp.DATA_STORE[6],
                                                                      board_with_pipe.RP.tx_usrapp.DATA_STORE[5],
                                                                      board_with_pipe.RP.tx_usrapp.DATA_STORE[4] })
                                 ||
                                (board_with_pipe.RP.tx_usrapp.P_READ_DATA_2 != {board_with_pipe.RP.tx_usrapp.DATA_STORE[3],
                                                                      board_with_pipe.RP.tx_usrapp.DATA_STORE[2],
                                                                      board_with_pipe.RP.tx_usrapp.DATA_STORE[1],
                                                                      board_with_pipe.RP.tx_usrapp.DATA_STORE[0] }) )
                          begin
                             testError=1'b1;
                             $display("[%t] : Test FAILED --- Data Error Mismatch, Write Data %x != Read Data %x",
                                       $realtime, {board_with_pipe.RP.tx_usrapp.DATA_STORE[7],board_with_pipe.RP.tx_usrapp.DATA_STORE[6],
                                                   board_with_pipe.RP.tx_usrapp.DATA_STORE[5],board_with_pipe.RP.tx_usrapp.DATA_STORE[4],
                                                   board_with_pipe.RP.tx_usrapp.DATA_STORE[3],board_with_pipe.RP.tx_usrapp.DATA_STORE[2],
                                                   board_with_pipe.RP.tx_usrapp.DATA_STORE[1],board_with_pipe.RP.tx_usrapp.DATA_STORE[0]},
                                                   {board_with_pipe.RP.tx_usrapp.P_READ_DATA,board_with_pipe.RP.tx_usrapp.P_READ_DATA_2});

                          end
                          else begin
                             $display("[%t] : Test PASS --- 2DW Write Data: %x successfully received",
                                      $realtime, {board_with_pipe.RP.tx_usrapp.P_READ_DATA,board_with_pipe.RP.tx_usrapp.P_READ_DATA_2});
                          end

                          board_with_pipe.RP.tx_usrapp.TSK_TX_CLK_EAT(10);
                          board_with_pipe.RP.tx_usrapp.DEFAULT_TAG = board_with_pipe.RP.tx_usrapp.DEFAULT_TAG + 1;

                     end
                default : $display("Error case in usrapp_tx\n");
            endcase

         end


    if(testError==1'b0)
    $display("[%t] : PASS - Test Completed Successfully",$realtime);

    if(testError==1'b1)
    $display("[%t] : FAIL - Test FAILED due to previous error ",$realtime);


    


    $display("[%t] : Finished transmission of PCI-Express TLPs", $realtime);
    $finish;
end
