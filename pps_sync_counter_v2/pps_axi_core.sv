`timescale 1ns/1ns
`default_nettype none

module pps_axi_core #(
        parameter [31:0] TIMEOUT_CYCLES = 32'd150_000_000
)
(
        input wire s_axi_aclk,
        input wire s_axi_aresetn,

        output logic s_axi_awready,
        input wire s_axi_awvalid,
        input wire [3:0] s_axi_awaddr,
        input wire [2:0] s_axi_awprot,
        output logic s_axi_wready,
        input wire s_axi_wvalid,
        input wire [31:0] s_axi_wdata,
        input wire [3:0]s_axi_wstrb,
        input wire s_axi_bready,
        output logic s_axi_bvalid,
        output logic [1:0] s_axi_bresp,
        output logic s_axi_arready,
        input wire s_axi_arvalid,
        input wire [3:0] s_axi_araddr,
        input wire [2:0] s_axi_arprot,
        input wire s_axi_rready,
        output logic s_axi_rvalid,
        output logic [31:0] s_axi_rdata,
        output logic [1:0] s_axi_rresp,

        // raw pps signal
        input wire pps_raw,
        // raw outputs to drive like something on board
        // optional
        output logic pps_missing,
        output logic pps_edge
        
    );
    pps_regs_pkg::pps_regs__in_t hwif_in;
    pps_regs_pkg::pps_regs__out_t hwif_out;
    
    wire core_rst;
    wire enable;
    wire [31:0] counter;
    wire [31:0] interval;
    // assign the reset value to be the or of axi full system 
    // reset and software reset
    assign core_rst = ~s_axi_aresetn | hwif_out.control.rst.value;
    // assign the enable wire
    assign enable = hwif_out.control.enable.value;
    // assign the axi status fields
    assign hwif_in.interval.interval.next[31:0] = interval;
    assign hwif_in.counter.counter.next[31:0] = counter;
    assign hwif_in.pps_missing.pps_missing.next = pps_missing;

    pps_sync_counter #(
        .TIMEOUT_CYCLES(TIMEOUT_CYCLES)
    ) u_counter (
        .clk         (s_axi_aclk),
        .rst         (core_rst),
        .pps_raw     (pps_raw),
        .enable      (enable),
        .pps_edge    (pps_edge),
        .counter     (counter),
        .interval    (interval),
        .pps_missing (pps_missing)
    );

    pps_regs u_regs (
        .clk            (s_axi_aclk),
        .rst_n          (s_axi_aresetn),
        .s_axil_awready (s_axi_awready),
        .s_axil_awvalid (s_axi_awvalid),
        .s_axil_awaddr  (s_axi_awaddr),
        .s_axil_awprot  (s_axi_awprot),
        .s_axil_wready  (s_axi_wready),
        .s_axil_wvalid  (s_axi_wvalid),
        .s_axil_wdata   (s_axi_wdata),
        .s_axil_wstrb   (s_axi_wstrb),
        .s_axil_bready  (s_axi_bready),
        .s_axil_bvalid  (s_axi_bvalid),
        .s_axil_bresp   (s_axi_bresp),
        .s_axil_arready (s_axi_arready),
        .s_axil_arvalid (s_axi_arvalid),
        .s_axil_araddr  (s_axi_araddr),
        .s_axil_arprot  (s_axi_arprot),
        .s_axil_rready  (s_axi_rready),
        .s_axil_rvalid  (s_axi_rvalid),
        .s_axil_rdata   (s_axi_rdata),
        .s_axil_rresp   (s_axi_rresp),
        .hwif_in        (hwif_in),
        .hwif_out       (hwif_out)
    );
    
`default_nettype wire
endmodule
    
