section .bss
buffer: resb 2048 ;выделил буффер для чтения
string: resb 2048 ;отдельная строка
section .data
f: db '-f', 0   ;ключ '-f' - читать из файла (имя файла после ключа),
                ;иначе читать строку из stdin
n: db '-n', 0   ;ключ '-n' - вывести только количество совпадений
file: db 0      ;файловый дескриптор, устанавливается, если есть ключ '-f'
is_n: db 0
bufflen: dw 2048
grepword: times 255 db 0    ;сюда будет записано слово для поиска
next_string: dq 0       ;указатель на следующую строку
error_msg: db 'An error occurred', 0
section .text
global _start
extern string_equals
extern print_string
extern string_copy
extern string_length
extern print_uint
_start:
    pop r8     ;вытащил количество аргументов командной строки
    cmp r8, 2
    je .simple
    cmp r8, 1
    je .error
    cmp r8, 5
    ja .error
    pop rsi
    mov rsi, rsp
    mov rsi, [rsi]
.n:             ;Есть ли ключ '-n'
    mov rdi, n
    push r8
    call string_equals
    pop r8
    test rax, rax
    jz .check_f
    mov byte[is_n], 1
    dec r8
    cmp r8, 2
    je .simple
.f:
    pop rsi
    mov rsi, rsp
    mov rsi, [rsi]
.check_f:
    mov rdi, f
    push r8
    call string_equals
    pop r8
    test rax, rax
    jz .n_again
    pop rsi
    mov rsi, rsp
    mov rdi, [rsi]
    mov eax, 2
    mov rsi, 0
    mov rdx, 555
    syscall
    test rax, rax
    js .error
    mov byte[file], al
    dec r8
    cmp r8, 2
    je .simple
.n_again:



.error:
    mov eax, 1
    mov edi, 1
    mov rsi, error_msg
    mov rdx, 17
    syscall
    call exit

.simple:    ;тупа выполнение
    mov rax, buffer
    mov qword[next_string], rax
    pop rsi
    mov rsi, rsp
    mov rdi, [rsi]
    call string_length
    mov rsi, grepword
    mov rdx, rax
    call string_copy
    push r12
    push r13
    xor r12, r12
.read:
    xor eax, eax
    mov dl, byte [file] ;дескриптор, откуда читать
    mov rsi, buffer
    mov rdx, bufflen
    syscall
    mov r9, rax
.grep_itself:           ;собсна греп
    mov rdi, buffer
    mov rsi, string
    call divide         ;отделяем следующую строку
    mov rdi, next_string
    sub rdi, buffer
    cmp di, word[bufflen]
    jnb .continue
    mov r13, string
.each_string:           ;ищем по строке
    mov rdi, grepword
    mov rsi, r13
    call contains
    inc r13
    mov rdi, next_string
    sub rdi, buffer
    sub r13, string
    cmp r13, rdi
    je .grep_itself
    add r13, string
    test rax, rax
    jz .each_string
    cmp byte[is_n], 1
    jne .print
    inc r12
    jmp .grep_itself

.print:                     ;пишет строку, в которой нашлось слово
    mov rdi, string
    call print_string
    jmp .each_string
.continue:
    cmp r9, bufflen
    je .read
    cmp byte[is_n], 1
    jne exit
    mov rdi, r12
    call print_uint
    pop r12
exit:           ;выход
    mov rax, 60
    mov rdi, 0
    syscall


contains:               ;принимает слово и строку
	call string_length
	mov  rcx, rax
	xchg rdi, rsi
	push r12
	mov r12, rcx
	dec rdi
.loop:
    inc rdi
    mov rcx, r12
	call string_length
	cmp  rax, rcx
	jb  .false
	call compare
	test rax, rax
    jz  .loop
.true:
	mov rax, 1
	pop r12
    ret
.false:
	mov rax, 0
	pop r12
    ret
compare:
    xchg rdi, rsi
    call string_length
    xchg rdi, rsi
    xor rdx, rdx
.loop:
    cmp rdx, rax
    je .true
    mov r10b, byte[rdi+rdx]
    cmp r10b, byte[rsi+rdx]
    jne .false
    inc rdx
    jmp .loop
.true:
    xor eax, eax
    inc eax
    ret
.false:
    xor eax, eax
    ret


divide:             ;выносит следующую строку в string.
    call line_length    ;Принимает буффер(указатель на начало следующей строки) и строку(куда записать)
    xor rcx, rcx
.loop:
    cmp rcx, rax
    je .ret
    mov dl, byte[rdi+rcx]
    mov byte[rsi+rcx], dl
    inc rcx
    jmp .loop
.ret:
    inc rax
    add qword[next_string], rax
    mov byte[rsi+rax], 0
    ret

line_length:
	xor eax, eax
	.loop:
	  cmp byte[rdi + rax], 0xA
	  je .ret
	  cmp byte[rdi + rax], 0
	  je .ret
	  inc rax
	  jmp .loop
	.ret:
  ret
