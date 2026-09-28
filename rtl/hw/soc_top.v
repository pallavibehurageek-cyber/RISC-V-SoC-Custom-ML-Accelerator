`timescale 1ns / 1ps

// =========================================================================
// Module: soc_top
// Theory: The top-level wrapper that instantiates and connects all IPs.
// =========================================================================
module soc_top (
    input wire clk,
    input wire rstn,
    output wire uart_tx_out
);

    // =========================================================================
    // 1. CPU Master Wires
    // =========================================================================
    wire [31:0] cpu_awaddr;  wire cpu_awvalid; wire cpu_awready;
    wire [31:0] cpu_wdata;   wire [3:0] cpu_wstrb; wire cpu_wvalid; wire cpu_wready;
    wire [1:0]  cpu_bresp;   wire cpu_bvalid;  wire cpu_bready;
    wire [31:0] cpu_araddr;  wire cpu_arvalid; wire cpu_arready;
    wire [31:0] cpu_rdata;   wire [1:0] cpu_rresp; wire cpu_rvalid; wire cpu_rready;

    // =========================================================================
    // 2. BRAM Slave Wires (Memory)
    // =========================================================================
    wire [31:0] bram_awaddr; wire bram_awvalid; wire bram_awready;
    wire [31:0] bram_wdata;  wire [3:0] bram_wstrb; wire bram_wvalid; wire bram_wready;
    wire [1:0]  bram_bresp;  wire bram_bvalid;  wire bram_bready;
    wire [31:0] bram_araddr; wire bram_arvalid; wire bram_arready;
    wire [31:0] bram_rdata;  wire [1:0] bram_rresp; wire bram_rvalid; wire bram_rready;

    // =========================================================================
    // 3. Bridge Slave Wires (Peripherals/Accelerator)
    // =========================================================================
    wire [31:0] br_awaddr;   wire br_awvalid;   wire br_awready;
    wire [31:0] br_wdata;    wire [3:0] br_wstrb;   wire br_wvalid;   wire br_wready;
    wire [1:0]  br_bresp;    wire br_bvalid;    wire br_bready;
    wire [31:0] br_araddr;   wire br_arvalid;   wire br_arready;
    wire [31:0] br_rdata;    wire [1:0] br_rresp;   wire br_rvalid;   wire br_rready;

    // =========================================================================
    // 4. THE TRAFFIC COP (Address Decoder & Interconnect)
    // =========================================================================
    
    // Step A: Look at the top 4 bits (the "Zip Code") of the address
    // 0x0... goes to BRAM. 0x4... or 0x5... goes to Bridge.
    wire aw_is_bram   = (cpu_awaddr[31:28] == 4'h0);
    wire aw_is_bridge = (cpu_awaddr[31:28] == 4'h4) || (cpu_awaddr[31:28] == 4'h5);
    
    wire ar_is_bram   = (cpu_araddr[31:28] == 4'h0);
    wire ar_is_bridge = (cpu_araddr[31:28] == 4'h4) || (cpu_araddr[31:28] == 4'h5);

    // Step B: Route CPU Outputs to Slaves based on Zip Code
    // Write Channels (AW & W)
    assign bram_awaddr  = cpu_awaddr;
    assign bram_awvalid = cpu_awvalid & aw_is_bram; // Only VALID to BRAM if address matches
    assign br_awaddr    = cpu_awaddr;
    assign br_awvalid   = cpu_awvalid & aw_is_bridge;
    
    assign bram_wdata   = cpu_wdata;
    assign bram_wstrb   = cpu_wstrb;
    assign bram_wvalid  = cpu_wvalid & aw_is_bram;
    assign br_wdata     = cpu_wdata;
    assign br_wstrb     = cpu_wstrb;
    assign br_wvalid    = cpu_wvalid & aw_is_bridge;

    // Read Channel (AR)
    assign bram_araddr  = cpu_araddr;
    assign bram_arvalid = cpu_arvalid & ar_is_bram;
    assign br_araddr    = cpu_araddr;
    assign br_arvalid   = cpu_arvalid & ar_is_bridge;

    // Step C: Route Slave Outputs back to CPU (The MUXes)
    // If BRAM is talking, connect BRAM. If Bridge is talking, connect Bridge.
    assign cpu_awready = aw_is_bram ? bram_awready : (aw_is_bridge ? br_awready : 1'b1);
    assign cpu_wready  = aw_is_bram ? bram_wready  : (aw_is_bridge ? br_wready  : 1'b1);
    
    // For Responses, we look at who is sending a VALID response
    assign cpu_bvalid  = bram_bvalid | br_bvalid;
    assign cpu_bresp   = bram_bvalid ? bram_bresp : br_bresp;
    assign bram_bready = cpu_bready;
    assign br_bready   = cpu_bready;

    assign cpu_arready = ar_is_bram ? bram_arready : (ar_is_bridge ? br_arready : 1'b1);
    
    assign cpu_rvalid  = bram_rvalid | br_rvalid;
    assign cpu_rdata   = bram_rvalid ? bram_rdata : br_rdata;
    assign cpu_rresp   = bram_rvalid ? bram_rresp : br_rresp;
    assign bram_rready = cpu_rready;
    assign br_rready   = cpu_rready;


    // =========================================================================
    // 5. Instantiations
    // =========================================================================
    
// The CPU
    picorv32_axi #(
        .ENABLE_COUNTERS(1), 
        .PROGADDR_RESET(32'h00000000) // FIXED: Correct parameter name for boot address
    ) cpu (
        .clk(clk), .resetn(rstn),
        .mem_axi_awaddr(cpu_awaddr), .mem_axi_awvalid(cpu_awvalid), .mem_axi_awready(cpu_awready),
        .mem_axi_wdata(cpu_wdata),   .mem_axi_wstrb(cpu_wstrb),     .mem_axi_wvalid(cpu_wvalid), .mem_axi_wready(cpu_wready),
        
        // FIXED: Removed .mem_axi_bresp(cpu_bresp) because PicoRV32 drops it to save space
        .mem_axi_bvalid(cpu_bvalid),   .mem_axi_bready(cpu_bready), 
        
        .mem_axi_araddr(cpu_araddr), .mem_axi_arvalid(cpu_arvalid), .mem_axi_arready(cpu_arready),
        
        // FIXED: Removed .mem_axi_rresp(cpu_rresp) for the same reason
        .mem_axi_rdata(cpu_rdata),     .mem_axi_rvalid(cpu_rvalid), .mem_axi_rready(cpu_rready) 
    );

    // The BRAM (Memory)
    axi_bram #(.RAM_SIZE(8192), .INIT_FILE("firmware.hex")) mem (
        .s_axi_aclk(clk), .s_axi_aresetn(rstn),
        .s_axi_awaddr(bram_awaddr), .s_axi_awvalid(bram_awvalid), .s_axi_awready(bram_awready),
        .s_axi_wdata(bram_wdata),   .s_axi_wstrb(bram_wstrb),     .s_axi_wvalid(bram_wvalid), .s_axi_wready(bram_wready),
        .s_axi_bresp(bram_bresp),   .s_axi_bvalid(bram_bvalid),   .s_axi_bready(bram_bready),
        .s_axi_araddr(bram_araddr), .s_axi_arvalid(bram_arvalid), .s_axi_arready(bram_arready),
        .s_axi_rdata(bram_rdata),   .s_axi_rresp(bram_rresp),     .s_axi_rvalid(bram_rvalid), .s_axi_rready(bram_rready)
    );

    // The Bridge & Accelerator (Tied together internally)
    wire [31:0] apb_paddr, apb_pwdata, apb_prdata;
    wire apb_psel, apb_penable, apb_pwrite, apb_pready;

    axi2apb_bridge bridge (
        .s_axi_aclk(clk), .s_axi_aresetn(rstn),
        .s_axi_awaddr(br_awaddr), .s_axi_awvalid(br_awvalid), .s_axi_awready(br_awready),
        .s_axi_wdata(br_wdata),   .s_axi_wvalid(br_wvalid),   .s_axi_wready(br_wready),
        .s_axi_bresp(br_bresp),   .s_axi_bvalid(br_bvalid),   .s_axi_bready(br_bready),
        .s_axi_araddr(br_araddr), .s_axi_arvalid(br_arvalid), .s_axi_arready(br_arready),
        .s_axi_rdata(br_rdata),   .s_axi_rresp(br_rresp),     .s_axi_rvalid(br_rvalid), .s_axi_rready(br_rready),
        
        .m_apb_paddr(apb_paddr), .m_apb_psel(apb_psel), .m_apb_penable(apb_penable),
        .m_apb_pwrite(apb_pwrite), .m_apb_pwdata(apb_pwdata), .m_apb_pready(apb_pready), .m_apb_prdata(apb_prdata)
    );

    // -----------------------------------------------------------
    // NEW: APB Address Decoder & Multiplexer
    // -----------------------------------------------------------
    wire sel_ml_accel = apb_psel & (apb_paddr[11:8] == 4'h0);
    wire sel_uart     = apb_psel & (apb_paddr[11:8] == 4'h1);
    
    wire [31:0] prdata_ml_accel;
    wire [31:0] prdata_uart;
    
    wire pready_ml_accel;
    wire pready_uart;
    
    // Mux both the Data AND the Ready signals back to the CPU!
    assign apb_prdata = sel_uart ? prdata_uart : prdata_ml_accel;
    assign apb_pready = sel_uart ? pready_uart : pready_ml_accel;

    // -----------------------------------------------------------
    // Peripheral Instantiations
    // -----------------------------------------------------------
    
    // The ML Accelerator
    ml_accelerator ml_accel_inst (
        .pclk    (clk), 
        .presetn (rstn),
        .paddr   (apb_paddr[7:0]), 
        .psel    (sel_ml_accel),  
        .penable (apb_penable),
        .pwrite  (apb_pwrite), 
        .pwdata  (apb_pwdata), 
        .prdata  (prdata_ml_accel), 
        .pready  (pready_ml_accel) // <--- PLUGGED BACK IN!
    );

    // The UART
    apb_uart apb_uart_inst (
        .pclk    (clk),
        .presetn (rstn),
        .paddr   (apb_paddr[11:0]),
        .psel    (sel_uart),
        .penable (apb_penable),
        .pwrite  (apb_pwrite),
        .pwdata  (apb_pwdata),
        .prdata  (prdata_uart),
        .pready  (pready_uart),   // <--- PLUGGED BACK IN!
        .tx_line (uart_tx_out) 
    );
endmodule
