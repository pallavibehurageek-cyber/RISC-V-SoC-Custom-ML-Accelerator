`timescale 1ns / 1ps

// =========================================================================
// Module: accelerator_engine (Version 2.0 - Real Math Engine)
// Theory: A Finite State Machine (FSM) that sequences a 4x4 Matrix Multiplication
//         using a single MAC unit to save hardware area.
// =========================================================================
module accelerator_engine (
    input  wire        clk,
    input  wire        rstn,
    input  wire [31:0] reg_ctrl,   // Ignition switch from APB
    output reg  [31:0] reg_status  // Status output to APB (0=Idle, 1=Done, 2=Busy)
);

    // -------------------------------------------------------------------------
    // 1. Memory: The 4x4 Matrices (Flattened into 16-element arrays)
    // -------------------------------------------------------------------------
    // Q4.4 Fixed Point. Example: 8'h10 = 1.0, 8'h20 = 2.0, 8'h08 = 0.5
    reg [7:0] matrix_a [0:15];
    reg [7:0] matrix_b [0:15];
    reg [31:0] matrix_c [0:15]; // The Output Matrix (32-bit to prevent overflow)

    // Hardcode some values for testing (we will replace this with APB writes later)
    integer i;
    initial begin
        for (i=0; i<16; i=i+1) begin
            matrix_a[i] = 8'h10; // Fill Matrix A with 1.0
            matrix_b[i] = 8'h20; // Fill Matrix B with 2.0
            matrix_c[i] = 32'd0;
        end
    end

    // -------------------------------------------------------------------------
    // 2. FSM States & Counters
    // -------------------------------------------------------------------------
    localparam STATE_IDLE = 2'd0;
    localparam STATE_CALC = 2'd1;
    localparam STATE_DONE = 2'd2;

    reg [1:0] state;
    
    // Hardware "for-loop" counters
    reg [2:0] row; // 0 to 3
    reg [2:0] col; // 0 to 3
    reg [2:0] k;   // 0 to 3 (The dot-product index)

    // -------------------------------------------------------------------------
    // 3. The MAC Unit (The Lego Brick)
    // -------------------------------------------------------------------------
    reg        mac_en;
    reg        mac_clear;
    reg  [7:0] mac_weight;
    reg  [7:0] mac_act;
    wire [31:0] mac_result;

    mac_unit core_mac (
        .clk(clk),
        .rstn(rstn),
        .en(mac_en),
        .clear(mac_clear),
        .weight(mac_weight),
        .act(mac_act),
        .accumulator(mac_result)
    );

    // -------------------------------------------------------------------------
    // 4. The State Machine (The Conductor)
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (~rstn) begin
            state      <= STATE_IDLE;
            reg_status <= 32'd0;
            row        <= 3'd0;
            col        <= 3'd0;
            k          <= 3'd0;
            mac_en     <= 1'b0;
            mac_clear  <= 1'b1;
        end else begin
            case (state)
                // --- WAIT FOR IGNITION ---
                STATE_IDLE: begin
                    if (reg_ctrl == 32'd1) begin
                        state      <= STATE_CALC;
                        reg_status <= 32'd2; // Status: BUSY
                        row        <= 0;
                        col        <= 0;
                        k          <= 0;
                        mac_clear  <= 1; // Clear MAC for first calculation
                    end else begin
                        reg_status <= 32'd0; // Status: IDLE
                        mac_en     <= 0;
                    end
                end

                // --- DO THE MATH (64 Clock Cycles) ---
                STATE_CALC: begin
                    mac_clear <= 0; // Stop clearing, start accumulating!
                    mac_en    <= 1;
                    
                    // Route the correct row/col data into the MAC unit
                    // Address Math: Row * 4 + K
                    mac_weight <= matrix_a[(row * 4) + k];
                    mac_act    <= matrix_b[(k * 4) + col];

                    // Hardware Loop Logic
                    if (k == 3) begin
                        // We finished one dot product! Save it on the NEXT clock cycle
                        k <= 0;
                        if (col == 3) begin
                            col <= 0;
                            if (row == 3) begin
                                state <= STATE_DONE; // Entire 4x4 matrix is finished!
                            end else begin
                                row <= row + 1;
                            end
                        end else begin
                            col <= col + 1;
                        end
                    end else begin
                        k <= k + 1;
                    end
                end

                // --- FINISHED ---
                STATE_DONE: begin
                    mac_en     <= 0;
                    reg_status <= 32'd1; // Status: DONE (CPU can read this!)
                    
                    // If CPU turns off the ignition, go back to IDLE
                    if (reg_ctrl == 32'd0) begin
                        state <= STATE_IDLE;
                    end
                end
            endcase
            
            // Because the MAC unit takes 1 clock cycle to add, we save the 
            // result exactly when 'k' rolls back to 0.
            if (state == STATE_CALC && k == 0 && !mac_clear) begin
                // Save the MAC's total into the correct output matrix slot
                // (Note: we use the 'previous' row/col because counters just updated)
                matrix_c[( (col==0 ? row-1 : row) * 4) + (col==0 ? 3 : col-1)] <= mac_result;
                mac_clear <= 1; // Clear the MAC for the next dot product
            end
        end
    end

endmodule
