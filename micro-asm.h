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

void movpd_reg_memory(microasm *a, char reg,  char disp) { asm_write(a, 5, 0x66, 0x0f, 0x11, 0x47 | reg << 3, disp); }
void movpd_memory_reg(microasm *a, char disp, char reg)  { asm_write(a, 5, 0x66, 0x0f, 0x10, 0x47 | reg << 3, disp); }
void addpd_memory_reg(microasm *a, char disp, char reg)  { asm_write(a, 5, 0x66, 0x0f, 0x58, 0x47 | reg << 3, disp); }
void movsd_reg_memory(microasm *a, char reg,  char disp) { asm_write(a, 5, 0xf2, 0x0f, 0x11, 0x47 | reg << 3, disp); }
void movsd_memory_reg(microasm *a, char disp, char reg)  { asm_write(a, 5, 0xf2, 0x0f, 0x10, 0x47 | reg << 3, disp); }
void movsd_reg_reg   (microasm *a, char src,  char dst)  { asm_write(a, 4, 0xf2, 0x0f, 0x11, 0xc0 | src << 3 | dst); }
void mulsd           (microasm *a, char src,  char dst)  { asm_write(a, 4, 0xf2, 0x0f, 0x59, 0xc0 | dst << 3 | src); }
void addsd           (microasm *a, char src,  char dst)  { asm_write(a, 4, 0xf2, 0x0f, 0x58, 0xc0 | dst << 3 | src); }
void subsd           (microasm *a, char src,  char dst)  { asm_write(a, 4, 0xf2, 0x0f, 0x5c, 0xc0 | dst << 3 | src); }
