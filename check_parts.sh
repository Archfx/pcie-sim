#!/bin/bash
#
# Check available Xilinx parts in Vivado installation
#

echo "Checking available Xilinx parts..."

if ! command -v vivado &> /dev/null; then
    echo "ERROR: Vivado not found in PATH"
    exit 1
fi

# Create a temporary script to list parts
cat > list_parts.tcl << 'EOF'
# List available parts
puts "Available UltraScale+ parts:"
set usp_parts [get_parts -filter {FAMILY =~ "*UltraScale+*"}]
if {[llength $usp_parts] > 0} {
    foreach part [lrange $usp_parts 0 4] {
        puts "  $part"
    }
    if {[llength $usp_parts] > 5} {
        puts "  ... and [expr [llength $usp_parts] - 5] more"
    }
} else {
    puts "  No UltraScale+ parts found"
}

puts "\nAvailable UltraScale parts:"
set us_parts [get_parts -filter {FAMILY =~ "*UltraScale*" && FAMILY !~ "*UltraScale+*"}]
if {[llength $us_parts] > 0} {
    foreach part [lrange $us_parts 0 4] {
        puts "  $part"
    }
    if {[llength $us_parts] > 5} {
        puts "  ... and [expr [llength $us_parts] - 5] more"
    }
} else {
    puts "  No UltraScale parts found"
}

puts "\nSample Kintex UltraScale+ parts:"
set ku_parts [get_parts -filter {FAMILY =~ "*Kintex*" && FAMILY =~ "*UltraScale+*"}]
if {[llength $ku_parts] > 0} {
    foreach part [lrange $ku_parts 0 2] {
        puts "  $part"
    }
} else {
    puts "  No Kintex UltraScale+ parts found"
}

# Suggest a good part for PCIe
puts "\nRecommended part for PCIe testing:"
if {[llength $ku_parts] > 0} {
    puts "  [lindex $ku_parts 0]"
} elseif {[llength $usp_parts] > 0} {
    puts "  [lindex $usp_parts 0]"
} elseif {[llength $us_parts] > 0} {
    puts "  [lindex $us_parts 0]"
} else {
    set all_parts [get_parts]
    if {[llength $all_parts] > 0} {
        puts "  [lindex $all_parts 0] (generic fallback)"
    } else {
        puts "  ERROR: No parts available!"
    }
}

exit 0
EOF

echo "Querying Vivado for available parts..."
vivado -mode batch -source list_parts.tcl -nojournal -nolog

# Cleanup
rm -f list_parts.tcl
