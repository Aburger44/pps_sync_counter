// pps_sync_counter.v
// Synchronizes an asynchronous PPS input into the clk domain,
// edge-detects it, runs a free-running counter, and captures
// the counter value + interval on every PPS edge.

// made in collaboration with claude code and Jack Allenburg

module pps_sync_counter (
    input  wire        clk,
    input  wire        rst,
    input  wire        pps_raw,       // asynchronous input from GPS module

    output wire        pps_edge,      // 1-cycle pulse on synchronized PPS rising edge
    output reg  [31:0] counter,       // free-running counter
    output reg  [31:0] pps_capture,   // counter value latched at last PPS edge
    output reg  [31:0] interval       // cycles between last two PPS edges
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
            // ensures the pps signal is fully registered
            pps_sync1 <= pps_raw;   // stage 1: may go metastable
            pps_sync2 <= pps_sync1; // stage 2: settled value
            // this will store the previous read at the last clock
            pps_prev  <= pps_sync2; // for edge detection
        end
    end
    // pps_edge must be when the last read of the pps
    // wire was 0 and the current read is 1
    assign pps_edge = pps_sync2 & ~pps_prev;

    // what happens when the 32 bit register gets full?

    // ---- free-running counter + capture ----
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // reset all the values
            counter     <= 32'd0;
            pps_capture <= 32'd0;
            interval    <= 32'd0;
        end else begin
            // add 1 to the counter
            counter <= counter + 32'd1;
            // if the pps edge is high, meaning the pps signal was just sent and registered
            if (pps_edge) begin
                // find the difference between the clk at last pps_edge
                // and the clk at this new pps_edge
                interval    <= counter - pps_capture;
                pps_capture <= counter;
            end
        end
    end

endmodule
