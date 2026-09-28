.section .init
.global _start

_start:
    li sp, 0x00002000
    call main
