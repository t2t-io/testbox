#include <stdint.h>
#include "app.h"

static uint8_t buffer[1024] = {0};

volatile unsigned int * const UART0DR = (unsigned int *)0x101f1000;

void print_uart0(const char *s) {
    while(*s != '\0') { /* Loop until end of string */
        *UART0DR = (unsigned int)(*s); /* Transmit char */
        s++; /* Next char */
    }
}

void print_addr(uintptr_t addr) {
    uint8_t str[32] = {0};
    uintptr_t x = addr;
    int offset = 0;
    int i;

    while (x > 0) {
        uint8_t y = x & 0x0F;
        x = x >> 4;
        str[offset++] = y < 10 ? y + '0' : (y - 10 + 'A');
    }

    for (i = 0; i < (offset >> 1); i++) {
        uint8_t tmp = str[i];
        str[i] = str[offset - i - 1];
        str[offset - i - 1] = tmp;
    }

    print_uart0("0x");
    print_uart0(str);
    print_uart0("\r\n");
}


void print_uint8(uint8_t c) {
    uint8_t h = (c & 0xF0) >> 4;
    uint8_t l = (c & 0x0F);
    uint8_t str[3] = {0};

    uint8_t x;
    str[0] = h < 10 ? (h + '0') : (h - 10 + 'A');
    str[1] = l < 10 ? (l + '0') : (l - 10 + 'A');
    print_uart0(str);
}


typedef void (* func) (int a);


void test(uint8_t *p) {
    print_addr((uintptr_t)p);
}

extern char _x_data_start;
extern char _x_data_end;
extern char _x_bss_start;
extern char _x_bss_end;

static int aa = 0x1234;

void system_main() {
    int i;
    int offset = 8;
    func f;

    print_uart0("_x_data_start = "); print_addr((uintptr_t) &_x_data_start); print_uart0("\n");
    print_uart0("_x_data_end = "); print_addr((uintptr_t) &_x_data_end); print_uart0("\n");
    print_uart0("_x_bss_start = "); print_addr((uintptr_t) &_x_bss_start); print_uart0("\n");
    print_uart0("_x_bss_end = "); print_addr((uintptr_t) &_x_bss_end); print_uart0("\n");

    print_uart0("aa = "); print_addr((uintptr_t) aa); print_uart0("\n");

    print_uart0("buffer = ");
    print_addr((uintptr_t) buffer);
    print_uart0("\n");

    print_uart0("buffer + offset = ");
    print_addr((uintptr_t) (buffer + offset));
    print_uart0("\n");

    print_uart0("print_uart0 = ");
    print_addr((uintptr_t) print_uart0);
    print_uart0("\n");

    print_uart0("print_addr = ");
    print_addr((uintptr_t) print_addr);
    print_uart0("\n");

    for (i = 0; i < APP_SIZE; i++) {
        buffer[i + offset] = app[i];
    }

    print_uart0("BEGIN\r\n");
    f = (func) (buffer + offset);
    f(0x1102);
    print_uart0("END\r\n");
    print_uart0("\r\n");
    print_uart0("\r\n");

    for (i = 0; i < offset; i++) {
        print_uint8(buffer[i]);
        print_uart0("\r\n");
    }

    // print_uart0((char *)0x106a0);
    {
        int *p = (int *) 0x10754;
        print_uart0("static variable = ");
        print_addr((uintptr_t) (*p));
        print_uart0("\r\n");
    }
}