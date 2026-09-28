`timescale 1ns / 1ps

module tb_soc;

    reg clk;
    reg rstn;

    // Instantiate the Motherboard
    soc_top uut (
        .clk(clk),
        .rstn(rstn)
    );

    // 100 MHz Clock
    always #5 clk = ~clk;

    initial begin
        // Initialize
        clk = 0;
        rstn = 0;

        $display("\n--- [Time %0t] Holding CPU in Reset ---", $time);
        
        // Wait 50ns, then release reset to wake up the CPU
        #50 rstn = 1;
        $display("--- [Time %0t] CPU Waking Up! ---", $time);

        // Let the CPU run for a while. 
        // It needs time to fetch instructions from BRAM over AXI and execute them.
        #2000000;

        $display("\n--- [Time %0t] Simulation Finished ---", $time);
        $finish;
    end

endmodule
