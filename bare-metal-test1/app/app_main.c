#include <stdint.h>

typedef void (* print_uart_t) (const char *s);
typedef void (* print_addr_t) (uintptr_t addr);

static void test2(int b);
static const char *hello = "hello\r\n";

static int xxx = 0;

void main(int a) {
    uint8_t *p = (uint8_t *) main;
    print_uart_t print_uart = (print_uart_t) 0x10010;
    print_addr_t print_addr = (print_addr_t) 0x10060;
    // print_addr((uintptr_t)p);
    // print_addr((uintptr_t)a);
    // test(a + 1);
    print_uart(hello);
    print_uart("world\r\n");
    // print_addr((uintptr_t) hello);
    print_addr((uintptr_t) (a + 1));
    print_addr((uintptr_t) &xxx);
    xxx = 2;
    test2(a + 2);
    p = p - 8;
    p[0] = 'A';
}

static void test2(int b) {
    print_addr_t print_addr = (print_addr_t) 0x10060;
    print_addr(b);
}
