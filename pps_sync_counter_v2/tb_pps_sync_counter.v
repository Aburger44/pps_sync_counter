// tb_pps_sync_counter.v
// Self-checking testbench for pps_sync_counter v2 (reset-on-PPS version
// with enable and interval_valid).
//
// Drives an asynchronous "PPS" input (deliberately NOT aligned to clk
// edges) and checks, every clock cycle, that:
//   1. pps_edge is a single-cycle pulse, exactly one per PPS pulse,
//      appearing 2 clk rising edges after pps_raw rises (2-FF sync).
//   2. counter restarts at 1 on the cycle after pps_edge and otherwise
//      increments by exactly 1 per cycle, saturating at 0xFFFFFFFF.
//   3. interval updates only after a pps_edge, holds its value between
//      edges, and equals the true number of clk cycles between the last
//      two PPS rising edges (or 0xFFFFFFFF if the counter saturated).
//   4. pps_missing is high exactly while counter > TIMEOUT_CYCLES, and
//      goes high during an interval only if that interval was longer
//      than the timeout.
//   5. rst (asynchronous) clears counter and interval immediately, and
//      the design recovers cleanly afterward.
//   6. interval_valid is 1 only after the second PPS edge since reset or
//      enable, and is 0 after an interval that saturated.
//   7. while enable is low, counter and interval hold and interval_valid
//      is 0; after re-enabling it takes two fresh PPS edges to be valid.
//
// The reference interval is measured by the testbench directly from
// pps_raw (rising edges of clk counted between two pps_raw rising
// edges), so it does not depend on the DUT's own synchronizer or counter.
//
// Real PPS is ~1 second apart at 100 MHz (100,000,000 cycles) -- far
// too many cycles to simulate quickly, so this scales one "second" down
// to ~1000 clock cycles, and the 1.5 s timeout down to 1500 cycles.
// The logic being tested is identical either way; only the ratio matters.
//
// Saturation needs 2^32 cycles (~43 s at 100 MHz) without PPS, which is
// too long to simulate, so the testbench writes the DUT's counter
// directly to just below 0xFFFFFFFF and lets it count up into saturation.
//
// The first pps_edge after any reset or re-enable does not have a
// previous PPS edge, so the interval it produces is not a PPS interval.
// That value is printed but not checked; interval_valid must be 0 then.
//
// Run:  iverilog -o simulation.vvp pps_sync_counter.v tb_pps_sync_counter.v
//       vvp simulation.vvp

`timescale 1ns/1ns

module tb_pps_sync_counter;

    localparam [31:0] TIMEOUT   = 32'd1500;       // scaled 1.5 s
    localparam [31:0] COUNT_MAX = 32'hFFFF_FFFF;

    reg clk = 0;
    reg rst = 1;
    reg pps_raw = 0;
    reg enable = 0;

    wire        pps_edge;
    wire [31:0] counter;
    wire [31:0] interval;
    wire        interval_valid;
    wire        pps_missing;

    pps_sync_counter #(
        .TIMEOUT_CYCLES(TIMEOUT)
    ) dut (
        .clk(clk),
        .rst(rst),
        .pps_raw(pps_raw),
        .enable(enable),
        .pps_edge(pps_edge),
        .counter(counter),
        .interval(interval),
        .interval_valid(interval_valid),
        .pps_missing(pps_missing)
    );

    // 100 MHz clock -> 10 ns period, rising edges at 5, 15, 25, ... ns
    always #5 clk = ~clk;

    // ------------------------------------------------------------------
    // Reference model: measured directly from pps_raw
    // ------------------------------------------------------------------
    integer posedge_count    = 0; // clk rising edges since time 0
    integer last_rise        = 0; // posedge_count at the latest pps_raw rise
    integer prev_rise        = 0; // posedge_count at the rise before that
    integer edges_this_pulse = 0; // pps_edge pulses seen for the latest rise
    integer total_rises      = 0;
    integer total_edges      = 0;

    reg     enable_q         = 0; // enable as the DUT saw it at the last clk edge

    always @(posedge clk) begin
        posedge_count = posedge_count + 1;
        enable_q      = enable;
    end

    always @(posedge pps_raw) begin
        if ($time % 10 == 5)
            $display("WARNING t=%0t: pps_raw rose exactly on a clk edge", $time);
        if (!rst) begin
            prev_rise        = last_rise;
            last_rise        = posedge_count;
            edges_this_pulse = 0;
            total_rises      = total_rises + 1;
        end
    end

    // ------------------------------------------------------------------
    // Checker: sample on the falling edge, when all DUT outputs are stable
    // ------------------------------------------------------------------
    integer    errors            = 0;
    integer    checks            = 0;
    reg        prev_edge         = 0; // pps_edge at the previous sample
    reg [31:0] prev_counter      = 0;
    reg [31:0] prev_interval     = 0;
    reg        prev_valid        = 0;
    reg        valid_expected    = 0; // what interval_valid should read
    reg        valid_next        = 0; // valid_expected after the latest edge
    integer    edges_since_start = 0; // pps_edge pulses since reset/enable
    reg [31:0] expected_interval = 0;
    reg        expected_valid    = 0; // latest edge has a true reference
    reg        missing_seen      = 0; // pps_missing went high this interval
    reg        poked             = 0; // testbench just overwrote dut.counter

    task check(input cond, input [8*64-1:0] what);
        begin
            checks = checks + 1;
            if (!cond) begin
                errors = errors + 1;
                $display("FAIL t=%0t ns: %0s | counter=%0d interval=%0d interval_valid=%b pps_edge=%b pps_missing=%b",
                         $time, what, counter, interval, interval_valid, pps_edge, pps_missing);
            end
        end
    endtask

    always @(negedge clk) begin
        if (rst) begin
            check(counter == 0 && interval == 0 && interval_valid == 0,
                  "outputs not cleared in reset");
            check(pps_edge == 0 && pps_missing == 0, "pps_edge/pps_missing high in reset");
            prev_edge       = 0;
            prev_counter    = 0;
            prev_interval   = 0;
            prev_valid      = 0;
            valid_expected  = 0;
            expected_valid    = 0;
            missing_seen      = 0;
            edges_since_start = 0;
        end else if (!enable_q) begin
            // --- disabled: counter/interval hold, interval_valid cleared ---
            check(counter == prev_counter && interval == prev_interval,
                  "counter/interval changed while disabled");
            check(interval_valid == 0, "interval_valid not cleared while disabled");
            prev_edge         = 0;
            prev_valid        = 0;
            valid_expected    = 0;
            expected_valid    = 0;
            missing_seen      = 0;
            edges_since_start = 0;
        end else begin
            // --- counter and interval behaviour for this cycle ---
            if (prev_edge) begin
                check(counter == 1, "counter did not restart at 1 after pps_edge");
                valid_expected = valid_next;
                if (expected_valid) begin
                    check(interval == expected_interval,
                          "interval != true PPS period");
                    $display("t=%0t ns | interval=%0d cycles (expected %0d)",
                             $time, interval, expected_interval);
                end else begin
                    $display("t=%0t ns | interval=%0d cycles (first edge after reset/enable: not a PPS interval, unchecked)",
                             $time, interval);
                end
            end else if (poked) begin
                // counter was written by the testbench; resync to it
                poked = 0;
            end else begin
                check(counter == ((prev_counter == COUNT_MAX) ? COUNT_MAX
                                                              : prev_counter + 1),
                      "counter did not increment/saturate correctly");
                check(interval == prev_interval, "interval changed without pps_edge");
            end

            // --- interval_valid behaviour ---
            check(interval_valid == valid_expected,
                  "interval_valid wrong for this interval");

            // --- pps_missing behaviour ---
            check(pps_missing == (counter > TIMEOUT),
                  "pps_missing does not match counter > TIMEOUT");
            if (pps_missing)
                missing_seen = 1;

            // --- pps_edge behaviour ---
            if (pps_edge) begin
                check(!prev_edge, "pps_edge high for more than one cycle");
                check(edges_this_pulse == 0, "more than one pps_edge per PPS pulse");
                check(posedge_count - last_rise == 2,
                      "pps_edge latency is not 2 clk edges");
                edges_this_pulse  = edges_this_pulse + 1;
                total_edges       = total_edges + 1;
                edges_since_start = edges_since_start + 1;
                expected_valid    = (edges_since_start >= 2);
                // a saturated counter means the true interval is too
                // long to count, so the DUT must report COUNT_MAX
                expected_interval = (counter == COUNT_MAX) ? COUNT_MAX
                                                           : last_rise - prev_rise;
                // valid only for a real, unsaturated measurement
                valid_next        = expected_valid && (counter != COUNT_MAX);
                // counter runs 1 .. interval, so pps_missing should
                // have fired only if interval > TIMEOUT
                if (expected_valid)
                    check(missing_seen == (expected_interval > TIMEOUT),
                          "pps_missing fired/missed for this interval");
                missing_seen      = 0;
                $display("t=%0t ns | pps_edge fired | counter=%0d", $time, counter);
            end

            prev_edge     = pps_edge;
            prev_counter  = counter;
            prev_interval = interval;
            prev_valid    = interval_valid;
        end
    end

    // ------------------------------------------------------------------
    // Stimulus
    // ------------------------------------------------------------------
    // One PPS period: high for width_ns, low for the remainder.
    task pps_period(input integer width_ns, input integer period_ns);
        begin
            pps_raw = 1;
            #(width_ns);
            pps_raw = 0;
            #(period_ns - width_ns);
        end
    endtask

    initial begin
        $dumpfile("pps_sync_counter.vcd");
        $dumpvars(0, tb_pps_sync_counter);

        rst = 1;
        enable = 0;
        #23 rst = 0;      // deliberately not a multiple of the clk period
        // Stay disabled for a while (outputs must hold at 0), then enable
        // well before the first PPS pulse, mimicking software writing
        // CONTROL to start the module.
        #500 enable = 1;
        #9514;            // first pulse at t=10037 ns: arbitrary, unaligned

        // Periods are not multiples of 10 ns, so each pulse lands at a
        // different point in the clk period and the true interval
        // alternates between neighbouring cycle counts.
        pps_period(23,   10003);   // ~1000 cycles, short pulse (~2 clk)
        pps_period(23,   10003);
        pps_period(23,   10003);
        pps_period(23,    5007);   // ~500 cycles: interval must shrink
        pps_period(23,   20011);   // ~2000 cycles: one missed pulse, so
                                   // pps_missing must fire, then clear
        pps_period(3001, 10003);   // wide pulse: still one pps_edge only
        pps_period(23,   10003);

        // Asynchronous reset in the middle of an interval.
        pps_raw = 1; #23; pps_raw = 0;
        #4001;
        rst = 1;
        #1;
        check(counter == 0 && interval == 0 && interval_valid == 0,
              "async reset did not clear outputs");
        #36 rst = 0;
        #(10003 - 23 - 4001 - 37);

        // Recovery after reset: first interval is unchecked, rest checked.
        pps_period(23, 10003);
        pps_period(23, 10003);
        pps_period(23, 10003);

        // Long PPS outage: jump the counter to just below its maximum
        // (2 ns after a clk rising edge, away from the DUT's updates) and
        // let it run into saturation. It must stop at COUNT_MAX, keep
        // pps_missing high, and the next PPS must report COUNT_MAX.
        // Times here land the write at t=127107 ns (posedge 127105 + 2)
        // and keep the next PPS rise off a clk edge.
        pps_raw = 1; #23; pps_raw = 0;
        #2002;
        force_counter(COUNT_MAX - 50);
        #2000;                     // ~200 cycles: well past saturation
        check(counter == COUNT_MAX && pps_missing,
              "counter did not saturate with pps_missing high");
        #(10006 - 23 - 2002 - 2000);

        // PPS returns: interval = COUNT_MAX with interval_valid = 0, then
        // normal valid intervals again.
        pps_period(23, 10003);
        pps_period(23, 10003);
        pps_period(23, 10003);

        // Disable in the middle of an interval, then re-enable. Outputs
        // hold and interval_valid clears; the first edge after enabling is
        // unchecked, and interval_valid returns only on the second edge.
        pps_raw = 1; #23; pps_raw = 0;
        #3001 enable = 0;
        #2001 enable = 1;
        #(10003 - 23 - 3001 - 2001);
        pps_period(23, 10003);
        pps_period(23, 10003);
        pps_period(23, 10003);

        #100;
        check(total_edges == total_rises, "pps_edge count != PPS pulse count");

        $display("----------------------------------------------------------");
        $display("%0d PPS pulses, %0d pps_edge pulses, %0d checks, %0d errors",
                 total_rises, total_edges, checks, errors);
        if (errors == 0)
            $display("TEST PASS");
        else
            $display("TEST FAIL");
        $finish;
    end

    // Overwrite the DUT's counter register directly (simulation only).
    task force_counter(input [31:0] value);
        begin
            dut.counter = value;
            poked = 1;
        end
    endtask

endmodule
