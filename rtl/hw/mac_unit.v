`timescale 1ns / 1ps

// =========================================================================
// Module: mac_unit
// Theory: Multiply-Accumulate block for Neural Network computations.
// Why: The fundamental building block for matrix multiplication.
// =========================================================================
module mac_unit (
    input  wire        clk,
    input  wire        rstn,
    input  wire        en,      // 1 = Do math this clock cycle
    input  wire        clear,   // 1 = Reset the accumulator to 0 (for a new row/col)
    
    // Inputs: Q4.4 Fixed Point Numbers (8 bits each)
    input  wire [7:0]  weight,  
    input  wire [7:0]  act,     // Activation (input data)
    
    // Output: The running total
    // 8-bit * 8-bit = 16-bit product. We use 32 bits for the accumulator 
    // to prevent overflow when adding hundreds of products together.
    output reg signed [31:0] accumulator
);

    // 1. Tell Verilog to treat the raw binary as signed (Two's Complement) numbers
    wire signed [7:0] signed_w = weight;
    wire signed [7:0] signed_a = act;
    
    // 2. The Multiplier: Automatically handles the negative/positive math
    wire signed [15:0] product = signed_w * signed_a;

    // 3. The Accumulator Register (Sequential Logic)
    always @(posedge clk) begin
        if (~rstn) begin
            accumulator <= 32'd0;
        end 
        else if (clear) begin
            // Clear is used when we finish a dot product and want to start a new one
            accumulator <= 32'd0; 
        end 
        else if (en) begin
            // The core MAC equation: New Total = Old Total + Product
            // The 16-bit product is automatically sign-extended to 32 bits here
            accumulator <= accumulator + product;
        end
    end

endmodule
