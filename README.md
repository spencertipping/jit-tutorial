# How to write a JIT compiler
First up, you probably don't want to. JIT, or more accurately "dynamic code
generation," is typically not the most effective way to optimize a project, and
common techniques end up trading away a lot of portability and require fairly
detailed knowledge about processor-level optimization.

That said, though, writing JIT compiler is a lot of fun and a great way to
learn stuff. The first thing to do is to write an interpreter.

## MandelASM
GPUs are fine for machine learning, but serious fractal enthusiasts design
their own processors to generate Mandelbrot sets. And the first step in
processor design, of course, is to write an emulator for it. Our emulator will
interpret the machine code we want to run and emit an image to stdout.

To keep it simple, our processor has four complex-valued registers called `a`,
`b`, `c`, and `d`, and it supports three in-place operations:

- `=ab`: assign register `a` to register `b`
- `+ab`: add register `a` to register `b`
- `*ab`: multiply register `b` by register `a`

For each pixel, the interpreter will zero all of the registers and then set `a`
to the current pixel's coordinates. It then iterates the machine code for up to
255 iterations waiting for register `b` to "overflow" (i.e. for its complex
absolute value to exceed 2).

### Simple interpreter
The first thing to do is write up a bare-bones interpreter in C. It would be
simpler to use `complex.h` here, but I'm going to write it in terms of
individual numbers because the JIT compiler will end up generating the longhand
logic. In production code we'd include bounds-checks and stuff, but I'm
omitting those here for simplicity.

```c
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
```

Now we can see the results by using `display` from ImageMagick
(`apt-get install imagemagick`), or by saving to a file:

```sh
$ gcc simple.c -o simple
$ ./simple *bb+ab | display -           # imagemagick version
$ ./simple *bb+ab > output.ppm          # save a grayscale PPM image
```

![image](http://storage8.static.itmages.com/i/17/0308/h_1488995804_6848135_3dd0ab2cdf.jpeg)
