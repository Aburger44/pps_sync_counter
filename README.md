# pps_sync_counter

A small Verilog module for measuring a local FPGA clock against a GPS
pulse-per-second (PPS) signal. It brings the asynchronous PPS input safely
into the clock domain with a 2-flip-flop synchronizer, detects each rising
edge, and runs a counter that restarts at every PPS edge. On each edge,
`interval` latches the number of clock cycles since the previous one, which
shows whether the local clock is running fast or slow relative to GPS time.
The counter saturates instead of wrapping, and `pps_missing` goes high when
no PPS edge arrives within `TIMEOUT_CYCLES` (default 1.5 s at 100 MHz).

The repository holds two versions, each with the module
(`pps_sync_counter.v`) and a self-checking testbench
(`tb_pps_sync_counter.v`). `pps_sync_counter_v1/` is the core design.
`pps_sync_counter_v2/` adds an `enable` input, so control logic can start
and stop the module without a reset, and an `interval_valid` output that is
high only when `interval` is a real measurement. To simulate either version
with Icarus Verilog, run this from that version's folder:

```sh
iverilog -o simulation.vvp pps_sync_counter.v tb_pps_sync_counter.v
vvp simulation.vvp    # ends with TEST PASS or TEST FAIL
```
