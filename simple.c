// simple.c
#include <stdio.h>
#include <stdlib.h>

#define sqr(x) ((x) * (x))

typedef struct { double r; double i; } complex;

void interpret(complex *registers, char const *code) {
  complex *src, *dst;
  double r, i;
  for (; *code; code += 3) {
    dst = &registers[code[2] - 'a'];
    src = &registers[code[1] - 'a'];
    switch (*code) {
      case '=':
        dst->r = src->r;
        dst->i = src->i;
        break;
      case '+':
        dst->r += src->r;
        dst->i += src->i;
        break;
      case '*':
        r = dst->r * src->r - dst->i * src->i;
        i = dst->r * src->i + dst->i * src->r;
        dst->r = r;
        dst->i = i;
        break;
      default:
        fprintf(stderr, "undefined instruction %s (ASCII %x)\n", code, *code);
        exit(1);
    }
  }
}

int main(int argc, char **argv) {
  complex registers[4];
  int i, x, y;
  printf("P2\n%d %d\n%d\n", 800, 800, 255);
  for (y = 0; y < 800; ++y) {
    for (x = 0; x < 800; ++x) {
      registers[0].r = -2 + 4 * (x / 800.0);
      registers[0].i = -2 + 4 * (y / 800.0);
      for (i = 1; i < 4; ++i) registers[i].r = registers[i].i = 0;
      for (i = 0; i < 255 && sqr(registers[1].r) + sqr(registers[1].i) < 4; ++i)
        interpret(registers, argv[1]);
      printf(" %d", 255 - i);
    }
    printf("\n");
  }
  return 0;
}
