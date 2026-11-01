# FPGA Dijkstra Pathfinder

**Dijkstra’s shortest-path algorithm implemented in Verilog on the DE2-115 FPGA, with configurable graph memory and VGA visualization.**

The user selects source and target nodes using the board switches. The FPGA computes the shortest path, reconstructs the node sequence, and displays the graph and highlighted route on a VGA monitor. Graph connections, weights, and node coordinates are stored in `graph.mif`.

**Graph editor:** [Open NodeForge — Graph to ROM](https://graphnode-beta.vercel.app/)

## Project team

- **Kishore B** — [Kishore5557](https://github.com/Kishore5557)
- **Sanjay** — [sanjaysmiles-gis](https://github.com/sanjaysmiles-gis)
- **Pavithran** — [Pavithrand22](https://github.com/Pavithrand22)

## Features

- Sequential, FSM-based Dijkstra implementation in Verilog.
- Support for 1–100 nodes and 1–100 connection slots per node.
- Graph size, connections, weights, and coordinates supplied through an NFG1 memory image.
- 8-bit unsigned edge weights and 16-bit total distances.
- Source and target selection using board switches.
- Start, stop, reset, and display-page buttons.
- Graph validation before accepting a search.
- 640 × 480 VGA output with directed edges, weight labels, and animated route highlighting.
- Double-buffered, 4-bit palette framebuffer with frame changes during vertical blanking.
- LED indicators for readiness, execution, completion, and errors.

Changing the graph within the supported limits does not require editing the routing algorithm or drawing coordinates in Verilog. The memory initialization and FPGA programming file must still be updated.

## Graph editor: NodeForge

[**Launch NodeForge — Graph to ROM**](https://graphnode-beta.vercel.app/)

NodeForge is the companion web tool for preparing graph memory images. Enter weighted, directed connections in a neighbour table, arrange the nodes in the live preview, and export a Quartus-compatible `graph.mif`. The exported node positions are used by the FPGA’s VGA renderer.

### Create a graph for the FPGA

1. Open NodeForge, set **Nodes** and **Neighbours / node** within the supported range of 1–100, and click **Apply**. Use **Load sample** to start with an example.
2. Enter each connection as `destination (weight)`, for example `4 (12)`. Node IDs and weights are decimal. IDs start at zero, weights range from 0 to 255, and blank cells represent unused slots.
3. Enter reverse connections separately when travel in both directions is needed. You can also paste a table range from Excel.
4. Drag nodes in the graph preview or enter their X/Y coordinates. These positions are saved for the 640 × 480 VGA display.
5. Optionally use **Run Dijkstra** to check a source-to-target route in the browser before trying it on the FPGA.
6. Click **Generate MIF** and place the downloaded `graph.mif` in the Quartus project folder, replacing the previous graph file.
7. Follow [Updating only the graph](#updating-only-the-graph) to update the programming file, program the board, and reset the design. For the first build, follow [Build and run](#build-and-run).

For an editable backup, export regular HEX before closing the editor; importing it restores the table and node layout. Use **MIF** for this project’s Quartus ROM. The padded HEX export is intended for `$readmemh` simulation.

The website prepares the memory image and can check routes in the browser. The FPGA computes its own route after programming; the website does not directly transfer a live graph to the board.

## Hardware and tools

| Item | Configuration |
|---|---|
| FPGA board | Terasic DE2-115 |
| FPGA device | Cyclone IV E, EP4CE115F29C7 |
| Input clock | 50 MHz |
| HDL | Verilog |
| Project tool version recorded in the QSF | Quartus Prime Lite 25.1std.0 |
| Display | VGA monitor and cable, 640 × 480 |
| Programming connection | USB-Blaster / board USB programming interface |

The ROM uses Altera’s `altsyncram` primitive. Simulation requires the corresponding Altera simulation library. The pin assignments and memory primitive target the DE2-115; another board requires adaptation.

## Project files

| File | Purpose |
|---|---|
| `dijkstra_fpga_top.v` | Connects the controls, graph memory controller, algorithm, display, and LEDs |
| `button_onepulse.v` | Synchronizes and debounces a button and generates one pulse per press |
| `graph_rom_mif.v` | Implements the graph ROM initialized from `graph.mif`; its module name is `graph_rom` |
| `graph_image_controller.v` | Validates the NFG1 image, caches node coordinates, and arbitrates ROM access |
| `dijkstra_core.v` | Selects the nearest unvisited node, relaxes outgoing edges, and reconstructs the route |
| `graph_renderer.v` | Converts graph and result data into drawing commands |
| `raster_engine.v` | Draws lines, rectangles, numbers, and text into the framebuffer |
| `framebuffer.v` | Stores two 640 × 480 frames using 4 bits per pixel |
| `vga_path_display.v` | Controls rendering, route animation, display pages, frame swaps, and RGB output |
| `vga_timing_640x480.v` | Generates pixel timing and VGA synchronization signals |
| `graph.mif` | Stores the graph header, connections, and node coordinates |
| `dijkstra_fpga_top.qpf` | Quartus project file |
| `dijkstra_fpga_top.qsf` | Device, source-file, and pin assignments |
| `NodeForge_DE2_115_All_Pins.tcl` | Pin-assignment script for the board |

Keep the project files together in the repository root because the supplied QSF uses relative filenames without subdirectories. Do not add another module named `graph_rom` alongside `graph_rom_mif.v`.

## Board controls

Node IDs are **zero-based**, from `0` to `N − 1`, where `N` is the node count in the memory image.

| Control | Function |
|---|---|
| `SW[6:0]` | Source node in binary; `SW[0]` is the least significant bit |
| `SW[13:7]` | Target node in binary; `SW[7]` is the least significant bit |
| `KEY[0]` | Reset the design and reload/validate graph data |
| `KEY[1]` | Start a shortest-path search |
| `KEY[2]` | Stop the current search |
| `KEY[3]` | Cycle between the graph view and result pages |

A start is accepted only when the graph is ready, the core is idle, and both selected IDs are valid. Allow the switches to settle before pressing Start. The design latches both node selections when it accepts a search.

### LED indicators

| LED | Meaning when high |
|---|---|
| `LEDR[6:0]` | Binary value of the source node latched at the last accepted start |
| `LEDR[7]` | Graph validation completed successfully |
| `LEDR[8]` | Search is running |
| `LEDR[9]` | Search completed; check the no-path indicator and display for the outcome |
| `LEDR[10]` | No route exists for the selected source and target |
| `LEDR[11]` | Graph error, rejected/invalid selection, or stopped search |

## Build and run

1. Download or clone this repository and keep the project files together.
2. Open `dijkstra_fpga_top.qpf` in Quartus Prime with Cyclone IV device support installed.
3. Confirm that the top-level entity is `dijkstra_fpga_top` and the device is `EP4CE115F29C7`.
4. Confirm that `graph.mif` is present. The top module defaults to `INIT_FILE="graph.mif"`.
5. Run a full compilation. The supplied QSF already includes the board pin assignments; the TCL script is available when reapplying them to a recreated project.
6. Connect the DE2-115 and VGA monitor. Open Quartus Programmer, select the USB-Blaster, and load the generated `.sof` from `output_files`.
7. Enable **Program/Configure** and program the FPGA.
8. Press and release `KEY[0]`. Wait until `LEDR[7]` turns on.
9. Set the source and target switches, then press `KEY[1]`.
10. View the highlighted path and total distance. Press `KEY[3]` for result pages.

### Example using the supplied graph

The attached graph image contains **30 nodes**, **3 slots per node**, and **90 valid directed connection entries**.

For a search from node **0** to node **29**:

- Set `SW[6:0] = 0000000`.
- Set `SW[13:7] = 0011101` — turn on `SW[11]`, `SW[10]`, `SW[9]`, and `SW[7]`; leave the other source/target switches off.
- Press `KEY[1]` after the graph is ready.

A software reference calculation using the supplied MIF gives:

```text
Source:    0
Target:    29
Path:      0 → 7 → 13 → 14 → 15 → 21 → 27 → 28 → 29
Distance:  41
```

This is an expected result calculated from the graph data, not a measured FPGA timing result. It applies to the supplied MIF; replacing the graph can change the route and distance.

## Graph memory format

`graph.mif` uses **32-bit words** and a ROM depth of **10,124 words**. The active image follows the **NodeForge NFG1, version 1** format.

| Region | Contents |
|---|---|
| Header | 24 words describing the format, node count, slot count, entry count, and region offsets |
| Connections | `N × K` words, where `K` is the number of slots reserved per node |
| Coordinates | One word per node |

The header starts with magic word `4E464731` (`NFG1`). The controller checks the header and image contents before asserting `graph_ready`.

Each connection word is:

```text
0000DDWW
```

- `DD`: destination node ID, in hexadecimal.
- `WW`: unsigned edge weight, in hexadecimal.
- `FFFFFFFF`: unused connection slot.

Connection slot `j` for node `i` is at word address `24 + i × K + j`. Connections are directed: add a reverse entry when travel in both directions is required. Reverse weights can differ.

Each coordinate word is `XXXXYYYY`, containing 16-bit unsigned X and Y coordinates. The accepted bounds are `0 ≤ X < 640` and `0 ≤ Y < 480`.

All header counts and offsets must match the stored data. Unused slots still occupy words and must use the sentinel value. Preserve the full MIF structure when exporting a new graph.

### Updating only the graph

When the HDL, device, ROM dimensions, and project configuration are unchanged:

1. Replace `graph.mif` with a valid NFG1 MIF using the same filename.
2. In the previously compiled Quartus project, run **Processing → Update Memory Initialization File**.
3. Run **Processing → Start → Start Assembler** to regenerate the programming file.
4. Program the FPGA with the updated `.sof`, then reset the design.

Editing the MIF on the computer does not change the graph already programmed into the FPGA. Run a full compilation when the HDL or hardware configuration changes.

## How the search works

1. Validate the graph image and cache coordinates.
2. Set the source distance to zero and all other distances to infinity.
3. Scan the unvisited nodes and choose the one with the smallest known distance.
4. Read its connection slots and update a neighbor’s distance and predecessor when a shorter route is found.
5. Repeat until the target is selected or no reachable unvisited node remains.
6. Follow predecessor links from target to source, reverse the sequence, and send the route to the display.

The core reuses its sequential datapath across nodes and edges. The animation reveals the reconstructed route after computation; it does not show every intermediate Dijkstra relaxation.

## Display diagnostics

Result pages show `STATUS`, `ERROR`, `SOURCE`, `TARGET`, `DIST`, `LENGTH`, and `PAGE`, followed by indexed path nodes when a valid route is available. `LENGTH` counts nodes in the route, including source and target. Each path page lists up to 20 nodes.

| Status code | Meaning |
|---|---|
| 0 | Graph loading/validation |
| 1 | Ready |
| 2 | Search running |
| 3 | Search completed |
| 4 | No path |
| 5 | Stopped |
| 6 | Graph error |
| 7 | Invalid/rejected selection |

| Graph error code | Meaning |
|---|---|
| 1 | Header format or fixed-field mismatch |
| 2 | Invalid node, slot, or connection count |
| 3 | Invalid region offsets or image size |
| 4 | Invalid connection word or destination ID |
| 5 | Valid connection count does not match the header |
| 6 | Coordinate outside the supported screen bounds |
| 7 | Unknown ROM data detected during simulation |
| 8 | Invalid runtime ROM request or controller state |

## Scope and limits

- Weights are unsigned; negative edge weights are unsupported.
- `16'hFFFF` represents infinity; finite distances must be below 65,535.
- This implementation selects the next node by scanning the distance array rather than using a priority queue.
- Graph changes use memory initialization and FPGA reprogramming; there is no live UART or USB graph-upload interface in these sources.
- Performance, resource utilization, and timing closure should be reported from the actual Quartus compilation. No measured speedup or maximum operating frequency is claimed here.
- NodeForge is available through the companion website linked above; its web application source is separate from these FPGA sources.

