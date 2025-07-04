//-----------------------------------------------------------------------------
//
// Project    : UltraScale+ FPGA PCI Express v4.0 with Python Communication
// File       : pipe_interface_simple.sv
// Description: Simplified Linux PIPE interface for Python communication
//              Compatible with Vivado SystemVerilog subset
//
//-----------------------------------------------------------------------------

`timescale 1ns/1ns

interface pipe_interface_simple;
    
    // Command structure for Python communication
    typedef struct packed {
        logic [7:0]  cmd_type;     // Command type: 0x01=read, 0x02=write, 0x03=reset, etc.
        logic [31:0] address;      // Target address
        logic [31:0] data;         // Data payload
        logic [15:0] length;       // Transfer length
        logic [7:0]  tag;          // Transaction tag
        logic [7:0]  status;       // Status/error code
    } pipe_cmd_t;
    
    // Response structure
    typedef struct packed {
        logic [7:0]  rsp_type;     // Response type
        logic [31:0] read_data;    // Read data
        logic [7:0]  tag;          // Matching transaction tag
        logic [7:0]  status;       // Completion status
        logic [31:0] timestamp;    // Simulation timestamp
    } pipe_rsp_t;
    
    // Pipe file handles (exposed for direct access)
    integer cmd_pipe_fd;
    integer rsp_pipe_fd;
    
    // Command and response buffers
    pipe_cmd_t current_cmd;
    pipe_rsp_t current_rsp;
    
    // Task local variables (must be at module level in Verilog)
    int scan_result;
    int cmd_type_i, address_i, data_i, length_i, tag_i;
    string dummy_line;
    string cmd_line;
    
    // Control signals
    logic pipe_ready;
    logic cmd_valid;
    logic rsp_ready;
    
    // Initialize pipes
    task automatic init_pipes(string cmd_pipe_name = "/tmp/pcie_sim_cmd", 
                              string rsp_pipe_name = "/tmp/pcie_sim_rsp");
        // Note: Named pipes must be created externally before simulation
        // Use: mkfifo /tmp/pcie_sim_cmd /tmp/pcie_sim_rsp
        
        // Open pipes for communication
        cmd_pipe_fd = $fopen(cmd_pipe_name, "r");
        rsp_pipe_fd = $fopen(rsp_pipe_name, "w");
        
        if (cmd_pipe_fd == 0 || rsp_pipe_fd == 0) begin
            $error("Failed to open PIPE communication files. Make sure pipes exist: mkfifo %s %s", 
                   cmd_pipe_name, rsp_pipe_name);
            pipe_ready = 1'b0;
        end else begin
            $display("[%t] : PIPE interface initialized successfully", $realtime);
            $display("[%t] : Command pipe: %s", $realtime, cmd_pipe_name);
            $display("[%t] : Response pipe: %s", $realtime, rsp_pipe_name);
            pipe_ready = 1'b1;
        end
    endtask
    
    // Read command from Python using timeout-based approach
    task automatic read_command();
        if (!pipe_ready) return;
        
        // Use fork/join_any with timeout to prevent blocking
        fork
            begin
                // Try to read command using fscanf with format: "cmd:addr:data:length:tag"
                scan_result = $fscanf(cmd_pipe_fd, "%x:%x:%x:%x:%x", 
                                     cmd_type_i, address_i, data_i, length_i, tag_i);
                
                if (scan_result == 5) begin
                    current_cmd.cmd_type = cmd_type_i[7:0];
                    current_cmd.address  = address_i[31:0];
                    current_cmd.data     = data_i[31:0];
                    current_cmd.length   = length_i[15:0];
                    current_cmd.tag      = tag_i[7:0];
                    cmd_valid = 1'b1;
                    
                    $display("[%t] : Received command: type=0x%02x, addr=0x%08x, data=0x%08x", 
                            $realtime, current_cmd.cmd_type, current_cmd.address, current_cmd.data);
                end else if (scan_result > 0) begin
                    $display("[%t] : Warning: Incomplete command received (got %0d fields)", $realtime, scan_result);
                    // Consume rest of line to reset state
                    scan_result = $fgets(cmd_line, cmd_pipe_fd);
                end
            end
            begin
                // Timeout to prevent blocking (10ns timeout)
                #10;
            end
        join_any
        disable fork;
        
        // Check for pipe errors (using proper $ferror syntax)
        if ($ferror(cmd_pipe_fd, dummy_line)) begin
            $display("[%t] : Warning: Command pipe error detected: %s", $realtime, dummy_line);
        end
    endtask
    
    // Send response to Python
    task automatic send_response(pipe_rsp_t response);
        if (!pipe_ready) return;
        
        // Format response as string
        $fwrite(rsp_pipe_fd, "%02x:%08x:%02x:%02x:%08x\n", 
               response.rsp_type, response.read_data, 
               response.tag, response.status, response.timestamp);
        $fflush(rsp_pipe_fd);
        
        $display("[%t] : Sent response: type=0x%02x, data=0x%08x, status=0x%02x", 
                $realtime, response.rsp_type, response.read_data, response.status);
    endtask
    
    // Cleanup pipes
    task automatic cleanup_pipes();
        if (cmd_pipe_fd != 0) $fclose(cmd_pipe_fd);
        if (rsp_pipe_fd != 0) $fclose(rsp_pipe_fd);
        pipe_ready = 1'b0;
        $display("[%t] : PIPE interface closed", $realtime);
    endtask
    
endinterface
