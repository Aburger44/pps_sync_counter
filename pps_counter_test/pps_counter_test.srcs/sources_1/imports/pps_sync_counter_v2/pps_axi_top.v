`timescale 1ns/1ns

module pps_axi_top #(
    // cycles without a PPS edge before pps_missing goes high
    // default: 1.5 s at a 100 MHz clk, so one missed PPS pulse is flagged
    parameter [31:0] TIMEOUT_CYCLES = 32'd150_000_000
)
(
        input wire s_axi_aclk,
        input wire s_axi_aresetn,
        output wire s_axi_awready,
        input wire s_axi_awvalid,
        input wire [3:0] s_axi_awaddr,
        input wire [2:0] s_axi_awprot,
        output wire s_axi_wready,
        input wire s_axi_wvalid,
        input wire [31:0] s_axi_wdata,
        input wire [3:0]s_axi_wstrb,
        input wire s_axi_bready,
        output wire s_axi_bvalid,
        output wire [1:0] s_axi_bresp,
        output wire s_axi_arready,
        input wire s_axi_arvalid,
        input wire [3:0] s_axi_araddr,
        input wire [2:0] s_axi_arprot,
        input wire s_axi_rready,
        output wire s_axi_rvalid,
        output wire [31:0] s_axi_rdata,
        output wire [1:0] s_axi_rresp,
        input wire pps_raw,
        output wire pps_missing,
        output wire pps_edge
);

    pps_axi_core #(
        .TIMEOUT_CYCLES(TIMEOUT_CYCLES)
    ) u_core (
        .s_axi_aclk    (s_axi_aclk),
        .s_axi_aresetn (s_axi_aresetn),
        .s_axi_awvalid (s_axi_awvalid),
        .s_axi_awready (s_axi_awready),
        .s_axi_awaddr  (s_axi_awaddr),
        .s_axi_awprot  (s_axi_awprot),
        .s_axi_wvalid  (s_axi_wvalid),
        .s_axi_wready  (s_axi_wready),
        .s_axi_wdata   (s_axi_wdata),
        .s_axi_wstrb   (s_axi_wstrb),
        .s_axi_bvalid  (s_axi_bvalid),
        .s_axi_bready  (s_axi_bready),
        .s_axi_bresp   (s_axi_bresp),
        .s_axi_arvalid (s_axi_arvalid),
        .s_axi_arready (s_axi_arready),
        .s_axi_araddr  (s_axi_araddr),
        .s_axi_arprot  (s_axi_arprot),
        .s_axi_rvalid  (s_axi_rvalid),
        .s_axi_rready  (s_axi_rready),
        .s_axi_rdata   (s_axi_rdata),
        .s_axi_rresp   (s_axi_rresp),
        .pps_raw       (pps_raw),
        .pps_edge      (pps_edge),
        .pps_missing   (pps_missing)
    );

endmodule
