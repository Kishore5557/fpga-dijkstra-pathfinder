module graph_rom (clk, addr, q);

parameter INIT_FILE = "graph.mif";

input clk;
input [13:0] addr;
output [31:0] q;

wire [31:0] rom_q;
wire [13:0] safe_addr;
reg valid_q;

assign safe_addr = (addr < 14'd10124) ? addr : 14'd0;
assign q = valid_q ? rom_q : 32'd0;

always @(posedge clk)
begin
    valid_q <= (addr < 14'd10124);
end

altsyncram #(
    .operation_mode("ROM"),
    .intended_device_family("Cyclone IV E"),
    .ram_block_type("M9K"),
    .width_a(32),
    .widthad_a(14),
    .numwords_a(10124),
    .width_byteena_a(1),
    .init_file(INIT_FILE),
    .outdata_reg_a("UNREGISTERED"),
    .outdata_aclr_a("NONE"),
    .clock_enable_input_a("BYPASS"),
    .clock_enable_output_a("BYPASS"),
    .lpm_type("altsyncram")
) memory (
    .clock0(clk),
    .clocken0(1'b1),
    .aclr0(1'b0),
    .address_a(safe_addr),
    .addressstall_a(1'b0),
    .data_a(32'd0),
    .wren_a(1'b0),
    .rden_a(1'b1),
    .byteena_a(1'b1),
    .q_a(rom_q)
);

endmodule