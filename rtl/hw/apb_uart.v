`timescale 1ns / 1ps

// =========================================================================
// Module: apb_uart
// Theory: Wraps the UART TX core in an APB interface for the CPU to control.
// =========================================================================
module apb_uart (
    input  wire        pclk,
    input  wire        presetn,
    input  wire [11:0] paddr,   // 12-bit address
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [31:0] pwdata,
    output reg  [31:0] prdata,
    output wire        pready,

    // The physical wire going to the outside world
    output wire        tx_line  
);

    assign pready = 1'b1;

    reg        tx_en;
    reg  [7:0] tx_data;
    wire       tx_busy;

    // Instantiate the raw UART core we just built
    uart_tx #(
        .CLK_FREQ(100_000_000),
        .BAUD_RATE(115200)
    ) tx_core (
        .clk(pclk),
        .rstn(presetn),
        .tx_en(tx_en),
        .tx_data(tx_data),
        .tx_busy(tx_busy),
        .tx_line(tx_line)
    );

    // -------------------------------------------------------------------------
    // APB Write Logic (CPU sending a character)
    // -------------------------------------------------------------------------
    always @(posedge pclk) begin
        if (~presetn) begin
            tx_en   <= 1'b0;
            tx_data <= 8'd0;
        end else begin
            // Default: don't send anything
            tx_en <= 1'b0;

            // Address 0x100: Trigger Transmission
            if (psel && penable && pwrite && (paddr == 12'h100)) begin
                tx_data <= pwdata[7:0]; // Grab the character
                tx_en   <= 1'b1;        // Pulse the enable pin for 1 clock cycle
            end
        end
    end

    // -------------------------------------------------------------------------
    // APB Read Logic (CPU checking if the wire is busy)
    // -------------------------------------------------------------------------
    always @(*) begin
        prdata = 32'd0;
        if (psel && !pwrite) begin
            // Address 0x104: Read Status
            if (paddr == 12'h104) begin
                prdata = {31'd0, tx_busy}; // Put the busy flag in the lowest bit
            end
        end
    end

endmodule
