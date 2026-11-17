`timescale 1ns/1ns

module pps_test_gen #(
    parameter [31:0] PERIOD_CYCLES = 100_000_000, 
    parameter [31:0] HIGH_CYCLES = 10_000_000
)(
    input wire clk,
    input wire rst_n,
    output reg pps_out
);
    reg [31:0] count;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            count <= 32'd0;
            pps_out <= 32'd0;
        end else begin
            if (count == PERIOD_CYCLES - 1)
                count <= 32'd0;
            else
                count <= count + 32'd1;
            pps_out <= (count < HIGH_CYCLES);
        end
    end
endmodule