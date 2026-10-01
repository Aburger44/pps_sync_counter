// pps_sync_counter.v
// Synchronizes an asynchronous PPS input into the clk domain,
// edge-detects it, and runs a counter that restarts at 1 on every
// PPS edge. On each PPS edge, interval latches the number of clk
// cycles since the previous PPS edge. pps_missing flags when no
// PPS edge has arrived for more than TIMEOUT_CYCLES.

// made in collaboration with Claude Code and Jack Allenburg

`timescale 1ns/1ns

module pps_sync_counter #(
    // cycles without a PPS edge before pps_missing goes high
    // default: 1.5 s at a 100 MHz clk, so one missed PPS pulse is flagged
    parameter [31:0] TIMEOUT_CYCLES = 32'd150_000_000
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        pps_raw,       // asynchronous input from GPS module

    output wire        pps_edge,      // 1-cycle pulse on synchronized PPS rising edge
    output reg  [31:0] counter,       // cycles since last PPS edge (1 on the cycle after it), saturates
    output reg  [31:0] interval,      // cycles between last two PPS edges, saturates
    output wire        pps_missing    // high while counter > TIMEOUT_CYCLES
);

    // ---- 2-FF synchronizer ----
    reg pps_sync1, pps_sync2, pps_prev;
    // runs every clock cycle
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pps_sync1 <= 1'b0;
            pps_sync2 <= 1'b0;
            pps_prev  <= 1'b0;
        end else begin
            // this takes two clock cycles to register the pps edge,
            // but it protects against metastability: pps_sync1 gets a
            // full clock period to settle before pps_sync2 reads it
            pps_sync1 <= pps_raw;   // stage 1: may go metastable
            pps_sync2 <= pps_sync1; // stage 2: settled value
            // this will store the previous read at the last clock
            pps_prev  <= pps_sync2; // for edge detection
        end
    end
    // pps_edge is when the last read of the pps
    // wire was 0 and the current read is 1
    // this ensures just the start of the pulse is detected,
    // so pps_edge is high for exactly one clock cycle
    assign pps_edge = pps_sync2 & ~pps_prev;

    // ---- PPS-reset counter + interval ----
    // the counter restarts at 1 on every pps edge (the edge cycle
    // itself counts as the first cycle), so at the next pps edge it
    // already holds the full number of cycles since the last edge
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // reset all the values
            counter     <= 32'd0;
            interval    <= 32'd0;
        end else begin
            // add 1 to the counter, but stop at the maximum instead of
            // wrapping to 0 (saturate), so a long PPS outage can never
            // look like a fresh, short count
            if (counter != 32'hFFFF_FFFF)
                counter <= counter + 32'd1;
            // if the pps edge is high, meaning the pps signal was just sent and registered
            if (pps_edge) begin
                // cycles between the last two pps edges; a saturated
                // counter passes 0xFFFFFFFF through as "too long"
                interval    <= counter;
                // overrides the increment above: the last nonblocking
                // assignment in the block wins
                counter     <= 32'd1;
            end
        end
    end

    // ---- PPS timeout ----
    // high once the counter passes the threshold; because the counter
    // saturates, this stays high until the next pps edge resets it
    assign pps_missing = (counter > TIMEOUT_CYCLES);

endmodule
