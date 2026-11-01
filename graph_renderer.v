module graph_renderer (clk, rst, start, graph_ready, active_nodes, slots_per_node,
    connection_base, source_node, target_node, path_len, reveal_count, path_nodes,
    path_edge_slots, result_valid, status_code, error_code, total_distance, page,
    req_valid, req_ready, req_addr, rsp_valid, rsp_data,
    c_req_valid, c_req_id, c_rsp_valid, c_x, c_y,
    busy, frame_complete, wr_en, wr_addr, wr_data);
input clk,rst,start,graph_ready,result_valid;
input [6:0] active_nodes,slots_per_node,path_len,reveal_count;
input [13:0] connection_base;
input [7:0] source_node,target_node;
input [799:0] path_nodes,path_edge_slots;
input [3:0] status_code,error_code,page;
input [15:0] total_distance;
output req_valid;
input req_ready,rsp_valid;
output [13:0] req_addr;
input [31:0] rsp_data;
output c_req_valid;
output [7:0] c_req_id;
input c_rsp_valid;
input [9:0] c_x;
input [8:0] c_y;
output reg busy,frame_complete;
output wr_en;
output [18:0] wr_addr;
output [3:0] wr_data;

localparam IDLE=0,CLEAR=1,MASK=2,EDGE_BEGIN=3,EDGE_REQ=4,EDGE_WAIT=5,
    SRC_REQ=6,SRC_WAIT=7,DST_REQ=8,DST_WAIT=9,GEOM=10,SEGMENT=11,
    ARROW1=12,ARROW2=13,WEIGHT=14,NEXT_EDGE=15,NODE_REQ=16,NODE_WAIT=17,
    NODE_BOX=18,NODE_LABEL=19,NEXT_NODE=20,PANEL=21,PANEL_TEXT=22,
    FINISH=23,CMD_WAIT=24,CMD_SEND=25,PANEL_VALUE=26,NODE_FILL=27,PANEL_TITLE=28,WEIGHT_BG=29,RANK_REQ=30,RANK_WAIT=31,
    TOP_BAR=32,STRIP_BG=33,STRIP_TITLE=34,STRIP_DIST_LABEL=35,STRIP_DIST=36,
    STRIP_BOX=37,STRIP_FILL=38,STRIP_NUMBER=39,STRIP_LINE=40,STRIP_WEIGHT=41,
    STRIP_NEXT=42,STRIP_EMPTY=43;
reg [5:0] state,return_state;
reg clip_graph;
wire raster_wr_en;
wire [18:0] raster_wr_addr;
assign wr_en=raster_wr_en && (!clip_graph || (raster_wr_addr>=19'd6400 && raster_wr_addr<19'd259840));
assign wr_addr=raster_wr_addr;
reg [7:0] path_weights[0:99];
reg [6:0] strip_i;
reg [3:0] strip_pos;
wire [7:0] strip_node=nodes_s[strip_i*8 +: 8];
wire [6:0] shown_count=reveal_s<len_s ? reveal_s : len_s;
wire [31:0] strip_x=32'd32+{28'd0,strip_pos}*32'd62;
wire [7:0] strip_weight=path_weights[strip_i];
reg ready_s,valid_s;
reg [6:0] n_s,k_s,len_s,reveal_s,mask_i,edge_slot,path_i,node_i;
reg [7:0] src_s,tgt_s,edge_src,edge_dst;
reg [13:0] base_s;
reg [799:0] nodes_s,slots_s;
reg [3:0] status_s,error_s,page_s;
reg [15:0] distance_s;
reg [99:0] node_mask;
reg highlight_pass,label_pass;
reg [6:0] pair_count[0:99];
reg [6:0] edge_rank,rank_slot;
integer j;
integer magnitude,nx,ny,offx,offy,label_x,label_y,label_w,node_cx,node_cy;
function integer norm8;
input integer a,d;
integer q;
begin
    norm8=0;
    for(q=1;q<=8;q=q+1)
        if(d>0 && absval(a)*8>=d*q) norm8=sign(a)*q;
end
endfunction
function integer clamp;
input integer a,lo,hi;
begin clamp=a<lo ? lo : a>hi ? hi : a;end
endfunction
reg [7:0] weight_s;
integer ax,ay,bx,by,mx,my,lane,vx,vy,tipx,tipy,ux,uy;
integer points_x[0:4],points_y[0:4];
reg [2:0] segment_i,segment_count;
reg [5:0] text_i;
reg cmd_valid;
wire cmd_ready,cmd_done;
reg [1:0] cmd_kind;
reg signed [31:0] x0,y0,x1,y1;
reg [3:0] ink;
reg [15:0] number;
reg [2:0] digits;
reg [47:0] label;
reg [1:0] text_scale;
wire [31:0] wide_addr={18'd0,base_s}+{24'd0,edge_src}*{25'd0,k_s}+{25'd0,(state==RANK_REQ || state==RANK_WAIT ? rank_slot : edge_slot)};
assign req_addr=wide_addr[13:0];
assign req_valid=(state==EDGE_REQ || state==RANK_REQ) && wide_addr<10124;
assign c_req_valid=state==SRC_REQ || state==DST_REQ || state==NODE_REQ;
assign c_req_id=state==SRC_REQ ? edge_src : state==DST_REQ ? edge_dst : {1'b0,node_i};
raster_engine raster (clk,rst,cmd_valid,cmd_ready,cmd_kind,x0,y0,x1,y1,
    ink,number,digits,label,text_scale,cmd_done,raster_wr_en,raster_wr_addr,wr_data);
function integer sign;
input integer a;
begin sign=a>0 ? 1 : a<0 ? -1 : 0; end
endfunction
function integer absval;
input integer a;
begin absval=a<0 ? -a : a; end
endfunction

// All lanes use the actual vector; reverse edges occupy opposite sides.
// Only earlier entries to the SAME destination increase the lane offset.
always @(*)
begin
    vx=bx-ax;vy=by-ay;
    magnitude=absval(vx)>absval(vy) ? absval(vx) : absval(vy);
    nx=norm8(vx,magnitude);ny=norm8(vy,magnitude);
    lane=5+{25'd0,edge_rank}*16;
    offx=-ny*lane/8;offy=nx*lane/8;
    points_x[0]=ax+offx+nx*25/8;points_y[0]=ay+offy+ny*25/8;
    points_x[1]=bx+offx-nx*28/8;points_y[1]=by+offy-ny*28/8;
    points_x[2]=0;points_y[2]=0;points_x[3]=0;points_y[3]=0;
    points_x[4]=0;points_y[4]=0;
    mx=ax+vx*3/8+offx;my=ay+vy*3/8+offy;
    ux=nx;uy=ny;segment_count=1;
    if(edge_rank!=0)
    begin
        // Fan out only true parallel entries. All arrow tips still meet the node.
        points_x[0]=ax-ny*5/8+nx*25/8;points_y[0]=ay+nx*5/8+ny*25/8;
        points_x[1]=ax+(bx-ax)/4+offx;points_y[1]=ay+(by-ay)/4+offy;
        points_x[2]=bx-(bx-ax)/4+offx;points_y[2]=by-(by-ay)/4+offy;
        points_x[3]=bx-ny*5/8-nx*28/8;points_y[3]=by+nx*5/8-ny*28/8;
        vx=points_x[3]-points_x[2];vy=points_y[3]-points_y[2];
        ux=norm8(vx,absval(vx)>absval(vy) ? absval(vx) : absval(vy));
        uy=norm8(vy,absval(vx)>absval(vy) ? absval(vx) : absval(vy));
        segment_count=3;
    end
    if(magnitude<48)
    begin
        // Visible loop for self edges, coincident nodes and very short edges.
        lane=34+{25'd0,edge_rank}*8;
        vx=ax<320 ? 1 : -1;vy=ay<240 ? 1 : -1;
        points_x[0]=ax+vx*23;points_y[0]=ay;
        points_x[1]=ax+vx*lane;points_y[1]=ay;
        points_x[2]=ax+vx*lane;points_y[2]=ay+vy*lane;
        points_x[3]=bx;points_y[3]=ay+vy*lane;
        points_x[4]=bx;points_y[4]=by+vy*21;
        mx=ax+vx*lane;my=ay+vy*lane;
        ux=0;uy=points_y[4]>=points_y[3] ? 8 : -8;segment_count=4;
    end
    tipx=points_x[segment_count];tipy=points_y[segment_count];
    label_w=weight_s>=100 ? 22 : weight_s>=10 ? 14 : 6;
    label_x=clamp(mx-label_w/2,3,636-label_w);
    label_y=clamp(my-5,14,390);
    // Inset badges only at the graph viewport boundary; keep IDs fully visible.
    node_cx=clamp(ax,24,615);node_cy=clamp(ay,28,387);
end

always @(posedge clk)
begin
    if(rst)
    begin
        state<=IDLE; return_state<=IDLE;clip_graph<=0;strip_i<=0;strip_pos<=0; busy<=0; frame_complete<=0; cmd_valid<=0;
        ready_s<=0; valid_s<=0; n_s<=0; k_s<=0; len_s<=0; reveal_s<=0;
        src_s<=0; tgt_s<=0; base_s<=0; nodes_s<=0; slots_s<=0; status_s<=0;
        error_s<=0; page_s<=0; distance_s<=0; node_mask<=0; mask_i<=0;
        edge_src<=0; edge_dst<=0; edge_slot<=0; path_i<=0; node_i<=0;
        highlight_pass<=0; label_pass<=0;edge_rank<=0;rank_slot<=0;
        for(j=0;j<100;j=j+1) pair_count[j]<=0;
        weight_s<=0; ax<=0;ay<=0;bx<=0;by<=0;
        segment_i<=0; text_i<=0; text_scale<=2;
        cmd_kind<=0; x0<=0;y0<=0;x1<=0;y1<=0;ink<=0;number<=0;digits<=1;label<=0;
    end
    else
    begin
        frame_complete<=0;
        case(state)
        IDLE: if(start)
        begin
            ready_s<=graph_ready; valid_s<=result_valid;
            n_s<=active_nodes; k_s<=slots_per_node; base_s<=connection_base;
            src_s<=source_node; tgt_s<=target_node;
            len_s<=path_len; reveal_s<=reveal_count; nodes_s<=path_nodes; slots_s<=path_edge_slots;
            status_s<=status_code; error_s<=error_code; distance_s<=total_distance; page_s<=page;
            node_mask<=0; mask_i<=0; highlight_pass<=0;label_pass<=0;
            for(j=0;j<100;j=j+1) pair_count[j]<=0;
            edge_src<=0; edge_slot<=0;
            path_i<=0; node_i<=0;clip_graph<=0;busy<=1;state<=CLEAR;
        end
        CLEAR:
        begin
            cmd_kind<=1; x0<=0;y0<=0;x1<=639;y1<=479;ink<=0;
            return_state<=TOP_BAR;state<=CMD_SEND;
        end
        TOP_BAR:
        begin
            if(ready_s && page_s==0)
            begin
                cmd_kind<=1;x0<=0;y0<=0;x1<=639;y1<=5;
                ink<=status_s==2 ? 4'd4 : status_s>=4 ? 4'd7 : 4'd5;
                return_state<=MASK;state<=CMD_SEND;
            end
            else state<=MASK;
        end
        MASK:
        begin
            if(valid_s && mask_i<len_s && mask_i<reveal_s)
            begin
                if(nodes_s[mask_i*8 +: 8]<{1'b0,n_s}) node_mask[nodes_s[mask_i*8 +: 7]]<=1;
                mask_i<=mask_i+7'd1;
            end
            else if(!ready_s || page_s!=0) state<=PANEL;
            else begin clip_graph<=1;state<=EDGE_BEGIN;end
        end
        EDGE_BEGIN:
        begin
            if(highlight_pass)
            begin
                if(valid_s && path_i+7'd1<len_s && path_i+7'd1<reveal_s)
                begin
                    edge_src<=nodes_s[path_i*8 +: 8];
                    edge_slot<=slots_s[path_i*8 +: 7]; state<=EDGE_REQ;
                end
                else if(!label_pass)
                begin
                    label_pass<=1;highlight_pass<=0;edge_src<=0;edge_slot<=0;
                    for(j=0;j<100;j=j+1) pair_count[j]<=0;
                    state<=EDGE_REQ;
                end
                else begin node_i<=0;state<=NODE_REQ;end
            end
            else state<=EDGE_REQ;
        end
        EDGE_REQ: if(req_ready) state<=EDGE_WAIT;
        EDGE_WAIT: if(rsp_valid)
        begin
            if(rsp_data==32'hFFFFFFFF || rsp_data[31:16]!=0 || rsp_data[15:8]>={1'b0,n_s}) state<=NEXT_EDGE;
            else
            begin
                edge_dst<=rsp_data[15:8];weight_s<=rsp_data[7:0];
                if(highlight_pass && !label_pass) path_weights[path_i]<=rsp_data[7:0];
                if(highlight_pass)
                begin
                    edge_rank<=0;rank_slot<=0;
                    state<=edge_slot==0 ? SRC_REQ : RANK_REQ;
                end
                else
                begin
                    edge_rank<=pair_count[rsp_data[14:8]];
                    pair_count[rsp_data[14:8]]<=pair_count[rsp_data[14:8]]+7'd1;
                    state<=SRC_REQ;
                end
            end
        end
        RANK_REQ: if(req_ready) state<=RANK_WAIT;
        RANK_WAIT: if(rsp_valid)
        begin
            if(rsp_data!=32'hFFFFFFFF && rsp_data[15:8]==edge_dst) edge_rank<=edge_rank+7'd1;
            rank_slot<=rank_slot+7'd1;
            state<=rank_slot+7'd1==edge_slot ? SRC_REQ : RANK_REQ;
        end
        SRC_REQ: state<=SRC_WAIT;
        SRC_WAIT: if(c_rsp_valid) begin ax<={22'd0,c_x};ay<=32'd28+({23'd0,c_y}*32'd3)/32'd4;state<=DST_REQ;end
        DST_REQ: state<=DST_WAIT;
        DST_WAIT: if(c_rsp_valid) begin bx<={22'd0,c_x};by<=32'd28+({23'd0,c_y}*32'd3)/32'd4;state<=GEOM;end
        GEOM: begin segment_i<=0;state<=label_pass ? WEIGHT_BG : SEGMENT;end
        SEGMENT:
        begin
            cmd_kind<=0;
            x0<=points_x[segment_i];y0<=points_y[segment_i];
            x1<=points_x[segment_i+1];y1<=points_y[segment_i+1];
            ink<=highlight_pass ? 4'd4 : 4'd1;
            segment_i<=segment_i+3'd1;
            return_state<=segment_i+1==segment_count ? ARROW1 : SEGMENT;
            state<=CMD_SEND;
        end
        ARROW1:
        begin
            cmd_kind<=0;ink<=highlight_pass ? 4'd10 : 4'd1;x0<=tipx;y0<=tipy;
            x1<=tipx-ux+uy*3/8;y1<=tipy-uy-ux*3/8;
            return_state<=ARROW2;state<=CMD_SEND;
        end
        ARROW2:
        begin
            cmd_kind<=0;ink<=highlight_pass ? 4'd10 : 4'd1;x0<=tipx;y0<=tipy;
            x1<=tipx-ux-uy*3/8;y1<=tipy-uy+ux*3/8;
            return_state<=NEXT_EDGE;state<=CMD_SEND;
        end
        WEIGHT_BG:
        begin
            cmd_kind<=1;x0<=label_x-2;y0<=label_y-2;
            x1<=label_x+label_w+1;y1<=label_y+11;ink<=0;
            return_state<=WEIGHT;state<=CMD_SEND;
        end
        WEIGHT:
        begin
            cmd_kind<=2;text_scale<=2;
            x0<=label_x;y0<=label_y;number<={8'd0,weight_s};
            digits<=weight_s>=100 ? 3'd3 : weight_s>=10 ? 3'd2 : 3'd1;
            ink<=highlight_pass ? 4'd4 : 4'd2;return_state<=NEXT_EDGE;state<=CMD_SEND;
        end
        NEXT_EDGE:
        begin
            if(highlight_pass) begin path_i<=path_i+7'd1;state<=EDGE_BEGIN;end
            else if(edge_slot+7'd1==k_s)
            begin
                edge_slot<=0;
                for(j=0;j<100;j=j+1) pair_count[j]<=0;
                if(edge_src+8'd1=={1'b0,n_s}) begin highlight_pass<=1;path_i<=0;state<=EDGE_BEGIN;end
                else begin edge_src<=edge_src+8'd1;state<=EDGE_REQ;end
            end
            else begin edge_slot<=edge_slot+7'd1;state<=EDGE_REQ;end
        end
        NODE_REQ: state<=NODE_WAIT;
        NODE_WAIT: if(c_rsp_valid) begin ax<={22'd0,c_x};ay<=32'd28+({23'd0,c_y}*32'd3)/32'd4;state<=NODE_BOX;end
        NODE_BOX:
        begin
            cmd_kind<=1;x0<=node_cx-22;y0<=node_cy-16;x1<=node_cx+22;y1<=node_cy+16;ink<=4'd8;
            return_state<=NODE_FILL;state<=CMD_SEND;
        end
        NODE_FILL:
        begin
            cmd_kind<=1;x0<=node_cx-20;y0<=node_cy-14;x1<=node_cx+20;y1<=node_cy+14;
            ink<={1'b0,node_i}==src_s ? 4'd5 : {1'b0,node_i}==tgt_s ? 4'd6 : node_mask[node_i] ? 4'd4 : 4'd3;
            return_state<=NODE_LABEL;state<=CMD_SEND;
        end
        NODE_LABEL:
        begin
            cmd_kind<=2;text_scale<=3;x0<=node_i>=10 ? node_cx-16 : node_cx-7;y0<=node_cy-10;
            number<={9'd0,node_i};digits<=node_i>=10 ? 3'd2 : 3'd1;
            ink<=node_mask[node_i] && {1'b0,node_i}!=src_s && {1'b0,node_i}!=tgt_s ? 4'd9 : 4'd2;
            return_state<=NEXT_NODE;state<=CMD_SEND;
        end
        NEXT_NODE:
            if(node_i+7'd1==n_s) begin clip_graph<=0;state<=STRIP_BG;end
            else begin node_i<=node_i+7'd1;state<=NODE_REQ;end
        STRIP_BG:
        begin
            cmd_kind<=1;x0<=0;y0<=410;x1<=639;y1<=411;ink<=4'd1;
            strip_i<=shown_count>10 ? shown_count-7'd10 : 7'd0;strip_pos<=0;
            return_state<=STRIP_TITLE;state<=CMD_SEND;
        end
        STRIP_TITLE:
        begin
            cmd_kind<=3;text_scale<=2;x0<=12;y0<=416;digits<=6;
            label<="PATH  ";ink<=4'd2;
            return_state<=valid_s ? STRIP_DIST_LABEL : STRIP_EMPTY;state<=CMD_SEND;
        end
        STRIP_DIST_LABEL:
        begin
            cmd_kind<=3;text_scale<=2;x0<=470;y0<=416;digits<=4;
            label<="DIST  ";ink<=4'd2;
            return_state<=STRIP_DIST;state<=CMD_SEND;
        end
        STRIP_DIST:
        begin
            cmd_kind<=2;text_scale<=2;x0<=514;y0<=416;digits<=5;
            number<=distance_s;ink<=4'd4;
            return_state<=shown_count==0 ? FINISH : STRIP_BOX;state<=CMD_SEND;
        end
        STRIP_EMPTY:
        begin
            cmd_kind<=3;text_scale<=2;x0<=76;y0<=416;digits<=6;ink<=4'd2;
            label<=status_s==1 ? "READY " : status_s==2 ? "WAIT  " : "NONE  ";
            return_state<=FINISH;state<=CMD_SEND;
        end
        STRIP_BOX:
        begin
            cmd_kind<=1;x0<=strip_x-20;y0<=439;x1<=strip_x+20;y1<=471;ink<=4'd8;
            return_state<=STRIP_FILL;state<=CMD_SEND;
        end
        STRIP_FILL:
        begin
            cmd_kind<=1;x0<=strip_x-18;y0<=441;x1<=strip_x+18;y1<=469;
            ink<=strip_node==src_s ? 4'd5 : strip_node==tgt_s ? 4'd6 : 4'd4;
            return_state<=STRIP_NUMBER;state<=CMD_SEND;
        end
        STRIP_NUMBER:
        begin
            cmd_kind<=2;text_scale<=3;x0<=strip_node>=10 ? strip_x-16 : strip_x-7;y0<=445;
            number<={8'd0,strip_node};digits<=strip_node>=10 ? 3'd2 : 3'd1;
            ink<=strip_node==src_s || strip_node==tgt_s ? 4'd2 : 4'd9;
            return_state<=strip_i+7'd1<shown_count ? STRIP_LINE : FINISH;state<=CMD_SEND;
        end
        STRIP_LINE:
        begin
            cmd_kind<=0;x0<=strip_x+22;y0<=455;x1<=strip_x+40;y1<=455;ink<=4'd4;
            return_state<=STRIP_WEIGHT;state<=CMD_SEND;
        end
        STRIP_WEIGHT:
        begin
            cmd_kind<=2;text_scale<=1;x0<=strip_x+31-(strip_weight>=100 ? 5 : strip_weight>=10 ? 3 : 1);y0<=443;
            number<={8'd0,strip_weight};digits<=strip_weight>=100 ? 3'd3 : strip_weight>=10 ? 3'd2 : 3'd1;ink<=4'd2;
            return_state<=STRIP_NEXT;state<=CMD_SEND;
        end
        STRIP_NEXT:
        begin strip_i<=strip_i+7'd1;strip_pos<=strip_pos+4'd1;state<=STRIP_BOX;end
        PANEL:
        begin
            // Optional results page: row codes are documented in README.
            text_i<=0;state<=PANEL_TITLE;
        end
        PANEL_TITLE:
        begin
            cmd_kind<=3;text_scale<=3;digits<=6;ink<=status_s==4 ? 4'd7 : 4'd2;
            x0<=20+text_i*72;y0<=20;
            if(status_s==4)
            begin
                case(text_i)
                0:label<="PATH I";
                1:label<="S NOT ";
                default:label<="FOUND ";
                endcase
            end
            else label<="RESULT";
            if(status_s==4 && text_i<2)
            begin text_i<=text_i+6'd1;return_state<=PANEL_TITLE;end
            else begin text_i<=0;return_state<=PANEL_TEXT;end
            state<=CMD_SEND;
        end
        PANEL_TEXT:
        begin
            cmd_kind<=3;text_scale<=2;ink<=4'd2;digits<=3'd6;x0<=20;y0<=72+text_i*14;
            case(text_i)
            0:label<="STATUS";
            1:label<="ERROR ";
            2:label<="SOURCE";
            3:label<="TARGET";
            4:label<="DIST  ";
            5:label<="LENGTH";
            6:label<="PAGE  ";
            default:begin cmd_kind<=2;digits<=3'd3;number<=({12'd0,page_s}-16'd1)*16'd20+{10'd0,text_i}-16'd7;end
            endcase
            return_state<=PANEL_VALUE;state<=CMD_SEND;
        end
        PANEL_VALUE:
        begin
            cmd_kind<=2;text_scale<=2;ink<=4'd2;digits<=3'd5;
            x0<=100;y0<=72+text_i*14;number<=0;
            case(text_i)
            0:number<={12'd0,status_s};
            1:number<={12'd0,error_s};
            2:number<={8'd0,src_s};
            3:number<={8'd0,tgt_s};
            4:if(status_s==4)
              begin cmd_kind<=3;digits<=3;label<="N/A   ";end
              else number<=distance_s;
            5:number<={9'd0,len_s};
            6:number<={12'd0,page_s};
            default:
                if(valid_s && (({28'd0,page_s}-32'd1)*32'd20+{26'd0,text_i}-32'd7)<len_s)
                    number<={8'd0,nodes_s[(({28'd0,page_s}-32'd1)*32'd20+{26'd0,text_i}-32'd7)*8 +: 8]};
                else number<=16'd65535;
            endcase
            text_i<=text_i+6'd1;
            return_state<=(text_i==26 || (text_i==6 && !valid_s)) ? FINISH : PANEL_TEXT;state<=CMD_SEND;
        end
        CMD_SEND:
        begin
            cmd_valid<=1;
            if(cmd_valid && cmd_ready) begin cmd_valid<=0;state<=CMD_WAIT;end
        end
        CMD_WAIT: if(cmd_done) state<=return_state;
        FINISH: begin busy<=0;frame_complete<=1;state<=IDLE;end
        default:state<=IDLE;
        endcase
    end
end
endmodule
