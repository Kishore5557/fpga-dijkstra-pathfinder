module dijkstra_fpga_top (CLOCK_50,KEY,SW,LEDR,VGA_R,VGA_G,VGA_B,
    VGA_CLK,VGA_HS,VGA_VS,VGA_BLANK_N,VGA_SYNC_N);
parameter INIT_FILE="graph.mif";
parameter BUTTON_CYCLES=500000;
parameter SWITCH_CYCLES=500000;
input CLOCK_50;
input [3:0] KEY;
input [13:0] SW;
output [11:0] LEDR;
output [7:0] VGA_R,VGA_G,VGA_B;
output VGA_CLK,VGA_HS,VGA_VS,VGA_BLANK_N,VGA_SYNC_N;
reg [1:0] reset_sync;
wire reset=reset_sync[1];
always @(posedge CLOCK_50 or negedge KEY[0])
    if(!KEY[0]) reset_sync<=2'b11;
    else reset_sync<={reset_sync[0],1'b0};
wire start_pulse,stop_pulse,page_pulse;
button_onepulse #(.COUNT_MAX(BUTTON_CYCLES)) start_button(CLOCK_50,reset,KEY[1],start_pulse);
button_onepulse #(.COUNT_MAX(BUTTON_CYCLES)) stop_button(CLOCK_50,reset,KEY[2],stop_pulse);
button_onepulse #(.COUNT_MAX(BUTTON_CYCLES)) page_button(CLOCK_50,reset,KEY[3],page_pulse);
reg [13:0] sw0,sw1,sw_prev;
reg [19:0] stable_count;
wire switches_stable=stable_count>=SWITCH_CYCLES;
wire [7:0] source_selection={1'b0,sw1[6:0]};
wire [7:0] target_selection={1'b0,sw1[13:7]};
reg [7:0] latched_source,latched_target;
wire graph_ready,graph_error;
wire [3:0] error_code;
wire [6:0] active_nodes,slots_per_node;
wire [13:0] connection_base,unused_coordinate_base,unused_image_words,unused_valid_edge_count,rom_addr;
wire [31:0] rom_q;
wire d_req_valid,d_req_ready,d_rsp_valid,r_req_valid,r_req_ready,r_rsp_valid;
wire [13:0] d_req_addr,r_req_addr;
wire [31:0] d_rsp_data,r_rsp_data;
wire c_req_valid,c_rsp_valid;
wire [7:0] c_req_id;
wire [9:0] c_x;
wire [8:0] c_y;
wire busy,done,no_path,stopped,core_invalid;
reg selection_error;
wire [15:0] total_distance;
wire [6:0] path_len;
wire [799:0] path_nodes,path_edge_slots;
wire accepted_start=start_pulse && !stop_pulse && !busy && graph_ready && !graph_error &&
    switches_stable && source_selection<{1'b0,active_nodes} && target_selection<{1'b0,active_nodes};
always @(posedge CLOCK_50)
begin
    if(reset)
    begin
        sw0<=0;sw1<=0;sw_prev<=0;stable_count<=0;
        latched_source<=0;latched_target<=0;selection_error<=0;
    end
    else
    begin
        sw0<=SW;sw1<=sw0;sw_prev<=sw1;
        if(sw_prev!=sw1) stable_count<=0;
        else if(!switches_stable) stable_count<=stable_count+20'd1;
        if(accepted_start)
        begin latched_source<=source_selection;latched_target<=target_selection;selection_error<=0;end
        else if(start_pulse && !busy) selection_error<=1;
    end
end
graph_rom #(.INIT_FILE(INIT_FILE)) image_rom(CLOCK_50,rom_addr,rom_q);
graph_image_controller controller(CLOCK_50,reset,rom_addr,rom_q,
    graph_ready,graph_error,error_code,active_nodes,slots_per_node,
    connection_base,unused_coordinate_base,unused_image_words,unused_valid_edge_count,
    d_req_valid,d_req_ready,d_req_addr,d_rsp_valid,d_rsp_data,
    r_req_valid,r_req_ready,r_req_addr,r_rsp_valid,r_rsp_data,
    c_req_valid,c_req_id,c_rsp_valid,c_x,c_y);
dijkstra_core core(CLOCK_50,reset,accepted_start,stop_pulse,source_selection,target_selection,
    graph_ready,graph_error,active_nodes,slots_per_node,connection_base,
    d_req_valid,d_req_ready,d_req_addr,d_rsp_valid,d_rsp_data,
    busy,done,no_path,stopped,core_invalid,total_distance,path_len,path_nodes,path_edge_slots);
vga_path_display display(CLOCK_50,reset,accepted_start,page_pulse,
    graph_ready,graph_error,error_code,active_nodes,slots_per_node,connection_base,
    latched_source,latched_target,busy,done,no_path,stopped,selection_error|core_invalid,
    total_distance,path_len,path_nodes,path_edge_slots,
    r_req_valid,r_req_ready,r_req_addr,r_rsp_valid,r_rsp_data,c_req_valid,c_req_id,c_rsp_valid,c_x,c_y,
    VGA_R,VGA_G,VGA_B,VGA_CLK,VGA_HS,VGA_VS,VGA_BLANK_N,VGA_SYNC_N);
assign LEDR[6:0]=latched_source[6:0];
assign LEDR[7]=graph_ready;
assign LEDR[8]=busy;
assign LEDR[9]=done;
assign LEDR[10]=no_path;
assign LEDR[11]=graph_error|selection_error|core_invalid|stopped;
endmodule
