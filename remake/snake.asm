; - Constants -
SIZE_X equ 20
SIZE_Y equ 20

STARTLEN equ 1
; SIZE parameters must not be 0

section .text
  global _start

_start:
  call set_non_canonical_mode
  call main
gameover:
  call set_canonical_mode
  mov rsi, GAMEOVER_MESSAGE
  call print
  jmp exit

exit:
mov rax, 0x3c
mov rdi, 0
syscall

; - Subroutines -
main:
  ; enter
  push rbp
  mov rbp, rsp

  ; set up stack frame for field memory
  sub rsp, SIZE_X * SIZE_Y * 8 + 8
  mov rsi, rsp
  mov qword[field_pointer], rsi

  mov rcx, rsp
  .clear_stack:
    mov qword[rcx], 0
  add rcx, 8
  cmp rcx, rbp
  jne .clear_stack

  sub rsp, 8
  mov qword[input_buffer], rsp
  mov byte[rsp+3], 0 ; \0 to end string in buffer

  ; cear stack frame

  
  gameloop:
    ; process user input
    call process_input
    mov rsi, [input_buffer]
      ; if/else through possilbe button presses:
      mov rax, DIRECTIONS.up
      call stringcmp
      jne .not_up
      mov qword[snake_vel], -SIZE_X
      .not_up:
      mov rax, DIRECTIONS.down
      call stringcmp
      jne .not_down
      mov qword[snake_vel], SIZE_X
      .not_down:
      mov rax, DIRECTIONS.left
      call stringcmp
      jne .not_left
      mov qword[snake_vel], -1
      .not_left:
      mov rax, DIRECTIONS.right
      call stringcmp
      jne .not_right
      mov qword[snake_vel], 1
      .not_right:

    ; clear screen
    mov rsi, CLEAR_SCREEN
    call print

    ; draw top border frame
      mov rsi, BORDER_PIECES.tl
      call print

      mov rsi, BORDER_PIECES.ho
      mov rcx, (SIZE_X * 2 - TITLE.len + 1) / 2
      .draw_top_border_left:
        call print
      dec rcx
      jnz .draw_top_border_left

      mov rsi, TITLE
      call print

      mov rsi, BORDER_PIECES.ho
      mov rcx, (SIZE_X * 2 - TITLE.len + 1) / 2
      .draw_top_border_right:
        call print
      dec rcx
      jnz .draw_top_border_right

      mov rsi, BORDER_PIECES.tr
      call print

    ;check if apple was eaten
    mov rax, [snake_pos]
    cmp [apple_pos], rax
    jne .no_apple_eaten
    inc qword[snake_len]

    rdtsc
    xor rdx, rdx
    mov r8, SIZE_X * SIZE_Y
    div r8
    mov [apple_pos], rdx
    .no_apple_eaten:

    ; iterate over each field
    mov rsi, BORDER_PIECES.vl
    call print

    mov rcx, 0 ; column counter
    mov r8, [field_pointer]
    mov r9, 0 ; field counter

    .update:
      cmp rcx, SIZE_X
      jne .no_newline
      .on_newline:
        mov rsi, BORDER_PIECES.vl
        call print
        mov al, 0xa ; print newline
        call print.character
        call print

        mov rcx, 0
      .no_newline:

      ; if snake head on curren positon: set snake body on current position
      cmp r9, [snake_pos]
      jne .no_snake_head_here

      mov rax, [r8]
      test rax, rax ; death-condition 1: if snake runs into own body
      jz .not_game_over_s

      mov al, byte[hasmoved] ; if snake hasnt moved yet it cant die
      test al, al
      jz .not_game_over_s
      mov byte[isgameover], 1

      .not_game_over_s:


      mov rax, [snake_len]
      mov [r8], rax
      .no_snake_head_here:

      ; check if snake body on current position
      mov rax, [r8]
      cmp rax, 0
      je .no_snake_body
      ; draw Snake body
      mov rsi, SNAKE_SIGN
      call print

      dec qword[r8]
      jmp .continue_loop
      .no_snake_body:

      ; draw apple
      cmp r9, [apple_pos]
      jne .no_apple
      mov rsi, APPLE_SIGN
      call print
      jmp .continue_loop

      ; draw whitespace
      .no_apple:
      mov rsi, EMPTY_SIGN
      call print


      .continue_loop:
      ; increase counters
      add r8, 8
      inc r9
      inc rcx

      mov rax, qword[field_pointer]
      add rax, SIZE_X * SIZE_Y * 8
      cmp r8, rax
      jne .update
  
    ; draw last vertical border peace
    mov rsi, BORDER_PIECES.vl
    call print
    mov al, 0xa
    call print.character

    ; draw bottom border frame
    mov rsi, BORDER_PIECES.bl
    call print
    mov rsi, BORDER_PIECES.ho
    mov rcx, SIZE_X * 2
    .draw_bottom_border:
      call print
    dec rcx
    jnz .draw_bottom_border
    mov rsi, BORDER_PIECES.br
    call print

    ; Display current Score
    mov rsi, SCORE_MESSAGE
    call print
    mov rax, [snake_len]
    call print.number

    cmp byte[isgameover], 0
    jnz gameover


    mov r12, [snake_vel]
    ; check for other death conditions
    mov rax, [snake_pos]
    
    ; divide snake pos into x and y
    mov rbx, SIZE_X
    xor rdx, rdx
    div rbx
    mov r13, rax
    mov r14, rdx

    ; now pos_x is in r14 and pos_y is in r13

    cmp r14, SIZE_X -1 
    jne .did_not_run_into_right_wall
    cmp r12, 1
    jnz .did_not_run_into_right_wall
    mov byte[isgameover], 1
    .did_not_run_into_right_wall:

    cmp r14, 0
    jne .did_not_run_into_left_wall
    cmp r12, -1
    jnz .did_not_run_into_left_wall
    mov byte[isgameover], 1
    .did_not_run_into_left_wall:

    cmp r13, SIZE_Y -1 
    jne .did_not_run_into_bottom_wall
    cmp r12, SIZE_Y
    jnz .did_not_run_into_bottom_wall
    mov byte[isgameover], 1
    .did_not_run_into_bottom_wall:

    cmp r13, 0
    jne .did_not_run_into_top_wall
    cmp r12, -SIZE_Y
    jnz .did_not_run_into_top_wall
    mov byte[isgameover], 1
    .did_not_run_into_top_wall:


    ; move snake head
    add [snake_pos], r12

    test r12, r12
    jz .snake_has_not_moved_yet
    mov byte[hasmoved], 1
    .snake_has_not_moved_yet:

    call sleep
    jmp gameloop


  ; leave
  mov rsp, rbp
  pop rbp
  ret

print:
  push rax
  push rdi
  push rdx
  push rcx

  push rsi
  
  xor rdx, rdx
  .get_string_len:
    lodsb
    cmp al, 0
    je .output_string
    inc rdx
    jmp .get_string_len

  .output_string:
  pop rsi
  mov rax, 0x1
  mov rdi, 0x1
  syscall

  pop rcx
  pop rdx
  pop rdi
  pop rax
  ret

  .character:
    push rax
    push rsi

    and rax, 0x000000ff
    push rax
    mov rsi, rsp
    call print

    add rsp, 8

    pop rsi
    pop rax
    ret

  .number:
    push rax
    push rdx
    push rbx
    push rsi

    ; enter
    push rbp
    mov rbp, rsp

    dec rsp
    mov byte[rsp], 0

    mov rbx, 0xa
    .get_digits:
      xor rdx, rdx
      div rbx

      or dl, '0'
      dec rsp
      mov [rsp], dl
      cmp rax, 0
      jne .get_digits

    mov rsi, rsp
    call print

    ; leave
    mov rsp, rbp
    pop rbp

    pop rsi
    pop rbx
    pop rdx
    pop rax
    ret

; pauses the game between frames
sleep:
  push rax
  push rdi
  push rsi
  mov rax, 0x23 ; nanosleep syscall
  mov rdi, SLEEPTIME
  xor rsi, rsi
  syscall
  pop rsi
  pop rdi
  pop rax


; tcgetattr gets Terminal controll information and writes it into [rdx]
tcgetattr:
  push rax
  push rbx
  push rdi
  push rsi

  mov rax, 0x10 ; ioctl system call
  mov rdi, 0x00 ; stdin fd
  mov rsi, 0x5401 ; tcgetattr request id
  syscall

  pop rsi
  pop rdi
  pop rbx
  pop rax
  ret

; tcsetattr set Terminal attributes found in [rdx] (type: struct termios)
tcsetattr:
  push rax
  push rbx
  push rdi
  push rsi

  mov rax, 0x10 ; ioctl system call
  mov rdi, 0x00 ; stdin fd
  mov rsi, 0x5402 ; tcsetattr
  syscall

  pop rsi
  pop rdi
  pop rbx
  pop rax
  ret

set_non_canonical_mode:
  push rdx
  push rbp
  mov rbp, rsp

  add rsp, 60 + 8 ; create stackframe with len(struct termios)
  mov rdx, rsp

  ; unset the ICANON bit in tc attributes
  call tcgetattr
  and dword[rdx+12], (~0xa) ; ; 2 = flag addr for ICANON 8 = flag addr for ECHO
  call tcsetattr

  ; leave
  mov rsp, rbp
  pop rbp
  pop rdx
  ret

set_canonical_mode:
  push rdx
  push rbp
  mov rbp, rsp

  add rsp, 60 + 8 ; create stackframe with len(struct termios)
  mov rdx, rsp

  ; unset the ICANON bit in tc attributes
  call tcgetattr
  or dword[rdx+12], 0xa ; 2 = flag addr for ICANON 8 = flag addr for ECHO
  call tcsetattr

  ; leave
  mov rsp, rbp
  pop rbp
  pop rdx
  ret

; cmp string in rsi with string in rax
stringcmp:
  push rax
  push rbx
  push rsi

  mov rbx, rax
  .loop:
    lodsb
    cmp al, byte[rbx]
    jne .not_equal

    inc rbx
    or al, al
    jnz .loop

  .equal:
  pop rsi
  pop rbx
  xor rax, rax ; set ZF=1
  pop rax
  ret

  .not_equal:
  pop rsi
  pop rbx
  pop rax
  cmp rax, 0 ; set ZF=0
  ret

process_input:
  push rax
  push rbx
  push rdi
  push rsi
  push rdx

  ; Poll syscall waits for an event in a file
  mov rax, 7 ; poll syscall
  mov rdi, POLLFD ; pointer to struct POLLFD (contains fd and events to listen for)
  mov rsi, 1 ; nfds, number of items in struct pollfd[] (stored in rdi)
  mov rdx, 0 ; number of ms poll() waits for an update
             ; set to 0 since sleep is implemented elsewhere (nanosleep)
  syscall

  test rax, rax
  jz .no_update_to_sysin

  ; update POLLIN detected: sysin was written to    
  mov rax, 0 ; sys_read
  mov rdi, 0 ; sysin
  mov rsi, [input_buffer]
  mov rdx, 3 ; max input len
  syscall
  
  .no_update_to_sysin:
  pop rdx
  pop rsi
  pop rdi
  pop rbx
  pop rax
  ret

section .rodata
  TITLE db "SnakeASM", 0
    .len equ 8
  
  SCORE_MESSAGE db "Score: ", 0
  GAMEOVER_MESSAGE db 10, "Game Over!", 10, 0

  BORDER_PIECES:
    .tl db "╔", 0
    .tr db "╗", 10, 0
    .bl db "╚", 0
    .br db "╝", 10, 0
    .ho db "═", 0
    .vl db "║", 0
  SNAKE_SIGN db "* ", 0
  APPLE_SIGN db "O ", 0
  EMPTY_SIGN db "  ", 0

  CLEAR_SCREEN db 27, "[2J", 27, "[0;0H", 0

  SLEEPTIME:
    .s dq 0
    .n dq 120000000

  DIRECTIONS:
    .up     db 27, "[A", 0
    .down   db 27, "[B", 0
    .right  db 27, "[C", 0
    .left   db 27, "[D", 0

section .data
  snake_len dq 3
  apple_pos dq 106
  snake_pos dq 5 + SIZE_X * 5
  has_apple db 0
  field_pointer dq 0
  input_buffer dq 0
  snake_vel dq 0
  isgameover db 0
  hasmoved db 0

  POLLFD:
    .fd      dd 0 ; sysin
    .events  dw 1 ; requested events (write to file / POLLIN)
    .revents dw 0 ; returned events
