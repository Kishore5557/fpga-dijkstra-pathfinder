module dijkstra_core (clk, rst, start, stop, source_node, target_node,
    graph_ready, graph_error, active_nodes, slots_per_node, connection_base,
    req_valid, req_ready, req_addr, rsp_valid, rsp_data,
    busy, done, no_path, stopped, invalid_selection, total_distance,
    path_len, path_nodes, path_edge_slots);
input clk, rst, start, stop, graph_ready, graph_error;
input [7:0] source_node, target_node;
input [6:0] active_nodes, slots_per_node;
input [13:0] connection_base;
output req_valid;
input req_ready, rsp_valid;
output [13:0] req_addr;
input [31:0] rsp_data;
output reg busy, done, no_path, stopped, invalid_selection;
output reg [15:0] total_distance;
output reg [6:0] path_len;
output [799:0] path_nodes, path_edge_slots;
localparam [15:0] INF=16'hFFFF;
localparam S_IDLE=0, S_INIT=1, S_FIND_INIT=2, S_FIND_SCAN=3,
    S_DECIDE=4, S_REQ=5, S_WAIT=6, S_RELAX=7, S_RECON=8,
    S_REVERSE=9, S_FINISH=10, S_DRAIN=11;
reg [3:0] state;
reg [15:0] distance [0:99];
reg [7:0] previous [0:99], previous_slot [0:99];
reg previous_valid [0:99], visited [0:99];
reg [7:0] path_mem [0:99], slot_mem [0:99], reverse_path [0:99], reverse_slot [0:99];
reg [7:0] source_reg, target_reg, current_node, best_node, recon_node;
reg [6:0] init_index, scan_index, edge_index, recon_count, reverse_len, reverse_index;
reg [15:0] best_distance;
reg best_valid;
reg [31:0] captured_word;
wire [7:0] neighbor=captured_word[15:8];
wire [31:0] wide_addr={18'd0,connection_base}+
    {24'd0,current_node}*{25'd0,slots_per_node}+{25'd0,edge_index};
wire [16:0] candidate={1'b0,distance[current_node[6:0]]}+{9'd0,captured_word[7:0]};
assign req_addr=wide_addr[13:0];
assign req_valid=state==S_REQ && !stop && graph_ready && !graph_error && wide_addr<10124;
genvar g;
generate for(g=0;g<100;g=g+1) begin: PACK_PATH
    assign path_nodes[g*8 +: 8]=path_mem[g];
    assign path_edge_slots[g*8 +: 8]=slot_mem[g];
end endgenerate
integer i;
always @(posedge clk)
begin
    if(rst)
    begin
        state<=S_IDLE; busy<=0; done<=0; no_path<=0; stopped<=0;
        invalid_selection<=0; total_distance<=0; path_len<=0;
        source_reg<=0; target_reg<=0; current_node<=0; best_node<=0; recon_node<=0;
        init_index<=0; scan_index<=0; edge_index<=0; recon_count<=0;
        reverse_len<=0; reverse_index<=0; best_distance<=INF; best_valid<=0; captured_word<=0;
        for(i=0;i<100;i=i+1)
        begin
            distance[i]<=INF; previous[i]<=0; previous_slot[i]<=0;
            previous_valid[i]<=0; visited[i]<=0; path_mem[i]<=0; slot_mem[i]<=0;
            reverse_path[i]<=0; reverse_slot[i]<=0;
        end
    end
    else if (state!=S_DRAIN && busy && (stop || graph_error || !graph_ready))
    begin
        done<=0; no_path<=0; stopped<=1; path_len<=0; total_distance<=0;
        if(state==S_WAIT && !rsp_valid) begin state<=S_DRAIN; busy<=1; end
        else begin state<=S_IDLE; busy<=0; end
    end
    else
    begin
        case(state)
            S_IDLE:
            begin
                if(start && !stop)
                begin
                    if(graph_ready && !graph_error && active_nodes!=0 &&
                       source_node<{1'b0,active_nodes} && target_node<{1'b0,active_nodes})
                    begin
                        source_reg<=source_node; target_reg<=target_node;
                        busy<=1; done<=0; no_path<=0; stopped<=0; invalid_selection<=0;
                        total_distance<=0; path_len<=0; init_index<=0; state<=S_INIT;
                    end
                    else begin invalid_selection<=1; done<=0; path_len<=0; end
                end
            end
            S_INIT:
            begin
                distance[init_index]<={1'b0,init_index}==source_reg ? 16'd0 : INF;
                previous_valid[init_index]<=0; visited[init_index]<=0;
                if(init_index==active_nodes-1) state<=S_FIND_INIT;
                else init_index<=init_index+7'd1;
            end
            S_FIND_INIT:
            begin
                scan_index<=0; best_valid<=0; best_distance<=INF; state<=S_FIND_SCAN;
            end
            S_FIND_SCAN:
            begin
                if(!visited[scan_index] && distance[scan_index]<best_distance)
                begin
                    best_distance<=distance[scan_index]; best_node<={1'b0,scan_index}; best_valid<=1;
                end
                if(scan_index==active_nodes-1) state<=S_DECIDE;
                else scan_index<=scan_index+7'd1;
            end
            S_DECIDE:
            begin
                if(!best_valid)
                begin
                    no_path<=1; total_distance<=INF; path_len<=0; state<=S_FINISH;
                end
                else
                begin
                    visited[best_node[6:0]]<=1;
                    if(best_node==target_reg)
                    begin
                        total_distance<=best_distance; recon_node<=target_reg;
                        recon_count<=0; state<=S_RECON;
                    end
                    else begin current_node<=best_node; edge_index<=0; state<=S_REQ; end
                end
            end
            S_REQ: if(req_valid && req_ready) state<=S_WAIT;
            S_WAIT: if(rsp_valid) begin captured_word<=rsp_data; state<=S_RELAX; end
            S_RELAX:
            begin
                if(captured_word!=32'hFFFFFFFF && captured_word[31:16]==0 && neighbor<{1'b0,active_nodes})
                begin
                    if(!visited[neighbor[6:0]] && distance[current_node[6:0]]!=INF)
                    begin
                        if(candidate<17'h0FFFF && candidate<{1'b0,distance[neighbor[6:0]]})
                        begin
                            distance[neighbor[6:0]]<=candidate[15:0]; previous[neighbor[6:0]]<=current_node;
                            previous_slot[neighbor[6:0]]<={1'b0,edge_index}; previous_valid[neighbor[6:0]]<=1;
                        end
                    end
                end
                if(edge_index==slots_per_node-1) state<=S_FIND_INIT;
                else begin edge_index<=edge_index+7'd1; state<=S_REQ; end
            end
            S_RECON:
            begin
                if(recon_node>={1'b0,active_nodes} || recon_count>=active_nodes)
                begin no_path<=1; path_len<=0; total_distance<=INF; state<=S_FINISH; end
                else
                begin
                    reverse_path[recon_count]<=recon_node;
                    reverse_slot[recon_count]<=previous_slot[recon_node[6:0]];
                    if(recon_node==source_reg)
                    begin
                        reverse_len<=recon_count+7'd1; path_len<=recon_count+7'd1;
                        reverse_index<=0; state<=S_REVERSE;
                    end
                    else if(!previous_valid[recon_node[6:0]] || recon_count==active_nodes-1)
                    begin no_path<=1; path_len<=0; total_distance<=INF; state<=S_FINISH; end
                    else begin recon_node<=previous[recon_node[6:0]]; recon_count<=recon_count+7'd1; end
                end
            end
            S_REVERSE:
            begin
                path_mem[reverse_index]<=reverse_path[reverse_len-7'd1-reverse_index];
                if(reverse_index+7'd1<reverse_len)
                    slot_mem[reverse_index]<=reverse_slot[reverse_len-7'd2-reverse_index];
                else slot_mem[reverse_index]<=0;
                if(reverse_index==reverse_len-1) state<=S_FINISH;
                else reverse_index<=reverse_index+7'd1;
            end
            S_FINISH: begin busy<=0; done<=1; state<=S_IDLE; end
            S_DRAIN: if(rsp_valid || graph_error) begin busy<=0; state<=S_IDLE; end
            default: begin state<=S_IDLE; busy<=0; path_len<=0; end
        endcase
    end
end
endmodule
