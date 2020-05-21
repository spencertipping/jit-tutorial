# How to write a JIT compiler
First up, you probably don't want to. JIT, or more accurately "dynamic code
generation," is typically not the most effective way to optimize a project, and
common techniques end up trading away a lot of portability and require fairly
detailed knowledge about processor-level optimization.

That said, though, writing JIT compiler is a lot of fun and a great way to
learn stuff. The first thing to do is to write an interpreter.

**NOTE:** If you don't have solid grasp of UNIX system-level programming, you
might want to read about [how to write a
shell](https://github.com/spencertipping/shell-tutorial), which covers a lot of
the fundamentals.

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
256 iterations waiting for register `b` to "overflow" (i.e. for its complex
absolute value to exceed 2). That means that the code for a standard Mandelbrot
set is `*bb+ab`.

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
  char line[1600];
  printf("P5\n%d %d\n%d\n", 1600, 900, 255);
  for (y = 0; y < 900; ++y) {
    for (x = 0; x < 1600; ++x) {
      registers[0].r = 2 * 1.6 * (x / 1600.0 - 0.5);
      registers[0].i = 2 * 0.9 * (y /  900.0 - 0.5);
      for (i = 1; i < 4; ++i) registers[i].r = registers[i].i = 0;
      for (i = 0; i < 256 && sqr(registers[1].r) + sqr(registers[1].i) < 4; ++i)
        interpret(registers, argv[1]);
      line[x] = i;
    }
    fwrite(line, 1, sizeof(line), stdout);
  }
  return 0;
}
```

Now we can see the results by using `display` from ImageMagick
(`apt-get install imagemagick`), or by saving to a file:

```sh
$ gcc simple.c -o simple
$ ./simple *bb+ab | display -           # imagemagick version
$ ./simple *bb+ab > output.pgm          # save a grayscale PPM image
$ time ./simple *bb+ab > /dev/null      # quick benchmark
real	0m2.369s
user	0m2.364s
sys	0m0.000s
$
```

![image](http://spencertipping.com/mandelbrot-output.png)

### Performance analysis
**In the real world, JIT is absolutely the wrong move for this problem.**

Array languages like APL, Matlab, and to a large extent Perl, Python, etc,
manage to achieve reasonable performance by having interpreter operations that
apply over a large number of data elements at a time. We've got exactly that
situation here: in the real world it's a lot more practical to vectorize the
operations to apply simultaneously to a screen-worth of data at a time -- then
we'd have nice options like offloading stuff to a GPU, etc.

However, since the point here is to compile stuff, on we go.

JIT can basically eliminate the interpreter overhead, which we can easily model
here by replacing `interpret()` with a hard-coded Mandelbrot calculation. This
will provide an upper bound on realistic JIT performance, since we're unlikely
to optimize as well as `gcc` does.

```c
// hardcoded.c
#include <stdio.h>
#include <stdlib.h>

#define sqr(x) ((x) * (x))

typedef struct { double r; double i; } complex;

void interpret(complex *registers, char const *code) {
  complex *a = &registers[0];
  complex *b = &registers[1];
  double r, i;
  r = b->r * b->r - b->i * b->i;
  i = b->r * b->i + b->i * b->r;
  b->r = r;
  b->i = i;
  b->r += a->r;
  b->i += a->i;
}

int main(int argc, char **argv) {
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
        interpret(registers, argv[1]);
      line[x] = i;
    }
    fwrite(line, 1, sizeof(line), stdout);
  }
  return 0;
}
```

This version runs about twice as fast as the simple interpreter:

```sh
$ gcc hardcoded.c -o hardcoded
$ time ./hardcoded *bb+ab > /dev/null
real	0m1.329s
user	0m1.328s
sys	0m0.000s
$
```

### JIT design and the x86-64 calling convention
The basic strategy is to replace `interpret(registers, code)` with a function
`compile(code)` that returns a pointer to a function whose signature is this:
`void compiled(registers*)`. The memory for the function needs to be allocated
using `mmap` so we can set permission for the processor to execute it.

The easiest way to start with something like this is probably to emit the
assembly for `simple.c` to see how it works:

```sh
$ gcc -S simple.c
```

Edited/annotated highlights from the assembly `simple.s`, which is much more
complicated than what we'll end up generating:

```s
interpret:
        // The stack contains local variables referenced to the "base pointer"
        // stored in hardware register %rbp. Here's the layout:
        //
        //   double i  = -8(%rbp)
        //   double r  = -16(%rbp)
        //   src       = -24(%rbp)
        //   dst       = -32(%rbp)
        //   registers = -40(%rbp)      <- comes in as an argument in %rdi
        //   code      = -48(%rbp)      <- comes in as an argument in %rsi

        pushq   %rbp
        movq    %rsp, %rbp              // standard x86-64 function header
        subq    $48, %rsp               // allocate space for six local vars
        movq    %rdi, -40(%rbp)         // registers arg -> local var
        movq    %rsi, -48(%rbp)         // code arg -> local var
        jmp     for_loop_condition      // commence loopage
```

Before getting to the rest, I wanted to call out the `%rsi` and `%rdi` stuff
and explain a bit about how calls work on x86-64. `%rsi` and `%rdi` seem
arbitrary, which they are to some extent -- C obeys a platform-specific calling
convention that specifies how arguments get passed in. On x86-64, up to six
arguments come in as registers; after that they get pushed onto the stack. If
you're returning a value, it goes into `%rax`.

The return address is automatically pushed onto the stack by `call`
instructions like `e8 <32-bit relative>`. So internally, `call` is the same as
`push ADDRESS; jmp <call-site>; ADDRESS: ...`. `ret` is the same as `pop %rip`,
except that you can't pop into `%rip`. This means that the return address is
always the most immediate value on the stack.

Part of the calling convention also requires callees to save a couple of
registers and use `%rbp` to be a copy of `%rsp` at function-call-time, but our
JIT can mostly ignore this stuff because it doesn't call back into C.

```s
for_loop_body:
        // (a bunch of stuff to set up *src and *dst)

        cmpl    $43, %eax               // case '+'
        je      add_branch
        cmpl    $61, %eax               // case '='
        je      assign_branch
        cmpl    $42, %eax               // case '*'
        je      mult_branch
        jmp     switch_default          // default

assign_branch:
        // the "bunch of stuff" above calculated *src and *dst, which are
        // stored in -24(%rbp) and -32(%rbp).
        movq    -24(%rbp), %rax         // %rax = src
        movsd   (%rax), %xmm0           // %xmm0 = src.r
        movq    -32(%rbp), %rax         // %rax = dst
        movsd   %xmm0, (%rax)           // dst.r = %xmm0

        movq    -24(%rbp), %rax         // %rax = src
        movsd   8(%rax), %xmm0          // %xmm0 = src.i
        movq    -32(%rbp), %rax         // %rax = dst
        movsd   %xmm0, 8(%rax)          // dst.i = %xmm0

        jmp     for_loop_step

add_branch:
        movq    -32(%rbp), %rax         // %rax = dst
        movsd   (%rax), %xmm1           // %xmm1 = dst.r
        movq    -24(%rbp), %rax         // %rax = src
        movsd   (%rax), %xmm0           // %xmm0 = src.r
        addsd   %xmm1, %xmm0            // %xmm0 += %xmm1
        movq    -32(%rbp), %rax         // %rax = dst
        movsd   %xmm0, (%rax)           // dst.r = %xmm0

        movq    -32(%rbp), %rax         // same thing for src.i and dst.i
        movsd   8(%rax), %xmm1
        movq    -24(%rbp), %rax
        movsd   8(%rax), %xmm0
        addsd   %xmm1, %xmm0
        movq    -32(%rbp), %rax
        movsd   %xmm0, 8(%rax)

        jmp     for_loop_step

mult_branch:
        movq    -32(%rbp), %rax
        movsd   (%rax), %xmm1
        movq    -24(%rbp), %rax
        movsd   (%rax), %xmm0
        mulsd   %xmm1, %xmm0
        movq    -32(%rbp), %rax
        movsd   8(%rax), %xmm2
        movq    -24(%rbp), %rax
        movsd   8(%rax), %xmm1
        mulsd   %xmm2, %xmm1
        subsd   %xmm1, %xmm0
        movsd   %xmm0, -16(%rbp)        // double r = src.r*dst.r - src.i*dst.i

        movq    -32(%rbp), %rax
        movsd   (%rax), %xmm1
        movq    -24(%rbp), %rax
        movsd   8(%rax), %xmm0
        mulsd   %xmm0, %xmm1
        movq    -32(%rbp), %rax
        movsd   8(%rax), %xmm2
        movq    -24(%rbp), %rax
        movsd   (%rax), %xmm0
        mulsd   %xmm2, %xmm0
        addsd   %xmm1, %xmm0
        movsd   %xmm0, -8(%rbp)         // double i = src.r*dst.i + src.i*dst.r

        movq    -32(%rbp), %rax
        movsd   -16(%rbp), %xmm0
        movsd   %xmm0, (%rax)           // dst.r = r
        movq    -32(%rbp), %rax
        movsd   -8(%rbp), %xmm0
        movsd   %xmm0, 8(%rax)          // dst.i = i
        jmp     for_loop_step

for_loop_step:
        addq    $3, -48(%rbp)

for_loop_condition:
        movq    -48(%rbp), %rax         // %rax = code (the pointer)
        movzbl  (%rax), %eax            // %eax = *code (move one byte)
        testb   %al, %al                // is %eax 0?
        jne     for_loop_body           // if no, then continue

        leave                           // otherwise rewind stack
        ret                             // pop and jmp
```

#### Compilation strategy
Most of the above is register-shuffling fluff that we can get rid of. We're
compiling the code up front, which means all of our register addresses are
known quantities and we won't need any unknown indirection at runtime. So all
of the shuffling into and out of `%rax` can be replaced by a much simpler move
directly to or from `N(%rdi)` -- since `%rdi` is the argument that points to
the first register's real component.

If you haven't already, at this point I'd recommend downloading the [Intel
software developer's
manual](https://software.intel.com/en-us/articles/intel-sdm), of which volume 2
describes the semantics and machine code representation of every instruction.

**NOTE:** GCC uses AT&T assembly syntax, whereas the Intel manuals use Intel
assembly syntax. An important difference is that AT&T reverses the arguments:
`mov %rax, %rbx` (AT&T syntax) assigns to `%rbx`, whereas `mov rax, rbx` (Intel
syntax) assigns to `rax`. All of my code examples use AT&T, and none of this
will matter once we're working with machine code.

##### Example: the Mandelbrot function `*bb+ab`
```s
// Step 1: multiply register B by itself
movsd 16(%rdi), %xmm0                   // %xmm0 = b.r
movsd 24(%rdi), %xmm1                   // %xmm1 = b.i
movsd 16(%rdi), %xmm2                   // %xmm2 = b.r
movsd 24(%rdi), %xmm3                   // %xmm3 = b.i
movsd %xmm0, %xmm4                      // %xmm4 = b.r
mulsd %xmm2, %xmm4                      // %xmm4 = b.r*b.r
movsd %xmm1, %xmm5                      // %xmm5 = b.i
mulsd %xmm3, %xmm5                      // %xmm5 = b.i*b.i
subsd %xmm5, %xmm4                      // %xmm4 = b.r*b.r - b.i*b.i
movsd %xmm4, 16(%rdi)                   // b.r = %xmm4

mulsd %xmm0, %xmm3                      // %xmm3 = b.r*b.i
mulsd %xmm1, %xmm2                      // %xmm2 = b.i*b.r
addsd %xmm3, %xmm2                      // %xmm2 = b.r*b.i + b.i*b.r
movsd %xmm2, 24(%rdi)                   // b.i = %xmm2

// Step 2: add register A to register B
movpd (%rdi), %xmm0                     // %xmm0 = (a.r, a.i)
addpd %xmm0, 16(%rdi)                   // %xmm0 += (b.r, b.i)
movpd %xmm0, 16(%rdi)                   // (b.r, b.i) = %xmm0
```

The multiplication code isn't optimized for the squaring-a-register use case;
instead, I left it fully general so we can use it as a template when we start
generating machine code.

### JIT mechanics
Before we compile a real language, let's just get a basic code generator
working.

```c
// jitproto.c
#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>

typedef long(*fn)(long);

fn compile_identity(void) {
  // Allocate some memory and set its permissions correctly. In particular, we
  // need PROT_EXEC (which isn't normally enabled for data memory, e.g. from
  // malloc()), which tells the processor it's ok to execute it as machine
  // code.
  char *memory = mmap(NULL,             // address
                      4096,             // size
                      PROT_READ | PROT_WRITE | PROT_EXEC,
                      MAP_PRIVATE | MAP_ANONYMOUS,
                      -1,               // fd (not used here)
                      0);               // offset (not used here)
  if (memory == MAP_FAILED) {
    perror("failed to allocate memory");
    exit(1);
  }

  int i = 0;

  // mov %rdi, %rax
  memory[i++] = 0x48;           // REX.W prefix
  memory[i++] = 0x8b;           // MOV opcode, register/register
  memory[i++] = 0xc7;           // MOD/RM byte for %rdi -> %rax

  // ret
  memory[i++] = 0xc3;           // RET opcode

  return (fn) memory;
}

int main() {
  fn f = compile_identity();
  int i;
  for (i = 0; i < 10; ++i)
    printf("f(%d) = %ld\n", i, (*f)(i));
  munmap(f, 4096);
  return 0;
}
```

This does what we expect: we've just produced an identity function.

```sh
$ gcc jitproto.c -o jitproto
$ ./jitproto
f(0) = 0
f(1) = 1
f(2) = 2
f(3) = 3
f(4) = 4
f(5) = 5
f(6) = 6
f(7) = 7
f(8) = 8
f(9) = 9
```

**TODO:** explanation about userspace page mapping/permissions, and how ELF
instructions tie into this (maybe also explain stuff like the FD table while
we're at it)

#### Generating MandelASM machine code
This is where we start to get some serious mileage out of the Intel manuals. We
need encodings for the following instructions:

- `f2 0f 11`: `movsd reg -> memory`
- `f2 0f 10`: `movsd memory -> reg`
- `f2 0f 59`: `mulsd reg -> reg`
- `f2 0f 58`: `addsd reg -> reg`
- `f2 0f 5c`: `subsd reg -> reg`
- `66 0f 11`: `movpd reg -> memory` (technically `movupd` for unaligned move)
- `66 0f 10`: `movpd memory -> reg`
- `66 0f 58`: `addpd memory -> reg`

##### The gnarly bits: how operands are specified
Chapter 2 of the Intel manual volume 2 contains a roundabout, confusing
description of operand encoding, so I'll try to sum up the basics here.
(**TODO**)

For the operators above, we've got two ModR/M configurations:

- `movsd reg <-> X(%rdi)`: mod = 01, r/m = 111, disp8 = X
- `addsd reg -> reg`: mod = 11

At the byte level, they're written like this:

```
movsd %xmm0, 16(%rdi)           # f2 0f 11 47 10
  # modr/m = b01 000 111 = 47
  # disp   = 16          = 10

addsd %xmm3, %xmm4              # f2 0f 58 e3
  # modr/m = b11 100 011 = e3
```

##### A simple micro-assembler
```h
// micro-asm.h
#include <stdarg.h>
typedef struct {
  char *dest;
} microasm;

// this makes it more obvious what we're doing later on
#define xmm(n) (n)

void asm_write(microasm *a, int n, ...) {
  va_list bytes;
  int i;
  va_start(bytes, n);
  for (i = 0; i < n; ++i) *(a->dest++) = (char) va_arg(bytes, int);
  va_end(bytes);
}

void movsd_reg_memory(microasm *a, char reg, char disp)
{ asm_write(a, 5, 0xf2, 0x0f, 0x11, 0x47 | reg << 3, disp); }

void movsd_memory_reg(microasm *a, char disp, char reg)
{ asm_write(a, 5, 0xf2, 0x0f, 0x10, 0x47 | reg << 3, disp); }

void movsd_reg_reg(microasm *a, char src, char dst)
{ asm_write(a, 4, 0xf2, 0x0f, 0x11, 0xc0 | src << 3 | dst); }

void mulsd(microasm *a, char src, char dst)
{ asm_write(a, 4, 0xf2, 0x0f, 0x59, 0xc0 | dst << 3 | src); }

void addsd(microasm *a, char src, char dst)
{ asm_write(a, 4, 0xf2, 0x0f, 0x58, 0xc0 | dst << 3 | src); }

void subsd(microasm *a, char src, char dst)
{ asm_write(a, 4, 0xf2, 0x0f, 0x5c, 0xc0 | dst << 3 | src); }

void movpd_reg_memory(microasm *a, char reg, char disp)
{ asm_write(a, 5, 0x66, 0x0f, 0x11, 0x47 | reg << 3, disp); }

void movpd_memory_reg(microasm *a, char disp, char reg)
{ asm_write(a, 5, 0x66, 0x0f, 0x10, 0x47 | reg << 3, disp); }

void addpd_memory_reg(microasm *a, char disp, char reg)
{ asm_write(a, 5, 0x66, 0x0f, 0x58, 0x47 | reg << 3, disp); }
```

##### Putting it all together
Now that we can write assembly-level stuff, we can take the structure from the
prototype JIT compiler and modify it to compile MandelASM.

```c
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

  // Return to caller (important! otherwise we'll segfault)
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
```

Now let's benchmark the interpreted and JIT-compiled versions:

```sh
$ gcc mandeljit.c -o mandeljit
$ time ./simple *bb+ab > /dev/null
real	0m2.348s
user	0m2.344s
sys	0m0.000s
$ time ./mandeljit *bb+ab > /dev/null
real    0m1.462s
user    0m1.460s
sys     0m0.000s
```

Very close to the limit performance of the hardcoded version. And, of course,
the JIT-compiled result is identical to the interpreted one:

```sh
$ ./simple *bb+ab | md5sum
12a1013d55ee17998390809ffd671dbc  -
$ ./mandeljit *bb+ab | md5sum
12a1013d55ee17998390809ffd671dbc  -
```

## Further reading
### Debugging JIT compilers
First, you need a good scotch; this one should work.

![image](https://cdn1.masterofmalt.com/whiskies/p-2813/laphroaig-quarter-cask-whisky.jpg?ss=2.0)

Once you've got that set up, `gdb` can probably be scripted to do what you
need. I've [used it somewhat
successfully](https://github.com/spencertipping/canard/blob/circular/bin/canard.debug.gdb)
to debug a bunch of hand-written self-modifying machine code with no debugging
symbols -- the limitations of the approach ended up being whiskey-related
rather than any deficiency of GDB itself.

I've also had some luck using [radare2](http://www.radare.org/r/) to figure out
when I was generating bogus instructions.

Offline disassemblers like NASM and YASM won't help you.

### Low-level
- The Intel guides cover a lot of stuff we didn't end up using here: addressing
  modes, instructions, etc. If you're serious about writing JIT compilers, it's
  worth an in-depth read.

- [Agner Fog's guides to processor-level
  optimization](http://www.agner.org/optimize/): an insanely detailed tour
  through processor internals, instruction parsing pipelines, and pretty much
  every variant of every processor in existence.

- [The V8 source
  code](https://github.com/v8/v8/blob/master/src/codegen/x64/assembler-x64.h): how JIT
  assemblers are actually written

- [The JVM source
  code](http://hg.openjdk.java.net/jdk9/hs/hotspot/file/6868eb69ce70/src)

- [Jonesforth](http://git.annexia.org/?p=jonesforth.git;a=blob;f=jonesforth.S;h=45e6e854a5d2a4c3f26af264dfce56379d401425;hb=HEAD):
  a well-documented example of low-level code generation and interpreter
  structure (sort of a JIT alternative)

- [Canard machine
  code](https://github.com/spencertipping/canard/blob/circular/bin/canard.md#introduction):
  similar to jonesforth, but uses machine code for its data structures
