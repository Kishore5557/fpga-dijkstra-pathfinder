// -----------------------------------------------------------------------------
// Debounces an active-low pushbutton and emits one clock-wide pulse when pressed.
// Defaults are for a 50 MHz FPGA clock and about 10 ms debounce time.
// -----------------------------------------------------------------------------
module button_onepulse #(
    parameter integer COUNT_MAX = 500000
)(
    input  clk,
    input  rst,
    input  button_n,
    output reg pulse
);
    reg sync0;
    reg sync1;
    reg stable_state;
    reg [19:0] count;

    always @(posedge clk) begin
        if (rst) begin
            sync0       <= 1'b1;
            sync1       <= 1'b1;
            stable_state<= 1'b1;
            count       <= 20'd0;
            pulse       <= 1'b0;
        end
        else begin
            sync0 <= button_n;
            sync1 <= sync0;
            pulse <= 1'b0;

            if (sync1 == stable_state) begin
                count <= 20'd0;
            end
            else if ({12'd0,count} >= COUNT_MAX - 1) begin
                // A stable 1 -> 0 transition is one physical button press.
                if (stable_state && !sync1)
                    pulse <= 1'b1;

                stable_state <= sync1;
                count <= 20'd0;
            end
            else begin
                count <= count + 20'd1;
            end
        end
    end
endmodule
