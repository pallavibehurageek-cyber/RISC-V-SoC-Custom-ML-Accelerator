`timescale 1ns / 1ps

module axi4_lite_slave #(
    parameter C_S_AXI_DATA_WIDTH = 32,
    parameter C_S_AXI_ADDR_WIDTH = 4  // 4 bits covers 16 bytes (4 registers)
)(
    // 1. Global Signals
    input wire  S_AXI_ACLK,
    input wire  S_AXI_ARESETN,

    // 2. Write Address Channel (AW)
    input wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR,
    input wire  S_AXI_AWVALID,
    output reg  S_AXI_AWREADY,

    // 3. Write Data Channel (W)
    input wire [C_S_AXI_DATA_WIDTH-1:0] S_AXI_WDATA,
    input wire [3:0] S_AXI_WSTRB, // Byte strobes (which bytes to write)
    input wire  S_AXI_WVALID,
    output reg  S_AXI_WREADY,

    // 4. Write Response Channel (B)
    output reg [1:0] S_AXI_BRESP, // 00 = OKAY
    output reg  S_AXI_BVALID,
    input wire  S_AXI_BREADY,

    // 5. Read Address Channel (AR)
    input wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR,
    input wire  S_AXI_ARVALID,
    output reg  S_AXI_ARREADY,

    // 6. Read Data Channel (R)
    output reg [C_S_AXI_DATA_WIDTH-1:0] S_AXI_RDATA,
    output reg [1:0] S_AXI_RRESP, // 00 = OKAY
    output reg  S_AXI_RVALID,
    input wire  S_AXI_RREADY
);

    // Internal Registers (Same as your APB Slave)
    // 0x0: CTRL
    // 0x4: DATA
    // 0x8: STATUS
    reg [31:0] reg_ctrl;
    reg [31:0] reg_data;
    reg [31:0] reg_status;

    // Internal Signals
    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_awaddr;
    reg axi_awready;
    reg axi_wready;
    reg axi_bvalid;
    reg axi_arready;
    reg [31:0] axi_rdata;
    reg axi_rvalid;

    // Example hardcoded ID for readback
    localparam [31:0] ID_VAL = 32'hDEADBEEF;

    // -------------------------------------------------------------------------
    // WRITE CHANNEL LOGIC (AW, W, B)
    // -------------------------------------------------------------------------
    
    // 1. AWREADY and WREADY Generation
    // We only accept an address when we are ready. In this simple design,
    // we assert READY when we see VALID, effectively completing the handshake in 1 cycle.
    always @(posedge S_AXI_ACLK) begin
        if (S_AXI_ARESETN == 1'b0) begin
            S_AXI_AWREADY <= 1'b0;
            S_AXI_WREADY  <= 1'b0;
        end 
        else begin
            // Handshake for Address
            if (~S_AXI_AWREADY && S_AXI_AWVALID && S_AXI_WVALID) begin
                S_AXI_AWREADY <= 1'b1;
            end else begin
                S_AXI_AWREADY <= 1'b0;
            end

            // Handshake for Data
            if (~S_AXI_WREADY && S_AXI_WVALID && S_AXI_AWVALID) begin
                S_AXI_WREADY <= 1'b1;
            end else begin
                S_AXI_WREADY <= 1'b0;
            end
        end
    end

    // 2. Actual Register Write
    // Happens when both AWVALID and WVALID are true (and we are ready)
    always @(posedge S_AXI_ACLK) begin
        if (S_AXI_ARESETN == 1'b0) begin
            reg_ctrl   <= 0;
            reg_data   <= 0;
            reg_status <= 0; // In real HW, Status is usually written by the engine, not bus
        end 
        else begin
            if (S_AXI_WREADY && S_AXI_WVALID && S_AXI_AWREADY && S_AXI_AWVALID) begin
                // Address Decoding (Simplified for 4 registers)
                // Note: AXI addresses are byte-based. Bit 0 and 1 are usually 0 for 32-bit alignment.
                // We look at bits [3:2] to choose the register.
                case (S_AXI_AWADDR[3:2])
                    2'b00: reg_ctrl <= S_AXI_WDATA;   // Offset 0x0
                    2'b01: reg_data <= S_AXI_WDATA;   // Offset 0x4
                    2'b10: reg_status <= S_AXI_WDATA; // Offset 0x8 (Debug write)
                    // 2'b11 is ID (Read-only)
                endcase
            end
        end
    end

    // 3. Write Response (B Channel)
    // After we accept the write, we must send a response (BVALID).
    always @(posedge S_AXI_ACLK) begin
        if (S_AXI_ARESETN == 1'b0) begin
            S_AXI_BVALID <= 0;
            S_AXI_BRESP  <= 2'b00; // OKAY
        end 
        else begin
            // If we just finished a write handshake...
            if (S_AXI_AWREADY && S_AXI_AWVALID && ~S_AXI_BVALID && S_AXI_WREADY && S_AXI_WVALID) begin
                S_AXI_BVALID <= 1'b1;
                S_AXI_BRESP  <= 2'b00; 
            end
            // Once Master accepts response (BREADY), clear BVALID
            else if (S_AXI_BVALID && S_AXI_BREADY) begin
                S_AXI_BVALID <= 1'b0; 
            end
        end
    end


    // -------------------------------------------------------------------------
    // READ CHANNEL LOGIC (AR, R)
    // -------------------------------------------------------------------------
    // Internal register to store address during read phase
    reg [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR_reg;
    
    // 1. ARREADY Generation
    always @(posedge S_AXI_ACLK) begin
        if (S_AXI_ARESETN == 1'b0) begin
            S_AXI_ARREADY <= 1'b0;
            S_AXI_ARADDR_reg <= 0;
        end 
        else begin
            if (~S_AXI_ARREADY && S_AXI_ARVALID) begin
                S_AXI_ARREADY <= 1'b1;
                // Latch the address
                S_AXI_ARADDR_reg <= S_AXI_ARADDR;
            end else begin
                S_AXI_ARREADY <= 1'b0;
            end
        end
    end
    

    // 2. RVALID and RDATA Generation
    // When we accept an address (ARREADY=1), we output data in the next cycle.
    always @(posedge S_AXI_ACLK) begin
        if (S_AXI_ARESETN == 1'b0) begin
            S_AXI_RVALID <= 0;
            S_AXI_RRESP  <= 0;
            S_AXI_RDATA  <= 0;
        end 
        else begin
            // If we just accepted a read address...
            if (S_AXI_ARREADY && S_AXI_ARVALID && ~S_AXI_RVALID) begin
                S_AXI_RVALID <= 1'b1;
                S_AXI_RRESP  <= 2'b00; // OKAY

                // Decode Address and Select Data
                case (S_AXI_ARADDR[3:2])
                    2'b00: S_AXI_RDATA <= reg_ctrl;
                    2'b01: S_AXI_RDATA <= reg_data;
                    2'b10: S_AXI_RDATA <= reg_status;
                    2'b11: S_AXI_RDATA <= ID_VAL;
                    default: S_AXI_RDATA <= 32'h0;
                endcase
            end
            // Once Master accepts data (RREADY), clear RVALID
            else if (S_AXI_RVALID && S_AXI_RREADY) begin
                S_AXI_RVALID <= 1'b0;
            end
        end
    end

endmodule
