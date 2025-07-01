//-----------------------------------------------------------------------------
//
// Project    : UltraScale+ FPGA PCI Express v4.0 with Python Communication
// File       : pipe_interface.sv
// Description: Linux PIPE interface for Python communication with PCIe simulation
//
//-----------------------------------------------------------------------------

`timescale 1ns/1ns

interface pipe_interface;
    
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
    
    // Pipe file handles
    integer cmd_pipe_fd;
    integer rsp_pipe_fd;
    
    // Command and response buffers
    pipe_cmd_t current_cmd;
    pipe_rsp_t current_rsp;
    
    // Control signals
    logic pipe_ready;
    logic cmd_valid;
    logic rsp_ready;
    
    // Initialize pipes
    function automatic void init_pipes(string cmd_pipe_name = "/tmp/pcie_sim_cmd", 
                                      string rsp_pipe_name = "/tmp/pcie_sim_rsp");
        int result;
        
        // Create named pipes if they don't exist
        result = $system($sformatf("mkfifo %s 2>/dev/null", cmd_pipe_name));
        result = $system($sformatf("mkfifo %s 2>/dev/null", rsp_pipe_name));
        
        // Open pipes for communication
        cmd_pipe_fd = $fopen(cmd_pipe_name, "r");
        rsp_pipe_fd = $fopen(rsp_pipe_name, "w");
        
        if (cmd_pipe_fd == 0 || rsp_pipe_fd == 0) begin
            $error("Failed to open PIPE communication files");
            pipe_ready = 1'b0;
        end else begin
            $display("[%t] : PIPE interface initialized successfully", $realtime);
            $display("[%t] : Command pipe: %s", $realtime, cmd_pipe_name);
            $display("[%t] : Response pipe: %s", $realtime, rsp_pipe_name);
            pipe_ready = 1'b1;
        end
    endfunction
    
    // Read command from Python
    task automatic read_command();
        int bytes_read;
        string cmd_str;
        
        if (!pipe_ready) return;
        
        // Read command string from pipe (expecting JSON-like format)
        bytes_read = $fgets(cmd_str, cmd_pipe_fd);
        
        if (bytes_read > 0) begin
            // Parse command string (simplified - expecting format: "cmd:addr:data:length:tag")
            if (parse_command_string(cmd_str, current_cmd)) begin
                cmd_valid = 1'b1;
                $display("[%t] : Received command: type=0x%02x, addr=0x%08x, data=0x%08x", 
                        $realtime, current_cmd.cmd_type, current_cmd.address, current_cmd.data);
            end
        end
    endtask
    
    // Send response to Python
    task automatic send_response(pipe_rsp_t response);
        string rsp_str;
        
        if (!pipe_ready) return;
        
        // Format response as string
        rsp_str = $sformatf("%02x:%08x:%02x:%02x:%08x\n", 
                           response.rsp_type, response.read_data, 
                           response.tag, response.status, response.timestamp);
        
        $fwrite(rsp_pipe_fd, "%s", rsp_str);
        $fflush(rsp_pipe_fd);
        
        $display("[%t] : Sent response: type=0x%02x, data=0x%08x, status=0x%02x", 
                $realtime, response.rsp_type, response.read_data, response.status);
    endtask
    
    // Parse command string (simple format parser)
    function automatic bit parse_command_string(string cmd_str, ref pipe_cmd_t cmd);
        string tokens[6];
        int num_tokens;
        
        // Split string by colons
        num_tokens = split_string(cmd_str, ":", tokens);
        
        if (num_tokens >= 5) begin
            cmd.cmd_type = tokens[0].atohex();
            cmd.address  = tokens[1].atohex();
            cmd.data     = tokens[2].atohex();
            cmd.length   = tokens[3].atohex();
            cmd.tag      = tokens[4].atohex();
            return 1'b1;
        end
        
        return 1'b0;
    endfunction
    
    // Helper function to split strings
    function automatic int split_string(string str, string delimiter, ref string tokens[]);
        int pos = 0;
        int start = 0;
        int count = 0;
        
        while (pos < str.len() && count < 6) begin
            pos = str.substr(start, str.len()-1).find(delimiter);
            if (pos == -1) begin
                tokens[count] = str.substr(start, str.len()-1);
                count++;
                break;
            end else begin
                tokens[count] = str.substr(start, start + pos - 1);
                count++;
                start = start + pos + 1;
            end
        end
        
        return count;
    endfunction
    
    // Cleanup pipes
    function automatic void cleanup_pipes();
        if (cmd_pipe_fd != 0) $fclose(cmd_pipe_fd);
        if (rsp_pipe_fd != 0) $fclose(rsp_pipe_fd);
        pipe_ready = 1'b0;
        $display("[%t] : PIPE interface closed", $realtime);
    endfunction
    
endinterface
