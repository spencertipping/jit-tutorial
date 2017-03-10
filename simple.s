	.file	"simple.c"
	.section	.rodata
	.align 8
.LC0:
	.string	"undefined instruction %s (ASCII %x)\n"
	.text
	.globl	interpret
	.type	interpret, @function
interpret:
.LFB2:
	.cfi_startproc
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset 6, -16
	movq	%rsp, %rbp
	.cfi_def_cfa_register 6
	subq	$48, %rsp
	movq	%rdi, -40(%rbp)
	movq	%rsi, -48(%rbp)
	jmp	.L2
.L8:
	movq	-48(%rbp), %rax
	addq	$2, %rax
	movzbl	(%rax), %eax
	movsbq	%al, %rax
	salq	$4, %rax
	leaq	-1552(%rax), %rdx
	movq	-40(%rbp), %rax
	addq	%rdx, %rax
	movq	%rax, -32(%rbp)
	movq	-48(%rbp), %rax
	addq	$1, %rax
	movzbl	(%rax), %eax
	movsbq	%al, %rax
	salq	$4, %rax
	leaq	-1552(%rax), %rdx
	movq	-40(%rbp), %rax
	addq	%rdx, %rax
	movq	%rax, -24(%rbp)
	movq	-48(%rbp), %rax
	movzbl	(%rax), %eax
	movsbl	%al, %eax
	cmpl	$43, %eax
	je	.L4
	cmpl	$61, %eax
	je	.L5
	cmpl	$42, %eax
	je	.L6
	jmp	.L9
.L5:
	movq	-24(%rbp), %rax
	movsd	(%rax), %xmm0
	movq	-32(%rbp), %rax
	movsd	%xmm0, (%rax)
	movq	-24(%rbp), %rax
	movsd	8(%rax), %xmm0
	movq	-32(%rbp), %rax
	movsd	%xmm0, 8(%rax)
	jmp	.L7
.L4:
	movq	-32(%rbp), %rax
	movsd	(%rax), %xmm1
	movq	-24(%rbp), %rax
	movsd	(%rax), %xmm0
	addsd	%xmm1, %xmm0
	movq	-32(%rbp), %rax
	movsd	%xmm0, (%rax)
	movq	-32(%rbp), %rax
	movsd	8(%rax), %xmm1
	movq	-24(%rbp), %rax
	movsd	8(%rax), %xmm0
	addsd	%xmm1, %xmm0
	movq	-32(%rbp), %rax
	movsd	%xmm0, 8(%rax)
	jmp	.L7
.L6:
	movq	-32(%rbp), %rax
	movsd	(%rax), %xmm1
	movq	-24(%rbp), %rax
	movsd	(%rax), %xmm0
	mulsd	%xmm1, %xmm0
	movq	-32(%rbp), %rax
	movsd	8(%rax), %xmm2
	movq	-24(%rbp), %rax
	movsd	8(%rax), %xmm1
	mulsd	%xmm2, %xmm1
	subsd	%xmm1, %xmm0
	movsd	%xmm0, -16(%rbp)
	movq	-32(%rbp), %rax
	movsd	(%rax), %xmm1
	movq	-24(%rbp), %rax
	movsd	8(%rax), %xmm0
	mulsd	%xmm0, %xmm1
	movq	-32(%rbp), %rax
	movsd	8(%rax), %xmm2
	movq	-24(%rbp), %rax
	movsd	(%rax), %xmm0
	mulsd	%xmm2, %xmm0
	addsd	%xmm1, %xmm0
	movsd	%xmm0, -8(%rbp)
	movq	-32(%rbp), %rax
	movsd	-16(%rbp), %xmm0
	movsd	%xmm0, (%rax)
	movq	-32(%rbp), %rax
	movsd	-8(%rbp), %xmm0
	movsd	%xmm0, 8(%rax)
	jmp	.L7
.L9:
	movq	-48(%rbp), %rax
	movzbl	(%rax), %eax
	movsbl	%al, %ecx
	movq	stderr(%rip), %rax
	movq	-48(%rbp), %rdx
	movl	$.LC0, %esi
	movq	%rax, %rdi
	movl	$0, %eax
	call	fprintf
	movl	$1, %edi
	call	exit
.L7:
	addq	$3, -48(%rbp)
.L2:
	movq	-48(%rbp), %rax
	movzbl	(%rax), %eax
	testb	%al, %al
	jne	.L8
	nop
	leave
	.cfi_def_cfa 7, 8
	ret
	.cfi_endproc
.LFE2:
	.size	interpret, .-interpret
	.section	.rodata
.LC1:
	.string	"P5\n%d %d\n%d\n"
	.text
	.globl	main
	.type	main, @function
main:
.LFB3:
	.cfi_startproc
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset 6, -16
	movq	%rsp, %rbp
	.cfi_def_cfa_register 6
	subq	$1712, %rsp
	movl	%edi, -1700(%rbp)
	movq	%rsi, -1712(%rbp)
	movq	%fs:40, %rax
	movq	%rax, -8(%rbp)
	xorl	%eax, %eax
	movl	$255, %ecx
	movl	$900, %edx
	movl	$1600, %esi
	movl	$.LC1, %edi
	movl	$0, %eax
	call	printf
	movl	$0, -1684(%rbp)
	jmp	.L11
.L19:
	movl	$0, -1688(%rbp)
	jmp	.L12
.L18:
	pxor	%xmm0, %xmm0
	cvtsi2sd	-1688(%rbp), %xmm0
	movsd	.LC2(%rip), %xmm1
	divsd	%xmm1, %xmm0
	movsd	.LC3(%rip), %xmm1
	subsd	%xmm1, %xmm0
	movsd	.LC4(%rip), %xmm1
	mulsd	%xmm1, %xmm0
	movsd	%xmm0, -1680(%rbp)
	pxor	%xmm0, %xmm0
	cvtsi2sd	-1684(%rbp), %xmm0
	movsd	.LC5(%rip), %xmm1
	divsd	%xmm1, %xmm0
	movsd	.LC3(%rip), %xmm1
	subsd	%xmm1, %xmm0
	movsd	.LC6(%rip), %xmm1
	mulsd	%xmm1, %xmm0
	movsd	%xmm0, -1672(%rbp)
	movl	$1, -1692(%rbp)
	jmp	.L13
.L14:
	movl	-1692(%rbp), %eax
	cltq
	salq	$4, %rax
	addq	%rbp, %rax
	subq	$1672, %rax
	pxor	%xmm0, %xmm0
	movsd	%xmm0, (%rax)
	movl	-1692(%rbp), %eax
	cltq
	salq	$4, %rax
	addq	%rbp, %rax
	subq	$1672, %rax
	movsd	(%rax), %xmm0
	movl	-1692(%rbp), %eax
	cltq
	salq	$4, %rax
	addq	%rbp, %rax
	subq	$1680, %rax
	movsd	%xmm0, (%rax)
	addl	$1, -1692(%rbp)
.L13:
	cmpl	$3, -1692(%rbp)
	jle	.L14
	movl	$0, -1692(%rbp)
	jmp	.L15
.L17:
	movq	-1712(%rbp), %rax
	addq	$8, %rax
	movq	(%rax), %rdx
	leaq	-1680(%rbp), %rax
	movq	%rdx, %rsi
	movq	%rax, %rdi
	call	interpret
	addl	$1, -1692(%rbp)
.L15:
	cmpl	$255, -1692(%rbp)
	jg	.L16
	movsd	-1664(%rbp), %xmm1
	movsd	-1664(%rbp), %xmm0
	mulsd	%xmm0, %xmm1
	movsd	-1656(%rbp), %xmm2
	movsd	-1656(%rbp), %xmm0
	mulsd	%xmm2, %xmm0
	addsd	%xmm1, %xmm0
	movsd	.LC8(%rip), %xmm1
	ucomisd	%xmm0, %xmm1
	ja	.L17
.L16:
	movl	-1692(%rbp), %eax
	movl	%eax, %edx
	movl	-1688(%rbp), %eax
	cltq
	movb	%dl, -1616(%rbp,%rax)
	addl	$1, -1688(%rbp)
.L12:
	cmpl	$1599, -1688(%rbp)
	jle	.L18
	movq	stdout(%rip), %rdx
	leaq	-1616(%rbp), %rax
	movq	%rdx, %rcx
	movl	$1600, %edx
	movl	$1, %esi
	movq	%rax, %rdi
	call	fwrite
	addl	$1, -1684(%rbp)
.L11:
	cmpl	$899, -1684(%rbp)
	jle	.L19
	movl	$0, %eax
	movq	-8(%rbp), %rcx
	xorq	%fs:40, %rcx
	je	.L21
	call	__stack_chk_fail
.L21:
	leave
	.cfi_def_cfa 7, 8
	ret
	.cfi_endproc
.LFE3:
	.size	main, .-main
	.section	.rodata
	.align 8
.LC2:
	.long	0
	.long	1083768832
	.align 8
.LC3:
	.long	0
	.long	1071644672
	.align 8
.LC4:
	.long	2576980378
	.long	1074370969
	.align 8
.LC5:
	.long	0
	.long	1082925056
	.align 8
.LC6:
	.long	3435973837
	.long	1073532108
	.align 8
.LC8:
	.long	0
	.long	1074790400
	.ident	"GCC: (Ubuntu 5.4.0-6ubuntu1~16.04.4) 5.4.0 20160609"
	.section	.note.GNU-stack,"",@progbits
