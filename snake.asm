fieldwidth  equ 30
fieldheight equ 20
startlen    equ 3



ICANON	equ 2
ECHO	equ 8

section .rodata
  fieldsize   equ fieldwidth * fieldheight


  snakesymbol db 27, '[32m', ' *', 0
  applesymbol db 27, '[31m', ' O', 0
  clearsymbol db '  ', 0

  clearscreen db 27, '[0m', 27, '[2J', 27, '[0;0f', 0

  endofline   db 27, '[37;30m', '|', 10, 27, '[u', 27, '[1B', 0
  startofline db 27, '[37;30m', 27, '[s', '|', 0

  testmessage db 'Hello World!', 10, 0

  lenmessage  db 27, '[0m', 'Score: ', 0
  newline     db 27, '[0m', 10, 0

  gameover    db 'Game Over!', 10, 0

  up	      db 27, '[A', 0
  down	      db 27, '[B', 0
  left	      db 27, '[C', 0
  right	      db 27, '[D', 0

  s1 db "asdf", 10, 0
  s2 db "asdf", 10, 0

section .data
  snakeposx   dw 3
  snakeposy   dw 3
  movx	      dw 0
  movy	      dw 0
  hasmoved    db 0

  snakelen    dw startlen

  applepos    dw 0

  sleeptime:
    .s dq 0
    .n dq 150000000

  fd  dd 0
  eve dw 1
  rev dw 0
  sym db 1

section .bss
  buffer    resb 128

  stty	  resb 12
  slflag  resb 4
  srest	  resb 44
  tty	  resb 12
  lflag	  resb 4
  brest	  resb 44

  field	    resw fieldsize


section .text
  global _start

_start:
  call setnoncan
  call newapplepos
  mainloop:
    call update
    call sleep

    jmp mainloop

exit:
  call setcan
  mov rsi, newline
  call print
  mov rsi, gameover
  call print
  mov rsi, lenmessage
  call print
  xor rax, rax
  mov ax, [snakelen]
  sub rax, startlen
  call print.number
  mov rsi, newline
  call print

  mov rax, 60
  mov rdi, 0
  syscall

update:
  cmp word[snakeposx], fieldwidth   ; check if snake is dead
  je exit
  cmp word[snakeposx], -1
  je exit
  cmp word[snakeposy], fieldheight
  je exit
  cmp word[snakeposy], -1
  je exit

  call poll		; exit when 'q' is pressed
  cmp al, 'q'
  je exit
			; controll snake:
  mov rax, buffer	; switch case through possible key presses

  switch:
  mov rsi, up
  call strcmp
  je .up
  mov rsi, down
  call strcmp
  je .down
  mov rsi, left
  call strcmp
  je .left
  mov rsi, right
  call strcmp
  je .right
  jmp endswitch
  .up:
    mov word[movx], 0
    mov word[movy], -1
    jmp .end
  .down:
    mov word[movx], 0
    mov word[movy], 1
    jmp .end
  .left:
    mov word[movx], 1
    mov word[movy], 0
    jmp .end
  .right:
    mov word[movx], -1
    mov word[movy], 0

  .end:
  mov byte[hasmoved], 1
  endswitch:	    ; controll end


  mov r8, 0	; pos counter // for counter
  xor r9, r9	; line counter
  mov r10, field; field pointer

  mov r11w, [movx]	; mov snake
  add [snakeposx], r11w
  mov r11w, [movy]
  add [snakeposy], r11w

  mov rsi, clearscreen	; clear screen
  call print

  xor r11, r11

  mov ax, [snakeposy]	; calc snake pos
  mov r11w, fieldwidth
  mul r11w
  mov r11w, [snakeposx]
  add r11w, ax
  cmp r11w, [applepos]
  jne .noappleeaten
  inc word[snakelen]

  call newapplepos
  .noappleeaten:

  .loop:
    cmp r8, fieldsize 
    je .end

    cmp r9, 0		  ; if start of line
    jne .nostartline
    mov rsi, startofline  ; print '|'
    call print
    .nostartline:


    mov ax, [snakeposy]	  ; calculate abs snake pos and put in r11
    mov r11w, fieldwidth
    mul r11w
    mov r11w, [snakeposx]
    add r11w, ax

    cmp r8w, r11w	  ; if snake head on current position
    jne .nohead
    cmp word[r10], 0	  ; if snake has eaten himself
    je .hneh
    cmp byte[hasmoved], 1 ; and has moved aleready
    je exit		  ; then exit

    .hneh:
    mov ax, [snakelen]
    mov word[r10], ax

    .nohead:
    cmp word[r10], 0	  ; if snake body on current position
    je .nosnake
    dec word[r10]	  ; then print snake symbol (*) and decrease lifespan
    mov rsi, snakesymbol
    call print
    jmp .snake
    .nosnake:		  ; else
    cmp r8w, [applepos]	  ; if apple on current position
    jne .noapple
    mov rsi, applesymbol  ; then print apple symbol
    call print
    jmp .snake
    .noapple:
    mov rsi, clearsymbol  ; else print whitespace
    call print
    .snake:
    add r10, 2		  ; inc r10 to next word // next cell

    cmp r9, fieldwidth-1  ; if end of line reached
    jne .noendline
    mov rsi, endofline	  ; then print '|\n'
    call print
    mov r9, -1

    .noendline:
    inc r9
    inc r8
    jmp .loop
  

  .end:			  ; print score
    mov rsi, lenmessage
    call print
    xor rax, rax
    mov ax, [snakelen]
    sub ax, startlen
    call print.number
    mov rsi, newline
    call print
    ret

sleep:			  ; sleep $sleeptime
  mov rax, 35
  mov rdi, sleeptime
  mov rsi, 0
  syscall
  ret

print:
  push rax
  push rdi
  push rdx
  push rcx

  push rsi
  xor rdx, rdx

  .getlen:
    cmp byte[rsi], 0
    je .out
    inc rdx
    inc rsi
    jmp .getlen
  .out:

    pop rsi
    mov rax, 1
    mov rdi, 1

    syscall
    pop rcx
    pop rdx
    pop rdi
    pop rax
  ret

  .number:
    mov rsi, buffer
    add rsi, 128
    mov byte[rsi], 0

    .nloop:
      cmp rax, 0
      je .nout
      dec rsi
      
      xor rdx, rdx
      mov rbx, 10
      div rbx
      xor dl, 48
      mov [rsi], dl
      jmp .nloop
    .nout:
      call print
      ret


newapplepos:
  rdtsc
  xor rdx, rdx
  mov rbx, fieldsize
  div rbx
  mov [applepos], dx
  ret

strcmp:
  push rax
  push rsi
  push r8
  xor r8, r8
  .loop:
    cmp byte[rax], 0
    je .e

    mov r8b, [rsi]
    cmp [rax], r8b
    jne .ne
    inc rax
    inc rsi
    jmp .loop

  .e:
    cmp byte[rsi], 0
    jne .ne
    pop r8
    pop rsi
    pop rax
    cmp rax, rax
    ret

  .ne:
    pop r8
    pop rsi
    pop rax
    cmp rax, 0
    ret




poll:
  mov qword[buffer], 0
  push rbx
  push rcx
  push rdx
  push rdi
  push rsi
  mov rax, 7; the number of the poll system call
  mov rdi, fd; pointer to structure
  mov rsi, 1; monitor one thread
  mov rdx, 0; do not give time to wait
  syscall
  test rax, rax; check the returned value to 0
  jz .e
  mov rax, 0
  mov rdi, 0; if there is data
  mov rsi, buffer; then make the call read
  mov rdx, 3
  syscall
  xor rax, rax
  mov al, byte [buffer]; return the character code if it was read
  .e:
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret


setnoncan:
  push stty
  call tcgetattr
  push tty
  call tcgetattr
  and dword[lflag], (~ ICANON)
  and dword[lflag], (~ ECHO)
  call tcsetattr
  add rsp, 16
  ret

setcan:
        push stty
        call tcsetattr
        add rsp, 8
        ret

tcgetattr:
  mov rdx, qword [rsp+8]
  push rax
  push rbx
  push rcx
  push rdi
  push rsi
  mov rax, 16; ioctl system call
  mov rdi, 0
  mov rsi, 21505
  syscall
  pop rsi
  pop rdi
  pop rcx
  pop rbx
  pop rax
  ret

tcsetattr:
  mov rdx, qword [rsp+8]
  push rax
  push rbx
  push rcx
  push rdi
  push rsi
  mov rax, 16; ioctl system call
  mov rdi, 0
  mov rsi, 21506
  syscall
  pop rsi
  pop rdi
  pop rcx
  pop rbx
  pop rax
  ret
