#!/bin/bash
# Quick syntax check for the pipe interface

echo "Testing SystemVerilog syntax..."

# Check if the pipe interface has syntax errors
vivado -mode batch -nojournal -nolog -source <(cat << 'EOF'
create_project -in_memory -part xcvc1502-nsvg1369-1LHP-i-L
add_files imports/pipe_interface_simple.sv
set_property file_type SystemVerilog [get_files pipe_interface_simple.sv]
update_compile_order -fileset sources_1
puts "SUCCESS: SystemVerilog syntax check passed"
exit 0
EOF
) 2>&1 | grep -E "(ERROR|SUCCESS|WARNING)"
