`timescale 1ns / 1ps

module axi2apb_bridge #(
    parameter C_S_AXI_DATA_WIDTH = 32,
    parameter C_S_AXI_ADDR_WIDTH = 32
)(
    // AXI4-Lite Slave Interface
    input wire  s_axi_aclk,
    input wire  s_axi_aresetn,
    
    input wire [C_S_AXI_ADDR_WIDTH-1:0] s_axi_awaddr,
    input wire  s_axi_awvalid,
    output reg  s_axi_awready,
    
    input wire [C_S_AXI_DATA_WIDTH-1:0] s_axi_wdata,
    input wire  s_axi_wvalid,
    output reg  s_axi_wready,
    
    output reg [1:0] s_axi_bresp,
    output reg  s_axi_bvalid,
    input wire  s_axi_bready,
    
    input wire [C_S_AXI_ADDR_WIDTH-1:0] s_axi_araddr,
    input wire  s_axi_arvalid,
    output reg  s_axi_arready,
    
    output reg [C_S_AXI_DATA_WIDTH-1:0] s_axi_rdata,
    output reg [1:0] s_axi_rresp,
    output reg  s_axi_rvalid,
    input wire  s_axi_rready,

    // APB Master Interface
    output reg [31:0] m_apb_paddr,
    output reg        m_apb_psel,
    output reg        m_apb_penable,
    output reg        m_apb_pwrite,
    output reg [31:0] m_apb_pwdata,
    input  wire       m_apb_pready,
    input  wire [31:0] m_apb_prdata
);

    localparam [1:0] IDLE   = 2'b00;
    localparam [1:0] SETUP  = 2'b01;
    localparam [1:0] ACCESS = 2'b10;

    reg [1:0] state, next_state;
    reg is_write_trans; // Remembers if current transaction is a write

    // 1. State Register
    always @(posedge s_axi_aclk) begin
        if (~s_axi_aresetn) state <= IDLE;
        else state <= next_state;
    end

    // 2. Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (s_axi_arvalid) next_state = SETUP;
                else if (s_axi_awvalid && s_axi_wvalid) next_state = SETUP;
            end
            SETUP: next_state = ACCESS;
            ACCESS: if (m_apb_pready) next_state = IDLE;
        endcase
    end

    // 3. APB Bus Control (FIXED: Driven directly by state, no latches)
    always @(posedge s_axi_aclk) begin
        if (~s_axi_aresetn) begin
            m_apb_psel    <= 0;
            m_apb_penable <= 0;
            m_apb_pwrite  <= 0;
            m_apb_paddr   <= 0;
            m_apb_pwdata  <= 0;
            is_write_trans<= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (s_axi_arvalid) begin
                        // Read Setup
                        m_apb_paddr    <= s_axi_araddr;
                        m_apb_pwrite   <= 0;
                        m_apb_psel     <= 1;
                        m_apb_penable  <= 0;
                        is_write_trans <= 0;
                    end else if (s_axi_awvalid && s_axi_wvalid) begin
                        // Write Setup
                        m_apb_paddr    <= s_axi_awaddr;
                        m_apb_pwdata   <= s_axi_wdata;
                        m_apb_pwrite   <= 1;
                        m_apb_psel     <= 1;
                        m_apb_penable  <= 0;
                        is_write_trans <= 1;
                    end else begin
                        m_apb_psel     <= 0;
                        m_apb_penable  <= 0;
                    end
                end
                
                SETUP: begin
                    m_apb_penable <= 1; // Trigger the access phase
                end
                
                ACCESS: begin
                    if (m_apb_pready) begin
                        m_apb_psel    <= 0;
                        m_apb_penable <= 0;
                    end
                end
            endcase
        end
    end

    // 4. AXI Handshake & Response
    always @(*) begin
        s_axi_awready = (state == IDLE) && (~s_axi_arvalid) && (s_axi_awvalid && s_axi_wvalid);
        s_axi_wready  = (state == IDLE) && (~s_axi_arvalid) && (s_axi_awvalid && s_axi_wvalid);
        s_axi_arready = (state == IDLE) && (s_axi_arvalid);
    end

    always @(posedge s_axi_aclk) begin
        if (~s_axi_aresetn) begin
            s_axi_bvalid <= 0;
            s_axi_rvalid <= 0;
        end else begin
            if (s_axi_bvalid && s_axi_bready) s_axi_bvalid <= 0;
            if (s_axi_rvalid && s_axi_rready) s_axi_rvalid <= 0;

            if (state == ACCESS && m_apb_pready) begin
                if (is_write_trans) begin
                    s_axi_bvalid <= 1;
                    s_axi_bresp  <= 2'b00;
                end else begin
                    s_axi_rvalid <= 1;
                    s_axi_rdata  <= m_apb_prdata;
                    s_axi_rresp  <= 2'b00;
                end
            end
        end
    end

endmodule
