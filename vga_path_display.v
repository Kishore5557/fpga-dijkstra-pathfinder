module vga_path_display (clk50,rst,accepted_start,page_pulse,
    graph_ready,graph_error,error_code,active_nodes,slots_per_node,connection_base,
    source_node,target_node,busy,done,no_path,stopped,invalid_selection,
    total_distance,path_len,path_nodes,path_edge_slots,
    req_valid,req_ready,req_addr,rsp_valid,rsp_data,c_req_valid,c_req_id,c_rsp_valid,c_x,c_y,
    VGA_R,VGA_G,VGA_B,VGA_CLK,VGA_HS,VGA_VS,VGA_BLANK_N,VGA_SYNC_N);
parameter ANIMATION_CYCLES=25000000;
input clk50,rst,accepted_start,page_pulse,graph_ready,graph_error;
input [3:0] error_code;
input [6:0] active_nodes,slots_per_node,path_len;
input [13:0] connection_base;
input [7:0] source_node,target_node;
input busy,done,no_path,stopped,invalid_selection;
input [15:0] total_distance;
input [799:0] path_nodes,path_edge_slots;
output req_valid;
input req_ready,rsp_valid;
output [13:0] req_addr;
input [31:0] rsp_data;
output c_req_valid;
output [7:0] c_req_id;
input c_rsp_valid;
input [9:0] c_x;
input [8:0] c_y;
output reg [7:0] VGA_R,VGA_G,VGA_B;
output VGA_CLK,VGA_SYNC_N;
output reg VGA_HS,VGA_VS,VGA_BLANK_N;
wire pixel_ce,active,hs,vs,vblank,phase;
wire [9:0] x,y;
wire [18:0] rd_addr=active ? ({9'd0,y}*19'd640+{9'd0,x}) : 19'd0;
wire [3:0] pixel;
reg active_q,hs_q,vs_q,valid_q;
reg front_bank,front_valid,swap_pending,render_start,dirty,launch_pending;
wire render_busy,frame_complete,wr_en;
wire [18:0] wr_addr;
wire [3:0] wr_data;
reg [6:0] reveal_count;
reg [24:0] animation_count;
reg [3:0] page;
reg [3:0] previous_status;
reg previous_ready;
reg [6:0] previous_reveal;
reg [3:0] previous_page;
wire result_valid=done && !busy && !no_path && !stopped && !invalid_selection && path_len>0 && path_len<=100;
wire [3:0] status_code=graph_error ? 4'd6 : !graph_ready ? 4'd0 : invalid_selection ? 4'd7 :
    stopped ? 4'd5 : busy ? 4'd2 : no_path ? 4'd4 : done ? 4'd3 : 4'd1;
wire scene_changed=previous_status!=status_code || previous_ready!=graph_ready ||
    previous_reveal!=reveal_count || previous_page!=page || accepted_start;
reg [23:0] rgb;

vga_timing_640x480 timing(clk50,rst,pixel_ce,x,y,active,hs,vs,vblank,phase);
framebuffer pixels(clk50,wr_en,!front_bank,wr_addr,wr_data,pixel_ce,front_bank,rd_addr,pixel);
graph_renderer renderer(clk50,rst,render_start,graph_ready,active_nodes,slots_per_node,
    connection_base,source_node,target_node,path_len,reveal_count,path_nodes,path_edge_slots,
    result_valid,status_code,error_code,total_distance,page,
    req_valid,req_ready,req_addr,rsp_valid,rsp_data,c_req_valid,c_req_id,c_rsp_valid,c_x,c_y,
    render_busy,frame_complete,wr_en,wr_addr,wr_data);
assign VGA_CLK=phase;
assign VGA_SYNC_N=1'b0;
always @(*)
begin
    case(pixel)
    0:rgb=24'h161B22;
    1:rgb=24'h66717E;
    2:rgb=24'hF8FAFC;
    3:rgb=24'h20262E;
    4:rgb=24'hFFD400;
    5:rgb=24'h00C853;
    6:rgb=24'h168BFF;
    7:rgb=24'hFF6B6B;
    8:rgb=24'hE2E8F0;
    9:rgb=24'h101820;
    10:rgb=24'hFFD400;
    default:rgb=24'hFF6B6B;
    endcase
end
always @(posedge clk50)
begin
    if(rst)
    begin
        front_bank<=0;front_valid<=0;swap_pending<=0;render_start<=0;dirty<=1;launch_pending<=0;
        reveal_count<=0;animation_count<=0;page<=0;previous_status<=15;
        previous_ready<=0;previous_reveal<=0;previous_page<=0;
        active_q<=0;hs_q<=1;vs_q<=1;valid_q<=0;
        VGA_R<=0;VGA_G<=0;VGA_B<=0;VGA_HS<=1;VGA_VS<=1;VGA_BLANK_N<=0;
    end
    else
    begin
        render_start<=0;
        previous_status<=status_code;previous_ready<=graph_ready;
        previous_reveal<=reveal_count;previous_page<=page;
        if(accepted_start || !result_valid)
        begin reveal_count<=0;animation_count<=0;end
        else if(reveal_count==0) reveal_count<=1;
        else if(reveal_count<path_len)
        begin
            if(animation_count==ANIMATION_CYCLES-1)
            begin reveal_count<=reveal_count+7'd1;animation_count<=0;end
            else animation_count<=animation_count+25'd1;
        end
        if(previous_status!=status_code && (graph_error || invalid_selection || stopped || no_path)) page<=1;
        if(page_pulse)
        begin
            if(page>=5 || (page>0 && page*20>=path_len)) page<=0;
            else page<=page+4'd1;
        end
        if(accepted_start) page<=0;
        if(!render_busy && !launch_pending && !swap_pending && !frame_complete && dirty)
        begin render_start<=1;launch_pending<=1;dirty<=0;end
        if(render_busy) launch_pending<=0;
        if(scene_changed) dirty<=1;
        if(frame_complete) swap_pending<=1;
        if(vblank && swap_pending)
        begin front_bank<=!front_bank;front_valid<=1;swap_pending<=0;end
        if(pixel_ce)
        begin active_q<=active;hs_q<=hs;vs_q<=vs;valid_q<=front_valid;end
        else
        begin
            VGA_HS<=hs_q;VGA_VS<=vs_q;VGA_BLANK_N<=active_q;
            if(active_q && valid_q)
            begin VGA_R<=rgb[23:16];VGA_G<=rgb[15:8];VGA_B<=rgb[7:0];end
            else begin VGA_R<=0;VGA_G<=0;VGA_B<=0;end
        end
    end
end
endmodule
