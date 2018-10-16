global _start

; Macro         : m_getc 
; Action        : invoke read syscall
; Parameters    : offset
%macro m_getc 1
	mov rax, 0
	mov rdi, 0
	lea rsi, [word_buffer + %1]
	mov rdx, 1
	syscall
%endmacro

; Macro         : multicall
; Action        : call multiple functions
; Parameters    : functions's labels
%macro multicall 1-*
  %rep     %0
	call   %1
	%rotate 1
  %endrep
%endmacro

; Macro         : multipush
; Action        : push arguments to stack
; Parameters    : values
%macro multipop 1-*
  %rep     %0
	push   %1 
	%rotate 1
  %endrep
%endmacro

; Macro         : multipop
; Action        : pop from stack to arguments
; Parameters    : registers, addresses
%macro multipush 1-*
  %rep     %0
	pop    %1 
	%rotate 1
  %endrep
%endmacro

%define ASCII_H_F 0x21 ; first readable ASCII symbol's code 
%define ASCII_N_F 0x30 ; first ASCII number symbol's code
%define ASCII_N_L 0x39 ; last  ASCII number symbol's code


section .data
	word_buffer : times 255 db 0
section .text
global print_string
global string_equals
global string_copy
global string_length
global print_uint
global print_newline

; Function    : string_length
; Parameters  :	rdi -- pointer to input string
; Side effects: nothing
; Returns     : rax -- input string's length
string_length:
	xor eax, eax
	.loop:
	  cmp  byte[rdi + rax], 0
	  je   .ret
	  inc  rax
	  jmp  .loop	  
	.ret:
  ret

; Function    :	print_string
; Parameters  :	rdi -- pointer to input string
; Side effects: string to stdout
;				unsaved:	rax, rcx, rdx, rdi, r11
; Returns	  :	nothing
print_string:
	call string_length
	mov  rdx, rax
	mov  rsi, rdi
	mov  rax, 1
	mov  rdi, 1
	syscall
  ret

; Function    :	print_char
; Parameters  :	rdi -- pointer to char
; Side effects: char to stdout
;				unsaved:	rax, rcx, rdx, rdi, r11
; Returns	  :	nothing
print_char:
	dec rsp
	mov byte[rsp], dil
	mov rsi, rsp
	mov rax, 1
	mov rdi, 1
	mov rdx, 1
	syscall
	inc rsp
  ret

; Function	  :	print_newline
; Parameters  : nothing
; Side effects: \n to stdout
;				unsaved:	rax, rdi, rdx, rsi, rdi, rcx, r11
; Returns	  :	nothing
print_newline:
	mov edi, 10 
	jmp print_char

; Function    :	print_uint
; Parameters  :	rdi -- unsigned int
; Side effects:	unsigned int to stdout
;				unsaved:	rax, rcx, rdx, rdi, rsi
; NOTE		  :	buffer in the stack			
; Returns	  :	nothing
print_uint:
	push rbp
	mov  rbp, rsp
	mov  rax, rdi
	mov  rdi, 10
	sub  rsp, 21
	dec  rbp
	mov  byte[rbp], 0
	.loop:
	  dec  rbp
	  xor  rdx, rdx
	  div  rdi
	  add  rdx, ASCII_N_F
	  mov  byte[rbp], dl
	  test rax, rax
	  jnz  .loop
	mov rdi, rbp
	call print_string
	add rsp, 21
	pop rbp
  ret
	
; Function    :	print_int
; Parameters  :	rdi -- signed int
; Side effects:	signed int to stdout
;				unsaved:	rax, rcx, rdx, rdi, rsi
; NOTE		  :	buffer in the stack			
; Returns	  :	nothing
print_int:
	test rdi, rdi
	jns  .pos
	push rdi
	mov  edi, '-'
	call print_char
	pop  rdi
	neg  rdi
 .pos:
	jmp  print_uint

; Function	  : read_char
; Parameters  : none
; Side effects: unsaved:	rax, rdi, rsi
; Returns	  : rax -- char
read_char:
	dec rsp
	xor eax, eax
	xor edi, edi
	mov rsi, rsp
	mov rdx, 1
	syscall
	mov rax, [rsp]
	inc rsp
  ret

; Function    :	read_word
; Parameters  :	none
; Side effects:	unsaved:	rcx, rdi, rsi
; NOTE		  :	ignores ' ', '\t', '\n' and non-readable symbols
; Returns	  :	rax -- pointer to buffer; rdx -- word's length
read_word:
	push rbx
	xor  rbx, rbx
	xor  edi, edi
	mov  rdx, 1
	.skip:
	  xor eax, eax
	  mov rsi, word_buffer
	  syscall
      cmp al, 0
      je  .finally
      xor eax, eax
	  cmp byte [word_buffer], ASCII_H_F
	  jb  .skip
	inc rbx
	.read:
	  xor eax, eax
	  lea rsi, [word_buffer + rbx]
	  syscall
	  cmp byte [word_buffer + rbx], ASCII_H_F
	  jb  .finally
	  inc rbx
	  jmp .read
  .finally:
	mov byte[word_buffer + rbx], 0
	mov rdx, rbx
	mov rax, word_buffer
	pop rbx
  ret

; Function    :	parse_uint
; Parameters  :	rdi -- pointer to input string
; Side effects:	unsaved:	rax, rcx, rdx, rdi, rsi
; Returns	  :	rax -- parsed unsigned number; 
;               rdx -- (length . show) number
parse_uint:
	call string_length
	mov rcx, rax
	mov rsi, rdi
	xor edx, edx
	xor eax, eax
	.parsing:
	  xor  edi, edi
	  mov  dil, byte[rsi + rdx]
	  cmp  dil, ASCII_N_F
	  jb   .finally
	  cmp  dil, ASCII_N_L
	  ja   .finally			; not digit
	  sub  dil, ASCII_N_F
	  imul rax, 10
	  add  rax, rdi
	  inc  rdx
	  dec  rcx
	  jnz  .parsing					; end of input string's length
	.finally:
  ret
	  
; Function    :	parse_int
; Parameters  :	rdi -- pointer to input string
; Side effects:	unsaved:	rax, rcx, rdx, rdi, rsi
; Returns	  :	rax -- parsed signed number; 
;             : rdx -- (length . show) number;
parse_int:
	cmp byte[rdi], '-'
	je  .signed
	jmp parse_uint
  .signed:
	inc  rdi
        call parse_uint
	test rdx, rdx
	jz   .empty
	neg  rax
	inc  rdx
  ret
  .empty:
	xor eax, eax
  ret

; Function    : string_equals
; Parameters  :	rdi -- pointer to first  string
;               rsi -- pointer to second string
; Side effects:	unsaved:	rax, rcx, rdx, rdi, rsi
; Returns	  :	rax -- true(1) or false(0)
string_equals:
	call string_length
	mov  rcx, rax
	xchg rdi, rsi
	call string_length
	cmp  rax, rcx
	jne  .false
	repe cmpsb
    jne  .false
  .true:
	mov rax, 1
  ret
  .false:
	mov rax, 0
  ret

; Function    : string_copy
; Parameters  :	rdi -- pointer to source      string
;               rsi -- pointer to destination string
; Side effects:	unsaved:	rax, rcx, rdx, rdi, rsi
; Returns	  :	none
string_copy:
	call string_length
        mov  rcx, rax
        inc  rcx
        xchg rsi, rdi
        mov  byte[rdi + rax], 0
        rep  movsb
  ret		
