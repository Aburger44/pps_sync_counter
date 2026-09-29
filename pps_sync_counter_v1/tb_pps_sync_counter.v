// tb_pps_sync_counter.v
// Drives an asynchronous "PPS" input (deliberately NOT aligned to clk
// edges) and watches the synchronizer, edge detector, counter, and
// capture register respond.
//
// Real PPS is ~1 second apart at 100 MHz (100,000,000 cycles) -- far
// too many cycles to simulate quickly, so this scales the interval
// down to ~1000 clock cycles per "PPS" pulse instead. The logic being
// tested is identical either way; only the ratio matters.

`timescale 1ns/1ns

module tb_pps_sync_counter;

    reg clk = 0;
    reg rst = 1;
    reg pps_raw = 0;

    wire        pps_edge;
    wire [31:0] counter;
    wire [31:0] pps_capture;
    wire [31:0] interval;

    pps_sync_counter dut (
        .clk(clk),
        .rst(rst),
        .pps_raw(pps_raw),
        .pps_edge(pps_edge),
        .counter(counter),
        .pps_capture(pps_capture),
        .interval(interval)
    );

    // 100 MHz clock -> 10 ns period
    always #5 clk = ~clk;

    // Release reset after a few cycles
    initial begin
        rst = 1;
        #23 rst = 0;   // deliberately not a multiple of the clk period
    end

    // Drive an asynchronous PPS pulse train. Intervals are close to
    // 1000 clock cycles (10,000 ns) but each one is nudged by a
    // different, non-multiple-of-10ns offset so every pulse lands at
    // a different, unaligned point relative to clk edges -- exactly
    // the "arrives at a random point in the clock period" situation
    // the synchronizer exists for.
    initial begin
        pps_raw = 0;
        #10037;  // first pulse: arbitrary, unaligned offset
        repeat (5) begin
            pps_raw = 1;
            #23;              // pulse width (not a multiple of clk period)
            pps_raw = 0;
            #9980;             // remainder of the ~1000-cycle interval
        end
    end

    // Log every time the synchronized edge pulse fires
    always @(posedge clk) begin
        if (pps_edge)
            $display("t=%0t ns | pps_edge fired | counter=%0d | pps_capture=%0d | interval=%0d cycles",
                      $time, counter, pps_capture, interval);
    end

    // Waveform dump for inspection in GTKWave
    initial begin
        $dumpfile("pps_sync_counter.vcd");
        $dumpvars(0, tb_pps_sync_counter);
    end

    initial begin
        #70000;
        $display("Simulation finished.");
        $finish;
    end

endmodule
