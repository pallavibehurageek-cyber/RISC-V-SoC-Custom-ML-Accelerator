`timescale 1ns / 1ps

// =========================================================================
// Module: uart_tx
// Theory: Serializes an 8-bit character into a 1-wire UART protocol.
// =========================================================================
module uart_tx #(
    parameter CLK_FREQ = 100_000_000,
    parameter BAUD_RATE = 115200
)(
    input  wire       clk,
    input  wire       rstn,
    input  wire       tx_en,    // CPU pulses this to 1 to send a character
    input  wire [7:0] tx_data,  // The character to send (e.g., 8'h41 for 'A')
    
    output reg        tx_busy,  // 1 = currently transmitting, CPU must wait!
    output reg        tx_line   // The physical wire going to the outside world
);

    // Calculate how many clock cycles each bit should last
    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE; // roughly 868

    localparam STATE_IDLE  = 2'd0;
    localparam STATE_START = 2'd1;
    localparam STATE_DATA  = 2'd2;
    localparam STATE_STOP  = 2'd3;

    reg [1:0]  state;
    reg [15:0] clk_count;
    reg [2:0]  bit_index;
    reg [7:0]  data_reg;

    always @(posedge clk) begin
        if (~rstn) begin
            state     <= STATE_IDLE;
            tx_line   <= 1'b1; // UART idle state is ALWAYS HIGH
            tx_busy   <= 1'b0;
            clk_count <= 0;
            bit_index <= 0;
            data_reg  <= 0;
        end else begin
            case (state)
                // --- WAIT FOR CPU ---
                STATE_IDLE: begin
                    tx_line <= 1'b1;
                    clk_count <= 0;
                    bit_index <= 0;
                    if (tx_en) begin
                        tx_busy  <= 1'b1;
                        data_reg <= tx_data; // Lock in the character
                        state    <= STATE_START;
                    end else begin
                        tx_busy  <= 1'b0;
                    end
                end

                // --- SEND START BIT (LOW) ---
                STATE_START: begin
                    tx_line <= 1'b0; 
                    if (clk_count == CLKS_PER_BIT - 1) begin
                        clk_count <= 0;
                        state     <= STATE_DATA;
                    end else begin
                        clk_count <= clk_count + 1;
                    end
                end

                // --- SEND 8 DATA BITS (LSB FIRST) ---
                STATE_DATA: begin
                    tx_line <= data_reg[bit_index]; 
                    if (clk_count == CLKS_PER_BIT - 1) begin
                        clk_count <= 0;
                        if (bit_index == 7) begin
                            state <= STATE_STOP; // Finished all 8 bits
                        end else begin
                            bit_index <= bit_index + 1;
                        end
                    end else begin
                        clk_count <= clk_count + 1;
                    end
                end

                // --- SEND STOP BIT (HIGH) ---
                STATE_STOP: begin
                    tx_line <= 1'b1; 
                    if (clk_count == CLKS_PER_BIT - 1) begin
                        clk_count <= 0;
                        state     <= STATE_IDLE; // Go back and wait for next char
                    end else begin
                        clk_count <= clk_count + 1;
                    end
                end
            endcase
        end
    end

endmodule
