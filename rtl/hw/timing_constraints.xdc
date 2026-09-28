# Define a 100 MHz clock (10.0 nanosecond period) on the 'clk' input port
create_clock -period 10.000 -name sys_clk [get_ports clk]
