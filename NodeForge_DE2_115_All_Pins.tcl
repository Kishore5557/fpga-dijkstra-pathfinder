# NodeForge Dynamic Dijkstra - DE2-115 complete controls, clock, status LED and VGA pins
# Created 28 October 2026 for NodeForge_FPGA_Implementation.zip.
# Reference: Final DE2-115_Pin_assignment_tickle_file.txt supplied by the user.
# This is for DE2-115 (EP4CE115F29 package), not the original Cyclone II DE2.
#
# USAGE:
# Open the NodeForge Quartus project and select dijkstra_fpga_top as top entity.
# Run this file in Quartus through Tools > Tcl Scripts, or the Tcl Console:
#   source {C:/your_folder/NodeForge_DE2_115_All_Pins.tcl}
# Assignments are saved to the current project's QSF. Recompile and program.
#
# KEY[0] = RESET (press to reset, release to boot)
# KEY[1] = START (captures both source and target)
# KEY[2] = STOP
# KEY[3] = results page / next page / return to graph
# SW[6:0] = source ID, SW[13:7] = target ID
# SW[0] and SW[7] are the respective least significant bits.
# Source = sum(SW[i]*2^i), i=0..6
# Target = sum(SW[i+7]*2^i), i=0..6
# Wait for LEDR[7] (ready); let switches settle before pressing START.
# IDs must be below active N and no greater than 99.
# Example 0 -> 15: SW[6:0]=0000000, SW[13:7]=0001111.
# Thus SW7, SW8, SW9, SW10 ON; all other used switches OFF.
#
# Voltage assumption: factory JP7 setting = 2.5 V for switches/buttons.
# If JP7 was changed, match nodeforge_controls_io_standard to actual VCCIO.
# Supported Quartus names: "1.5 V", "1.8 V", "2.5 V", "3.3-V LVTTL".
# CLOCK_50 is fixed 3.3-V LVTTL; red LED pins are fixed 2.5 V.
# Manual: https://www.terasic.com.tw/wiki/images/f/ff/DE2_115_User_manual_2013.pdf
# Tables 4-1, 4-2, 4-3, 4-5, 4-16 and JP7 Table 4-8.
# VGA source: https://www.terasic.com.tw/attachment/archive/502/DE2_115_User_manual.pdf
#
# This replacement covers ALL 60 top-level pins, including all 29 VGA signals.
# It does not add RTL files, change the FPGA device, or supply timing constraints.
# After running: perform FULL compilation; program the NEW .sof from that build;
# press and release KEY0. The graph/status screen does not require KEY1.
# A previous .sof does not contain these newly saved pin assignments.
# Checked with a Tcl interpreter and a mocked Quartus command interface;
# actual Quartus compilation and physical board operation are not verified.

package require ::quartus::project

if {![is_project_open]} {
    error {Open the NodeForge Quartus project before running this file.}
}
set nodeforge_device [get_global_assignment -name DEVICE]
if {![string match -nocase {EP4CE115F29*} $nodeforge_device]} {
    error {This file requires a DE2-115 EP4CE115F29 device. Check Assignments > Device; do not use these pins for an original DE2.}
}
if {[get_global_assignment -name TOP_LEVEL_ENTITY] ne {dijkstra_fpga_top}} {
    error {Set the top-level entity to dijkstra_fpga_top from the new NodeForge package.}
}

set nodeforge_controls_io_standard {2.5 V}

# Clock
set_location_assignment PIN_Y2 -to {CLOCK_50}
set_instance_assignment -name IO_STANDARD {3.3-V LVTTL} -to {CLOCK_50}

# Buttons
set_location_assignment PIN_M23 -to {KEY[0]}
set_location_assignment PIN_M21 -to {KEY[1]}
set_location_assignment PIN_N21 -to {KEY[2]}
set_location_assignment PIN_R24 -to {KEY[3]}

# Source node: SW0 is bit 0; SW6 is bit 6.
set_location_assignment PIN_AB28 -to {SW[0]}
set_location_assignment PIN_AC28 -to {SW[1]}
set_location_assignment PIN_AC27 -to {SW[2]}
set_location_assignment PIN_AD27 -to {SW[3]}
set_location_assignment PIN_AB27 -to {SW[4]}
set_location_assignment PIN_AC26 -to {SW[5]}
set_location_assignment PIN_AD26 -to {SW[6]}

# Target node: SW7 is bit 0; SW13 is bit 6.
set_location_assignment PIN_AB26 -to {SW[7]}
set_location_assignment PIN_AC25 -to {SW[8]}
set_location_assignment PIN_AB25 -to {SW[9]}
set_location_assignment PIN_AC24 -to {SW[10]}
set_location_assignment PIN_AB24 -to {SW[11]}
set_location_assignment PIN_AB23 -to {SW[12]}
set_location_assignment PIN_AA24 -to {SW[13]}

foreach nodeforge_port {
    KEY[0] KEY[1] KEY[2] KEY[3]
    SW[0] SW[1] SW[2] SW[3] SW[4] SW[5] SW[6]
    SW[7] SW[8] SW[9] SW[10] SW[11] SW[12] SW[13]
} {
    set_instance_assignment -name IO_STANDARD $nodeforge_controls_io_standard -to $nodeforge_port
}

# LED0..6: accepted source ID; LED7: ready; LED8: busy; LED9: done;
# LED10: no path; LED11: graph/selection error or stopped.
set_location_assignment PIN_G19 -to {LEDR[0]}
set_location_assignment PIN_F19 -to {LEDR[1]}
set_location_assignment PIN_E19 -to {LEDR[2]}
set_location_assignment PIN_F21 -to {LEDR[3]}
set_location_assignment PIN_F18 -to {LEDR[4]}
set_location_assignment PIN_E18 -to {LEDR[5]}
set_location_assignment PIN_J19 -to {LEDR[6]}
set_location_assignment PIN_H19 -to {LEDR[7]}
set_location_assignment PIN_J17 -to {LEDR[8]}
set_location_assignment PIN_G17 -to {LEDR[9]}
set_location_assignment PIN_J15 -to {LEDR[10]}
set_location_assignment PIN_H16 -to {LEDR[11]}

foreach nodeforge_port {
    LEDR[0] LEDR[1] LEDR[2] LEDR[3] LEDR[4] LEDR[5]
    LEDR[6] LEDR[7] LEDR[8] LEDR[9] LEDR[10] LEDR[11]
} {
    set_instance_assignment -name IO_STANDARD {2.5 V} -to $nodeforge_port
}

# Complete DE2-115 VGA DAC and monitor connections: Table 4-16, 3.3 V.
set_location_assignment PIN_E12 -to {VGA_R[0]}
set_location_assignment PIN_E11 -to {VGA_R[1]}
set_location_assignment PIN_D10 -to {VGA_R[2]}
set_location_assignment PIN_F12 -to {VGA_R[3]}
set_location_assignment PIN_G10 -to {VGA_R[4]}
set_location_assignment PIN_J12 -to {VGA_R[5]}
set_location_assignment PIN_H8 -to {VGA_R[6]}
set_location_assignment PIN_H10 -to {VGA_R[7]}
set_location_assignment PIN_G8 -to {VGA_G[0]}
set_location_assignment PIN_G11 -to {VGA_G[1]}
set_location_assignment PIN_F8 -to {VGA_G[2]}
set_location_assignment PIN_H12 -to {VGA_G[3]}
set_location_assignment PIN_C8 -to {VGA_G[4]}
set_location_assignment PIN_B8 -to {VGA_G[5]}
set_location_assignment PIN_F10 -to {VGA_G[6]}
set_location_assignment PIN_C9 -to {VGA_G[7]}
set_location_assignment PIN_B10 -to {VGA_B[0]}
set_location_assignment PIN_A10 -to {VGA_B[1]}
set_location_assignment PIN_C11 -to {VGA_B[2]}
set_location_assignment PIN_B11 -to {VGA_B[3]}
set_location_assignment PIN_A11 -to {VGA_B[4]}
set_location_assignment PIN_C12 -to {VGA_B[5]}
set_location_assignment PIN_D11 -to {VGA_B[6]}
set_location_assignment PIN_D12 -to {VGA_B[7]}
set_location_assignment PIN_A12 -to {VGA_CLK}
set_location_assignment PIN_F11 -to {VGA_BLANK_N}
set_location_assignment PIN_G13 -to {VGA_HS}
set_location_assignment PIN_C13 -to {VGA_VS}
set_location_assignment PIN_C10 -to {VGA_SYNC_N}

foreach nodeforge_port {
    VGA_R[0] VGA_R[1] VGA_R[2] VGA_R[3] VGA_R[4] VGA_R[5] VGA_R[6] VGA_R[7]
    VGA_G[0] VGA_G[1] VGA_G[2] VGA_G[3] VGA_G[4] VGA_G[5] VGA_G[6] VGA_G[7]
    VGA_B[0] VGA_B[1] VGA_B[2] VGA_B[3] VGA_B[4] VGA_B[5] VGA_B[6] VGA_B[7]
    VGA_CLK VGA_BLANK_N VGA_HS VGA_VS VGA_SYNC_N
} {
    set_instance_assignment -name IO_STANDARD {3.3-V LVTTL} -to $nodeforge_port
}

export_assignments
puts {NodeForge: 60 DE2-115 clock/control/LED/VGA pins assigned and saved.}
puts {Reset KEY0; source SW6..SW0; target SW13..SW7; start KEY1; stop KEY2; results KEY3.}
