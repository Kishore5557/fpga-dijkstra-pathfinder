module graph_image_controller (clk, rst, rom_addr, rom_q,
    graph_ready, graph_error, error_code, active_nodes, slots_per_node,
    connection_base, coordinate_base, image_words, valid_edge_count,
    d_req_valid, d_req_ready, d_req_addr, d_rsp_valid, d_rsp_data,
    r_req_valid, r_req_ready, r_req_addr, r_rsp_valid, r_rsp_data,
    c_req_valid, c_req_id, c_rsp_valid, c_x, c_y);
input clk, rst;
output reg [13:0] rom_addr;
input [31:0] rom_q;
output reg graph_ready, graph_error;
output reg [3:0] error_code;
output reg [6:0] active_nodes, slots_per_node;
output reg [13:0] connection_base, coordinate_base, image_words, valid_edge_count;
input d_req_valid, r_req_valid;
input [13:0] d_req_addr, r_req_addr;
output d_req_ready, r_req_ready;
output reg d_rsp_valid, r_rsp_valid;
output reg [31:0] d_rsp_data, r_rsp_data;
input c_req_valid;
input [7:0] c_req_id;
output reg c_rsp_valid;
output reg [9:0] c_x;
output reg [8:0] c_y;

localparam S_REQ=0, S_WAIT=1, S_CAPTURE=2, S_VALIDATE=3,
           S_READY=4, S_BUS_WAIT=5, S_BUS_REPLY=6, S_ERROR=7;
reg [3:0] state;
reg [1:0] phase;
reg [13:0] index, edge_seen;
reg [31:0] header [0:23];
reg [9:0] node_x [0:99];
reg [8:0] node_y [0:99];
reg owner, last_owner;
reg [3:0] header_error;
reg [31:0] product, total, id_bits;
integer j;
wire choose_d = d_req_valid && (!r_req_valid || last_owner);
assign d_req_ready = graph_ready && state==S_READY && choose_d;
assign r_req_ready = graph_ready && state==S_READY && r_req_valid && !choose_d;

always @(*)
begin
    product = 32'd0;
    total = 32'd0;
    id_bits = 32'd1;
    header_error = 4'd0;
    for (j=1; j<7; j=j+1)
        if (header[3] > (32'd1 << j)) id_bits=j+1;
    if (header[3]<1 || header[3]>100 || header[4]<1 || header[4]>100)
        header_error=4'd2;
    else
    begin
        product=header[3]*header[4];
        total=32'd24+product+header[3];
        if (header[5]>product) header_error=4'd2;
        else if (header[13]!=24 || header[14]!=product ||
                 header[15]!=24+product || header[16]!=header[3] ||
                 header[17]!=total || total>10124) header_error=4'd3;
        else if (header[0]!=32'h4E464731 || header[1]!=1 || header[2]!=24 ||
                 header[6]!=id_bits || header[7]!=8 || header[8]!=32 ||
                 header[9]!=640 || header[10]!=480 || header[11]!=10 ||
                 header[12]!=9 || header[18]!=32'hFFFFFFFF ||
                 header[19]!=16 || header[20]!=8 || header[21]!=100 ||
                 header[22]!=100 || header[23]!=1) header_error=4'd1;
    end
end

always @(posedge clk)
begin
    if (rst)
    begin
        state<=S_REQ; phase<=0; index<=0; rom_addr<=0; edge_seen<=0;
        graph_ready<=0; graph_error<=0; error_code<=0;
        active_nodes<=0; slots_per_node<=0; connection_base<=0;
        coordinate_base<=0; image_words<=0; valid_edge_count<=0;
        d_rsp_valid<=0; r_rsp_valid<=0; d_rsp_data<=0; r_rsp_data<=0;
        c_rsp_valid<=0; c_x<=0; c_y<=0; owner<=0; last_owner<=1;
    end
    else
    begin
        d_rsp_valid<=0; r_rsp_valid<=0; c_rsp_valid<=0;
        if (graph_ready && c_req_valid && c_req_id<{1'b0,active_nodes})
        begin
            c_x<=node_x[c_req_id[6:0]]; c_y<=node_y[c_req_id[6:0]]; c_rsp_valid<=1;
        end
        case (state)
            S_REQ:
            begin
                if (phase==0) rom_addr<=index;
                else if (phase==1) rom_addr<=14'd24+index;
                else rom_addr<=header[15][13:0]+index;
                state<=S_WAIT;
            end
            S_WAIT: state<=S_CAPTURE;
            S_CAPTURE:
            begin
                state<=S_REQ;
                if (phase==0)
                begin
                    header[index[4:0]]<=rom_q;
                    if (index==23) state<=S_VALIDATE;
                    else index<=index+14'd1;
                end
                else if (phase==1)
                begin
                    if (rom_q!=32'hFFFFFFFF &&
                        (rom_q[31:16]!=0 || {24'd0,rom_q[15:8]}>=header[3]))
                    begin
                        error_code<=4'd4; state<=S_ERROR;
                    end
                    else
                    begin
                        if (rom_q!=32'hFFFFFFFF) edge_seen<=edge_seen+14'd1;
                        if ({18'd0,index}+32'd1==header[14])
                        begin
                            if ({18'd0,edge_seen}+(rom_q!=32'hFFFFFFFF ? 32'd1 : 32'd0)!=header[5])
                            begin
                                error_code<=4'd5; state<=S_ERROR;
                            end
                            else begin phase<=2; index<=0; end
                        end
                        else index<=index+14'd1;
                    end
                end
                else
                begin
                    if (rom_q[31:16]>=640 || rom_q[15:0]>=480)
                    begin
                        error_code<=4'd6; state<=S_ERROR;
                    end
                    else
                    begin
                        node_x[index[6:0]]<=rom_q[25:16]; node_y[index[6:0]]<=rom_q[8:0];
                        if ({18'd0,index}+32'd1==header[3])
                        begin
                            active_nodes<=header[3][6:0]; slots_per_node<=header[4][6:0];
                            valid_edge_count<=header[5][13:0]; connection_base<=14'd24;
                            coordinate_base<=header[15][13:0]; image_words<=header[17][13:0];
                            graph_ready<=1; state<=S_READY;
                        end
                        else index<=index+14'd1;
                    end
                end
                // synthesis translate_off
                if ((^rom_q)===1'bx)
                begin
                    error_code<=4'd7; state<=S_ERROR;graph_ready<=0;graph_error<=1;
                    $display("NFG1 unknown data at address %0d",rom_addr);
                end
                // synthesis translate_on
            end
            S_VALIDATE:
            begin
                if (header_error!=0) begin error_code<=header_error; state<=S_ERROR; end
                else begin phase<=1; index<=0; edge_seen<=0; state<=S_REQ; end
            end
            S_READY:
            begin
                if (d_req_ready || r_req_ready)
                begin
                    owner<=!choose_d; last_owner<=!choose_d;
                    rom_addr<=choose_d ? d_req_addr : r_req_addr;
                    state<=S_BUS_WAIT;
                    if ((choose_d ? d_req_addr : r_req_addr)>=image_words)
                    begin
                        error_code<=4'd8; graph_ready<=0; state<=S_ERROR;
                    end
                end
            end
            S_BUS_WAIT: state<=S_BUS_REPLY;
            S_BUS_REPLY:
            begin
                if (owner) begin r_rsp_data<=rom_q; r_rsp_valid<=1; end
                else begin d_rsp_data<=rom_q; d_rsp_valid<=1; end
                state<=S_READY;
            end
            S_ERROR: begin graph_error<=1; graph_ready<=0; end
            default: begin error_code<=4'd8; state<=S_ERROR; end
        endcase
    end
end
endmodule
