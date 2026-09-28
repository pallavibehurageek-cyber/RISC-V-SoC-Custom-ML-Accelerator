#define ACCEL_CTRL   (*((volatile unsigned int*)0x50000000))
#define ACCEL_STATUS (*((volatile unsigned int*)0x50000004))
volatile unsigned int* HW_MATRIX_A = (volatile unsigned int*)0x50000040;
volatile unsigned int* HW_MATRIX_B = (volatile unsigned int*)0x50000080;

#define UART_TX_DATA (*((volatile unsigned int*)0x50000100))
#define UART_STATUS  (*((volatile unsigned int*)0x50000104))

void uart_putc(char c) {
    while (UART_STATUS & 1) {} 
    UART_TX_DATA = c;
}

void uart_print(const char* str) {
    while (*str != '\0') {
        uart_putc(*str);
        str++;
    }
}

void main() {
    int i;
    
    uart_print("Hello World!\n");

    for(i = 0; i < 16; i++) {
        HW_MATRIX_A[i] = 0x10; 
        HW_MATRIX_B[i] = 0x20; 
    }

    ACCEL_CTRL = 1;
    while (ACCEL_STATUS != 1) {}
    ACCEL_CTRL = 0;

    uart_print("Done!\n");

    while(1) {}
}
