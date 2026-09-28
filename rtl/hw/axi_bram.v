`timescale 1ns / 1ps

// =========================================================================
// Module: axi_bram
// Theory: Acts as the primary memory (Instruction + Data) for the SoC.
// Why: The CPU needs a place to fetch code and store variables.
// =========================================================================
module axi_bram #(
    parameter RAM_SIZE = 8192, // 8KB BRAM as specified in the project plan
    parameter INIT_FILE = ""   // File to load C program from
)(
    // AXI4-Lite Slave Interface
    input wire  s_axi_aclk,
    input wire  s_axi_aresetn,
    
    // Write Channels
    input wire [31:0] s_axi_awaddr,
    input wire  s_axi_awvalid,
    output reg  s_axi_awready,
    input wire [31:0] s_axi_wdata,
    input wire [3:0]  s_axi_wstrb,
    input wire  s_axi_wvalid,
    output reg  s_axi_wready,
    output reg [1:0]  s_axi_bresp,
    output reg  s_axi_bvalid,
    input wire  s_axi_bready,
    
    // Read Channels
    input wire [31:0] s_axi_araddr,
    input wire  s_axi_arvalid,
    output reg  s_axi_arready,
    output reg [31:0] s_axi_rdata,
    output reg [1:0]  s_axi_rresp,
    output reg  s_axi_rvalid,
    input wire  s_axi_rready
);

    // -------------------------------------------------------------------------
    // 1. The Actual Memory Array
    // -------------------------------------------------------------------------
    // 8192 bytes / 4 bytes per word = 2048 words.
    reg [31:0] ram [0:(RAM_SIZE/4)-1];

    // Initialization block: Loads our compiled software into the hardware memory
    initial begin
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, ram);
        end
    end

    // -------------------------------------------------------------------------
    // 2. AXI Write Logic
    // -------------------------------------------------------------------------
    wire write_en = s_axi_awvalid && s_axi_wvalid && s_axi_awready && s_axi_wready;
    
    // Calculate the actual array index from the byte address (Address / 4)
    wire [29:0] word_addr_wr = s_axi_awaddr[31:2]; 

    always @(posedge s_axi_aclk) begin
        if (~s_axi_aresetn) begin
            s_axi_awready <= 0;
            s_axi_wready  <= 0;
            s_axi_bvalid  <= 0;
            s_axi_bresp   <= 2'b00;
        end else begin
            // Handshake logic
            s_axi_awready <= ~s_axi_awready && s_axi_awvalid && s_axi_wvalid;
            s_axi_wready  <= ~s_axi_wready  && s_axi_awvalid && s_axi_wvalid;

            // Write into the memory array using the Strobe (WSTRB)
            if (write_en) begin
                if (s_axi_wstrb[0]) ram[word_addr_wr][7:0]   <= s_axi_wdata[7:0];
                if (s_axi_wstrb[1]) ram[word_addr_wr][15:8]  <= s_axi_wdata[15:8];
                if (s_axi_wstrb[2]) ram[word_addr_wr][23:16] <= s_axi_wdata[23:16];
                if (s_axi_wstrb[3]) ram[word_addr_wr][31:24] <= s_axi_wdata[31:24];
            end

            // Response logic
            if (write_en && ~s_axi_bvalid) begin
                s_axi_bvalid <= 1;
            end else if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 0;
            end
        end
    end

    // -------------------------------------------------------------------------
    // 3. AXI Read Logic
    // -------------------------------------------------------------------------
    wire read_en = s_axi_arvalid && s_axi_arready;
    wire [29:0] word_addr_rd = s_axi_araddr[31:2];

    always @(posedge s_axi_aclk) begin
        if (~s_axi_aresetn) begin
            s_axi_arready <= 0;
            s_axi_rvalid  <= 0;
            s_axi_rresp   <= 2'b00;
            s_axi_rdata   <= 0;
        end else begin
            // Handshake logic
            s_axi_arready <= ~s_axi_arready && s_axi_arvalid;

            // Read from memory array
            if (read_en && ~s_axi_rvalid) begin
                s_axi_rdata  <= ram[word_addr_rd]; // Fetch data from RAM
                s_axi_rvalid <= 1;
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 0;
            end
        end
    end

endmodule
