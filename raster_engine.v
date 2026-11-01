module raster_engine (clk, rst, cmd_valid, cmd_ready, cmd_kind,
    x0, y0, x1, y1, color, number, digits, label, text_scale, done, wr_en, wr_addr, wr_data);
input clk, rst, cmd_valid;
output cmd_ready;
input [1:0] cmd_kind;
input signed [31:0] x0,y0,x1,y1;
input [3:0] color;
input [15:0] number;
input [2:0] digits;
input [47:0] label;
input [1:0] text_scale;
output reg done;
output reg wr_en;
output reg [18:0] wr_addr;
output [3:0] wr_data;
localparam IDLE=0, LINE=1, RECT=2, TEXT=3;
reg [1:0] state;
integer px,py,ex,ey,ox,oy,dx,dy,sx,sy,err;
wire signed [31:0] twice_err=err*2;
reg [3:0] ink;
reg [15:0] value;
reg [47:0] text_value;
reg text_mode;
reg [2:0] ndigits, digit_index, gx, gy;
reg [1:0] scale_s, sub_x, sub_y;
reg [2:0] brush_x,brush_y;
integer digit, tx,ty, address;
wire [2:0] brush_last=ink==4 ? 3'd4 : 3'd1;
wire large_number=!text_mode && scale_s==3;
reg [34:0] large_glyph;
reg [14:0] glyph;
assign cmd_ready=state==IDLE;
assign wr_data=ink;
function [14:0] font;
input integer d;
begin
case(d)
0:font=15'b111101101101111;
1:font=15'b010110010010111;
2:font=15'b111001111100111;
3:font=15'b111001111001111;
4:font=15'b101101111001001;
5:font=15'b111100111001111;
6:font=15'b111100111101111;
7:font=15'b111001010010010;
8:font=15'b111101111101111;
9:font=15'b111101111001111;
47:font=15'b001001010100100;
65:font=15'b010101111101101;
67:font=15'b111100100100111;
68:font=15'b110101101101110;
69:font=15'b111100110100111;
70:font=15'b111100110100100;
71:font=15'b111100101101111;
72:font=15'b101101111101101;
73:font=15'b111010010010111;
76:font=15'b100100100100111;
78:font=15'b101111111111101;
79:font=15'b111101101101111;
80:font=15'b111101111100100;
82:font=15'b110101110101101;
83:font=15'b111100111001111;
84:font=15'b111010010010010;
89:font=15'b101101010010010;
87:font=15'b101101111111101;
85:font=15'b101101101101111;
default:font=15'd0;
endcase
end
endfunction
function [34:0] number_font;
input integer d;
begin
case(d)
0:number_font=35'b01110100011000110001100011000101110;
1:number_font=35'b00100011000010000100001000010001110;
2:number_font=35'b01110100010000100010001000100011111;
3:number_font=35'b11110000010000101110000010000111110;
4:number_font=35'b00010001100101010010111110001000010;
5:number_font=35'b11111100001000011110000010000111110;
6:number_font=35'b01110100001000011110100011000101110;
7:number_font=35'b11111000010001000100010000100001000;
8:number_font=35'b01110100011000101110100011000101110;
9:number_font=35'b01110100011000101111000010000101110;
default:number_font=35'd0;
endcase
end
endfunction
always @(*)
begin
    case(ndigits-digit_index)
    2:digit=({16'd0,value}/32'd10)%32'd10;
    3:digit=({16'd0,value}/32'd100)%32'd10;
    4:digit=({16'd0,value}/32'd1000)%32'd10;
    5:digit=({16'd0,value}/32'd10000)%32'd10;
    default:digit={16'd0,value}%32'd10;
    endcase
    if(text_mode) digit={24'd0,text_value[47-digit_index*8 -: 8]};
    glyph=font(digit);large_glyph=number_font(digit);
    tx=px; ty=py;
    // Two-pixel graph strokes; five-pixel highlighted route.
    if(state==LINE) begin tx=px+{29'd0,brush_x}-(ink==4 ? 2 : 1); ty=py+{29'd0,brush_y}-(ink==4 ? 2 : 1); end
    if(state==TEXT)
    begin
        tx=ox+(digit_index*(large_number ? 6 : 4)+{29'd0,gx})*{30'd0,scale_s}+{30'd0,sub_x};
        ty=oy+{29'd0,gy}*{30'd0,scale_s}+{30'd0,sub_y};
    end
    address=ty*640+tx;
    wr_en=0; wr_addr=0;
    if(state!=IDLE && tx>=0 && tx<640 && ty>=0 && ty<480 && address>=0 && address<307200)
    begin
        wr_addr=address[18:0];
        if(state!=TEXT) wr_en=1;
        else if(large_number) wr_en=large_glyph[32'd34-{29'd0,gy}*32'd5-{29'd0,gx}];
        else wr_en=glyph[14-gy*3-gx];
    end
end
always @(posedge clk)
begin
    if(rst)
    begin
        state<=IDLE; done<=0; px<=0; py<=0; ex<=0; ey<=0; ox<=0; oy<=0;
        dx<=0; dy<=0; sx<=0; sy<=0; err<=0; ink<=0;
        scale_s<=1;sub_x<=0;sub_y<=0;brush_x<=0;brush_y<=0;
        value<=0; text_value<=0;text_mode<=0;ndigits<=1; digit_index<=0; gx<=0; gy<=0;
    end
    else
    begin
        done<=0;
        case(state)
        IDLE: if(cmd_valid)
        begin
            brush_x<=0;brush_y<=0;sub_x<=0;sub_y<=0;
            scale_s<=text_scale==0 ? 2'd1 : text_scale;
            px<=x0; py<=y0; ex<=x1; ey<=y1; ox<=x0; oy<=y0; ink<=color;
            if(cmd_kind==0)
            begin
                dx<=x1>=x0 ? x1-x0 : x0-x1;
                dy<=y1>=y0 ? y0-y1 : y1-y0;
                sx<=x0<x1 ? 1 : -1; sy<=y0<y1 ? 1 : -1;
                err<=(x1>=x0 ? x1-x0 : x0-x1)+(y1>=y0 ? y0-y1 : y1-y0);
                state<=LINE;
            end
            else if(cmd_kind==1) state<=RECT;
            else
            begin
                value<=number;text_value<=label;text_mode<=cmd_kind==3;ndigits<=digits; digit_index<=0; gx<=0; gy<=0; state<=TEXT;
            end
        end
        LINE:
        begin
            if(brush_x==brush_last)
            begin
                brush_x<=0;
                if(brush_y==brush_last)
                begin
                    brush_y<=0;
                    if(px==ex && py==ey) begin state<=IDLE; done<=1; end
                    else
                    begin
                        if(twice_err>=dy) px<=px+sx;
                        if(twice_err<=dx) py<=py+sy;
                        err<=err+(twice_err>=dy ? dy : 0)+(twice_err<=dx ? dx : 0);
                    end
                end
                else brush_y<=brush_y+3'd1;
            end
            else brush_x<=brush_x+3'd1;
        end
        RECT:
        begin
            if(px==ex)
            begin
                px<=ox;
                if(py==ey) begin state<=IDLE; done<=1; end
                else py<=py+1;
            end
            else px<=px+1;
        end
        TEXT:
        begin
            if(sub_x+2'd1==scale_s)
            begin
                sub_x<=0;
                if(sub_y+2'd1==scale_s)
                begin
                    sub_y<=0;
                    if(gx==(large_number ? 4 : 2))
                    begin
                        gx<=0;
                        if(gy==(large_number ? 6 : 4))
                        begin
                            gy<=0;
                            if(digit_index+1==ndigits) begin state<=IDLE; done<=1; end
                            else digit_index<=digit_index+3'd1;
                        end
                        else gy<=gy+3'd1;
                    end
                    else gx<=gx+3'd1;
                end
                else sub_y<=sub_y+2'd1;
            end
            else sub_x<=sub_x+2'd1;
        end
        default:state<=IDLE;
        endcase
    end
end
endmodule
