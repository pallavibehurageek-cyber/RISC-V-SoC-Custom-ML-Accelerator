`timescale 1ns / 1ps

// =========================================================================
// Module: ml_accelerator (The Final Unified Peripheral)
// Theory: Combines the APB Slave interface and the Matrix FSM into one block.
// =========================================================================
module ml_accelerator (
    input  wire        pclk,
    input  wire        presetn,
    input  wire [7:0]  paddr,   // 8-bit address (covers 0x00 to 0xFF)
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [31:0] pwdata,
    output reg  [31:0] prdata,
    output wire        pready
);

    // -------------------------------------------------------------------------
    // 1. The Memory Registers
    // -------------------------------------------------------------------------
    reg [31:0] reg_ctrl;
    reg [31:0] reg_status;

    reg [7:0]  matrix_a [0:15];
    reg [7:0]  matrix_b [0:15];
    reg [31:0] matrix_c [0:15];

    assign pready = 1'b1; // We are always ready for APB traffic

    // -------------------------------------------------------------------------
    // 2. APB Write Logic (CPU uploading data to hardware)
    // -------------------------------------------------------------------------
    always @(posedge pclk) begin
        if (~presetn) begin
            reg_ctrl <= 0;
        end else begin
            // Auto-clear CTRL so it acts like a push-button, not a toggle switch
            if (reg_ctrl == 32'd1) reg_ctrl <= 0;

            if (psel && penable && pwrite) begin
                if (paddr == 8'h00) reg_ctrl <= pwdata;
                // Subtract base address and divide by 4 (>> 2) to get array index 0-15
                else if (paddr >= 8'h40 && paddr <= 8'h7C) matrix_a[(paddr - 8'h40) >> 2] <= pwdata[7:0];
                else if (paddr >= 8'h80 && paddr <= 8'hBC) matrix_b[(paddr - 8'h80) >> 2] <= pwdata[7:0];
            end
        end
    end

    // -------------------------------------------------------------------------
    // 3. APB Read Logic (CPU reading data from hardware)
    // -------------------------------------------------------------------------
    always @(*) begin
        prdata = 32'd0;
        if (psel && !pwrite) begin
            if (paddr == 8'h00) prdata = reg_ctrl;
            else if (paddr == 8'h04) prdata = reg_status;
            else if (paddr >= 8'h40 && paddr <= 8'h7C) prdata = {24'd0, matrix_a[(paddr - 8'h40) >> 2]};
            else if (paddr >= 8'h80 && paddr <= 8'hBC) prdata = {24'd0, matrix_b[(paddr - 8'h80) >> 2]};
            else if (paddr >= 8'hC0 && paddr <= 8'hFC) prdata = matrix_c[(paddr - 8'hC0) >> 2];
        end
    end

    // -------------------------------------------------------------------------
    // 4. The Math FSM & MAC Unit (Copied from yesterday)
    // -------------------------------------------------------------------------
    localparam STATE_IDLE = 2'd0;
    localparam STATE_CALC = 2'd1;
    localparam STATE_DONE = 2'd2;

    reg [1:0] state;
    reg [2:0] row, col, k;

    reg        mac_en, mac_clear;
    reg  [7:0] mac_weight, mac_act;
    wire [31:0] mac_result;

    mac_unit core_mac (
        .clk(pclk), .rstn(presetn), .en(mac_en), .clear(mac_clear),
        .weight(mac_weight), .act(mac_act), .accumulator(mac_result)
    );

    always @(posedge pclk) begin
        if (~presetn) begin
            state <= STATE_IDLE;
            reg_status <= 32'd0;
            row <= 0; col <= 0; k <= 0;
            mac_en <= 0; mac_clear <= 1;
        end else begin
            case (state)
                STATE_IDLE: begin
                    if (reg_ctrl == 32'd1) begin
                        state <= STATE_CALC;
                        reg_status <= 32'd2; // BUSY
                        row <= 0; col <= 0; k <= 0;
                        mac_clear <= 1;
                    end else begin
                        reg_status <= 32'd0; // IDLE
                        mac_en <= 0;
                    end
                end

                STATE_CALC: begin
                    mac_clear <= 0;
                    mac_en <= 1;
                    mac_weight <= matrix_a[(row * 4) + k];
                    mac_act    <= matrix_b[(k * 4) + col];

                    if (k == 3) begin
                        k <= 0;
                        if (col == 3) begin
                            col <= 0;
                            if (row == 3) state <= STATE_DONE;
                            else row <= row + 1;
                        end else col <= col + 1;
                    end else k <= k + 1;
                end

                STATE_DONE: begin
                    mac_en <= 0;
                    reg_status <= 32'd1; // DONE
                    if (reg_ctrl == 32'd0) state <= STATE_IDLE;
                end
            endcase
            
            // Save MAC result
            if (state == STATE_CALC && k == 0 && !mac_clear) begin
                matrix_c[( (col==0 ? row-1 : row) * 4) + (col==0 ? 3 : col-1)] <= mac_result;
                mac_clear <= 1;
            end
        end
    end

endmodule
