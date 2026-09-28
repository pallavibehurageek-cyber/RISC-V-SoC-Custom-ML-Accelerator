RISC-V SoC with Custom ML Accelerator

🚀 Project Overview

This project implements a bare-metal RISC-V System-on-Chip (SoC) integrating a lightweight RISC-V processor with a custom hardware accelerator for matrix computation.

The system combines a PicoRV32 RV32IM processor, AXI4-Lite to APB interconnect, 8 KB on-chip BRAM, a custom Q4.4 fixed-point matrix-multiplication accelerator, and an APB UART peripheral.

The project demonstrates hardware/software co-design in which the processor controls dedicated hardware through memory-mapped registers instead of relying on an operating system or standard runtime environment.

---

🎯 Objectives

- Build a complete RISC-V-based SoC.
- Integrate a lightweight RV32IM processor.
- Implement a custom hardware accelerator for matrix operations.
- Use fixed-point arithmetic for hardware-efficient computation.
- Connect peripherals through AXI4-Lite and APB interfaces.
- Implement memory-mapped control and status registers.
- Develop bare-metal firmware for SoC control.
- Create a custom assembly startup sequence and linker script.
- Verify the integrated hardware/software system.
- Evaluate FPGA timing performance.

---

🏗️ System Architecture

The overall architecture consists of the following major blocks:

                    ┌──────────────────────┐
                    │      PicoRV32        │
                    │      RV32IM CPU      │
                    └──────────┬───────────┘
                               │
                         AXI4-Lite Bus
                               │
                    ┌──────────▼──────────┐
                    │ AXI4-Lite → APB     │
                    │      Bridge         │
                    └──────────┬──────────┘
                               │
                             APB
              ┌────────────────┼────────────────┐
              │                │                │
              ▼                ▼                ▼
       ┌────────────┐   ┌──────────────┐   ┌────────────┐
       │ ML         │   │ APB UART     │   │ Other      │
       │ Accelerator│   │ Transmitter  │   │ Peripherals│
       └────────────┘   └──────────────┘   └────────────┘

                    ┌──────────────────────┐
                    │      8 KB BRAM       │
                    │ Boot / Code / Data   │
                    └──────────────────────┘

The architecture documented by the project uses a PicoRV32 RV32IM CPU, an AXI4-Lite to APB bridge, 8 KB BRAM, a custom matrix accelerator, and an APB UART.

---

🧠 RISC-V Processor

The processor subsystem is based on PicoRV32, configured around the RV32IM instruction set.

The CPU executes the bare-metal firmware stored in the on-chip memory and communicates with the hardware peripherals through memory-mapped addresses.

This allows software instructions to control the ML accelerator and UART without requiring an operating system.

---

⚡ Custom ML Accelerator

The SoC includes a custom accelerator designed for fixed-point matrix multiplication.

Accelerator Characteristics

- Q4.4 fixed-point arithmetic
- 4 × 4 matrix computation
- MAC-based processing
- Hardware-controlled computation
- 64-cycle matrix dot-product operation

The accelerator is accessed through memory-mapped APB registers, allowing the RISC-V processor to configure and start computations from software.

Conceptual Data Flow

Matrix A ──┐
           │
           ▼
      ┌───────────┐
      │ ML        │
      │ Accelerator│
      └─────┬─────┘
            │
            ▼
        Matrix Result

The dedicated hardware datapath allows matrix operations to be performed without executing every multiplication and accumulation operation directly on the CPU.

---

🔌 AXI4-Lite to APB Interconnect

The system uses an AXI4-Lite to APB bridge to connect the processor-side bus infrastructure with low-complexity peripheral interfaces.

PicoRV32
   │
   ▼
AXI4-Lite
   │
   ▼
AXI4-Lite → APB Bridge
   │
   ├──────────► ML Accelerator
   │
   └──────────► UART

This architecture separates the processor/interconnect side from the peripheral-control side.

---

💾 Memory System

The SoC contains 8 KB of BRAM used for:

- Bootloader
- Program instructions
- Data
- Stack

The memory is therefore shared by the bare-metal firmware environment and processor execution system.

---

🗺️ Memory-Mapped Peripheral Interface

The accelerator and UART are controlled using memory-mapped registers.

Peripheral| Register| Address| Access| Function
ML Accelerator| "ACCEL_CTRL"| "0x50000000"| Write| Start computation
ML Accelerator| "ACCEL_STATUS"| "0x50000004"| Read| Accelerator status
ML Accelerator| "MATRIX_A_BASE"| "0x50000040"| Write| Matrix A base address
ML Accelerator| "MATRIX_B_BASE"| "0x50000080"| Write| Matrix B base address
UART| "TX_DATA"| "0x50000100"| Write| Transmit character
UART| "TX_STATUS"| "0x50000104"| Read| UART status

These addresses and register functions are documented in the original project.

---

📡 UART Peripheral

An APB-based UART transmitter provides a simple communication interface for the SoC.

The documented configuration uses:

- 115200 baud
- Memory-mapped transmit register
- Hardware status polling

The processor can write characters to the UART through the "TX_DATA" register and check the transmitter state using "TX_STATUS".

---

💻 Bare-Metal Firmware

The system operates without an operating system or standard C runtime.

The firmware environment contains three important elements:

"start.S"

Custom assembly startup code initializes the processor environment and sets the stack pointer.

"link.ld"

A custom linker script defines the memory layout and places the boot code at the required memory address.

"main.c"

The main C program communicates with the hardware using memory-mapped register accesses.

The original project uses a freestanding RISC-V compilation flow with "riscv64-unknown-elf-gcc" and converts the resulting executable into a Verilog-compatible firmware image.

---

🔄 Hardware/Software Co-Design Flow

             ┌─────────────────┐
             │  RISC-V CPU     │
             └────────┬────────┘
                      │
                      ▼
             ┌─────────────────┐
             │ Bare-Metal      │
             │ Firmware        │
             └────────┬────────┘
                      │
              Memory-Mapped I/O
                      │
          ┌───────────┴───────────┐
          ▼                       ▼
 ┌─────────────────┐     ┌─────────────────┐
 │ ML Accelerator  │     │      UART       │
 └─────────────────┘     └─────────────────┘

This creates a hardware/software interface where software configures specialized hardware through registers.

---

⏱️ FPGA Timing Performance

The documented FPGA implementation achieved:

Maximum Frequency: 158 MHz

with:

Worst Negative Slack (WNS): +3.67 ns

The project reports this as achieved timing closure in Vivado.

---

🧪 Verification & Testing

The integrated system can be evaluated at multiple levels:

RTL Level

Verify individual modules such as:

- CPU interface
- Bus bridge
- Accelerator
- UART
- Memory

Integration Level

Verify:

- Processor-to-peripheral communication
- Memory-mapped register accesses
- Accelerator control
- UART transmission
- System-level data flow

Hardware Level

Evaluate:

- FPGA synthesis
- Timing closure
- Maximum operating frequency
- Resource utilization

---

🛠️ Technologies Used

Category| Technology
Processor| PicoRV32
ISA| RV32IM
HDL| Verilog
Interconnect| AXI4-Lite / APB
Memory| BRAM
Accelerator| Q4.4 Fixed-Point Matrix Multiplier
Peripheral| APB UART
Firmware| C + RISC-V Assembly
FPGA Flow| Vivado
Target| FPGA

---

🧠 Skills Demonstrated

- RISC-V Architecture
- SoC Design
- RTL Design
- Verilog
- Digital System Architecture
- AXI4-Lite
- APB
- Hardware/Software Co-Design
- Fixed-Point Arithmetic
- Matrix Multiplication Hardware
- Memory-Mapped I/O
- Bare-Metal Firmware
- FPGA Synthesis
- Timing Analysis
- Hardware Accelerator Design

---

📚 Key Learning Outcomes

This project provides practical exposure to:

- Integrating a RISC-V processor into an SoC
- Designing custom hardware accelerators
- Connecting peripherals through standard bus protocols
- Using memory-mapped registers
- Developing bare-metal firmware
- Working with fixed-point arithmetic
- Understanding hardware/software interaction
- Building and synthesizing an FPGA-based SoC
- Interpreting FPGA timing results

---

📌 Project Summary

Parameter| Details
Architecture| RISC-V SoC
CPU| PicoRV32
ISA| RV32IM
ML Accelerator| 4 × 4 Matrix Multiplication
Arithmetic| Q4.4 Fixed Point
Interconnect| AXI4-Lite → APB
Memory| 8 KB BRAM
Peripheral| APB UART
FPGA Flow| Vivado
Reported Fmax| 158 MHz
Reported WNS| +3.67 ns

The architectural and timing values above come from the repository's current documentation.

---
