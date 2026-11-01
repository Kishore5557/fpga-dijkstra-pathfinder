module vga_timing_640x480 (clk50, rst, pixel_ce, x, y, active, hs, vs, vblank, pixel_phase);
input clk50,rst;
output pixel_ce,active,hs,vs,vblank;
output reg [9:0] x,y;
output reg pixel_phase;
assign pixel_ce=!pixel_phase;
assign active=x<640 && y<480;
assign hs=!(x>=656 && x<752);
assign vs=!(y>=490 && y<492);
assign vblank=pixel_ce && x==0 && y==480;
always @(posedge clk50)
begin
    if(rst) begin x<=0; y<=0; pixel_phase<=0; end
    else
    begin
        pixel_phase<=!pixel_phase;
        if(pixel_ce)
        begin
            if(x==799)
            begin
                x<=0;
                if(y==524) y<=0;
                else y<=y+10'd1;
            end
            else x<=x+10'd1;
        end
    end
end
endmodule
