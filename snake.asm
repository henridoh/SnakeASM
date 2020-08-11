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

  endofline   db 27, '[0m', '║', 10, 27, '[u', 27, '[1B', 0
  startofline db 27, '[0m', 27, '[s', '║', 0
  top				db '╔'
						times (fieldwidth-4) db '═'
					  db 27, '[32m', 'SnakeASM', 27, '[0m'
						times (fieldwidth-4) db '═'
    	      db '╗', 10, 0
  
  bottom    db '╚'
    	      times (fieldwidth*2) db '═'
    	      db '╝', 0


  lenmessage  db 10, 27, '[0m', 'Score: ', 0
  newline     db 27, '[0m', 10, 0

  gameover    db 'Game Over!', 0

  up		      db 27, '[A', 0
  down	      db 27, '[B', 0
  left	      db 27, '[C', 0
  right	      db 27, '[D', 0

section .data
  snakeposx   dw 3
  snakeposy   dw 3
  movx	      dw 0
  movy	      dw 0
  hasmoved    db 0
  
  isgameover  db 0

  snakelen    dw startlen

  applepos    dw 0

  sleeptime:
    .s dq 0
    .n dq 125000000

  fd  dd 0
  eve dw 1
  rev dw 0
  sym db 1

	screenbuffer:
		.buffer times (fieldsize * 5) db 0
		.end		db 0
		.pos		dw 0

section .bss
  buffer    resb 128

  stty	  resb 12
  slflag  resb 4
  srest	  resb 44
  tty			resb 12
  lflag	  resb 4
  brest	  resb 44

  field	    resw fieldsize


section .text
  global _start

_start:
	rdtsc
  xor rdx, rdx
  mov rbx, fieldwidth
  div rbx
  mov word[snakeposx], dx
  rdtsc
  xor rdx, rdx
  mov rbx, fieldheight
  div rbx
  mov word[snakeposy], dx


  call setnoncan
  call newapplepos
  mainloop:
    call update
    call sleep

    jmp mainloop

exit:
  call setcan
  mov rsi, newline
  call print.buffer
  mov rsi, gameover
  call print.buffer
  mov rsi, lenmessage
  call print.buffer
  xor rax, rax
  mov ax, [snakelen]
  sub rax, startlen
  call print.numberbuf
  mov rsi, newline
  call print.buffer
  call print.flush

  mov rax, 60
  mov rdi, 0
  syscall

update:
  cmp word[snakeposx], fieldwidth   ; check if snake is dead
  je .dead
  cmp word[snakeposx], -1
  je .dead
  cmp word[snakeposy], fieldheight
  je .dead
  cmp word[snakeposy], -1
  je .dead

  jmp .noexit
  .dead:
  mov byte[isgameover], 2

  .noexit:

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
  call print.buffer

  mov rsi, top
  call print.buffer

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
    call print.buffer
    .nostartline:


    mov ax, [snakeposy]	  ; calculate abs snake pos and put in r11
    mov r11w, fieldwidth
    mul r11w
    mov r11w, [snakeposx]
    add r11w, ax

    cmp r8w, r11w	  ; if snake head on current position
    jne .nohead
      cmp word[r10], 0  	  ; if snake has eaten itself
      je .hneh
  
      cmp byte[hasmoved], 1   ; and has moved aleready
      sete byte[isgameover]   ; set game over

    .hneh:    ; put snake body on head position
    mov ax, [snakelen]
    mov word[r10], ax

    .nohead:
    cmp word[r10], 0	  ; if snake body on current position
    je .nosnake
      dec word[r10]	  ; then print snake symbol (*) and decrease lifespan
      mov rsi, snakesymbol
      call print.buffer
    jmp .snake
    .nosnake:		  ; else
      cmp r8w, [applepos]	  ; if apple on current position
      jne .noapple
      mov rsi, applesymbol  ; then print apple symbol
      call print.buffer
    jmp .snake

    .noapple:
    mov rsi, clearsymbol  ; else print whitespace
    call print.buffer

    .snake:
    add r10, 2		  ; inc r10 to next word // next cell

    cmp r9, fieldwidth-1  ; if end of line reached
    jne .noendline
    mov rsi, endofline	  ; then print '|\n'
    call print.buffer
    mov r9, -1

    .noendline:
    inc r9
    inc r8
    jmp .loop
  

  .end:			  ; print score
    mov rsi, bottom
    call print.buffer

    cmp byte[isgameover], 0   ; if game over is set
    jne exit                  ; go to exit

    mov rsi, lenmessage       ; print length
    call print.buffer
    xor rax, rax
    mov ax, [snakelen]
    sub ax, startlen
    call print.numberbuf
    mov rsi, newline
    call print.buffer
		call print.flush          ; flush print buffer
    ret

sleep:			  ; sleep $sleeptime
  mov rax, 35
  mov rdi, sleeptime
  mov rsi, 0
	mov rdx, 0
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

	.buffer:
		push r9
		push r10
		push r11
		push rsi

		xor r9, r9

		mov r11, screenbuffer
		xor r10, r10
		mov r10w, word[screenbuffer.pos]
		add r11, r10
		.bloop:
			cmp byte[rsi], 0
			je .bend

			mov r9b, byte[rsi]
			mov byte[r11], r9b
			inc r11
			inc word[screenbuffer.pos]
			inc rsi
			jmp .bloop

		.bend:
			mov word[r11], 0

			pop rsi
			pop r11
			pop r10
			pop r9
			ret

	.flush:
		mov rsi, screenbuffer
		call print
		xor rax, rax
		mov ax, word[screenbuffer.pos]
		mov word[screenbuffer.pos], 0
		ret
	
	.numberbuf:
    mov rsi, buffer
    add rsi, 128
    mov byte[rsi], 0

    .nloop:
      dec rsi
      
      xor rdx, rdx
      mov rbx, 10
      div rbx
      xor dl, 48
      mov [rsi], dl
      cmp rax, 0
			jne .nloop
    .nout:
      call print.buffer
      ret


newapplepos:
  rdtsc
  xor rdx, rdx
  mov rbx, fieldsize
  div rbx
  mov r12, field
  add r12, rdx
  add r12, rdx
  cmp word[r12], 0
  jne newapplepos

  .eq:
    mov word[applepos], dx
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
