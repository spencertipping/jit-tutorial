// mandeljit.c
#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>

#include "micro-asm.h"

#define sqr(x) ((x) * (x))

typedef struct { double r; double i; } complex;
typedef void(*compiled)(complex*);

#define offsetof(type, field) ((unsigned long) &(((type *) 0)->field))

compiled compile(char *code) {
  char *memory = mmap(NULL, 4096, PROT_READ | PROT_WRITE | PROT_EXEC,
                      MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
  microasm a = { .dest = memory };
  char src_dsp, dst_dsp;
  char const r = offsetof(complex, r);
  char const i = offsetof(complex, i);

  for (; *code; code += 3) {
    src_dsp = sizeof(complex) * (code[1] - 'a');
    dst_dsp = sizeof(complex) * (code[2] - 'a');
    switch (*code) {
      case '=':
        movpd_memory_reg(&a, src_dsp, xmm(0));
        movpd_reg_memory(&a, xmm(0), dst_dsp);
        break;

      case '+':
        movpd_memory_reg(&a, src_dsp, xmm(0));
        addpd_memory_reg(&a, dst_dsp, xmm(0));
        movpd_reg_memory(&a, xmm(0), dst_dsp);
        break;

      case '*':
        movsd_memory_reg(&a, src_dsp + r, xmm(0));
        movsd_memory_reg(&a, src_dsp + i, xmm(1));
        movsd_memory_reg(&a, dst_dsp + r, xmm(2));
        movsd_memory_reg(&a, dst_dsp + i, xmm(3));
        movsd_reg_reg   (&a, xmm(0), xmm(4));
        mulsd           (&a, xmm(2), xmm(4));
        movsd_reg_reg   (&a, xmm(1), xmm(5));
        mulsd           (&a, xmm(3), xmm(5));
        subsd           (&a, xmm(5), xmm(4));
        movsd_reg_memory(&a, xmm(4), dst_dsp + r);

        mulsd           (&a, xmm(0), xmm(3));
        mulsd           (&a, xmm(1), xmm(2));
        addsd           (&a, xmm(3), xmm(2));
        movsd_reg_memory(&a, xmm(2), dst_dsp + i);
        break;

      default:
        fprintf(stderr, "undefined instruction %s (ASCII %x)\n", code, *code);
        exit(1);
    }
  }

  // Return to caller (important!)
  asm_write(&a, 1, 0xc3);

  return (compiled) memory;
}

int main(int argc, char **argv) {
  compiled fn = compile(argv[1]);
  complex registers[4];
  int i, x, y;
  char line[1600];
  printf("P5\n%d %d\n%d\n", 1600, 900, 255);
  for (y = 0; y < 900; ++y) {
    for (x = 0; x < 1600; ++x) {
      registers[0].r = 2 * 1.6 * (x / 1600.0 - 0.5);
      registers[0].i = 2 * 0.9 * (y /  900.0 - 0.5);
      for (i = 1; i < 4; ++i) registers[i].r = registers[i].i = 0;
      for (i = 0; i < 256 && sqr(registers[1].r) + sqr(registers[1].i) < 4; ++i)
        (*fn)(registers);
      line[x] = i;
    }
    fwrite(line, 1, sizeof(line), stdout);
  }
  return 0;
}
