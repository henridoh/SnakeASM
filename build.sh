#!/bin/bash
nasm -felf64 snake.asm
ld -m elf_x86_64 snake.o -o Snake
strip Snake --strip-all
rm snake.o
