#include <stdint.h>

typedef void (* print_uart_t) (const char *s);
typedef void (* print_addr_t) (uintptr_t addr);

static void test2(int b);
static const char *hello = "hello\r\n";

static int xxx = 0;

void bar_main(int a) {
    uint8_t *p = (uint8_t *) bar_main;
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

/**
 * Why print_uart("hello") cannot output?
 *     => as long as start-address of `bar.ld` specified correctly
 *        the print_uart() can output string correctly.
 *
 * Can I add 2 more functions and let bar_main call them?
 *     => failed!! when test2() is declared before bar_main()
 *             it seems test2() occupies the first address
 *             of `bar.bin`
 *
 *     => success!!, when test2() is declared after bar_main()
 *
 *     => can I specify
 *
 * Can I pass argument to bar_main()?
 *     => success!!
 *
 * Can I use global static variable? (bss, zero-initialized)
 *     => yes, but the address is not perfect.
 *
 *          . = 0x1064C;
            .startup . : { bar.o(.text) }
            .text : { *(.text) }
            .data : { *(.data) }

        With above linker script, the address of variable `static int xxx = 0`
        is located at 0x10754, which is still in the region
        of CODE memory buffer.

        => Can I declare a Memory area to put those bss section?
 *
 *
 * Can I use global static variable with default values? (not BSS, with default values: non-zero)
 *
 *
 * Can I get return value of bar_main()?
 *
 *
 *
 * Add a share header file for jump structure. Just use one sizeof(uintptr_t) to
 * shift the address of bar_main.
 *
 *  struct aa {
 *      void (* print_uart_t) (const char *s);
 *      void (* print_addr_t) (uintptr_t addr);
 *  }
 *
 *  uintptr_t *x = (uintptr_t *) bar_main;
 *  uintptr_t p = (uintptr_t) (*(--x));
 *  struct aa *a = (struct aa *) p;
 *
 *  a->print_uart("hello");
 *  a->print_uart(0xAABB123);
 *
 *
 */