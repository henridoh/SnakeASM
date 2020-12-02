CC = cc
LD = ld
NASM = nasm
NASMFLAGS = -felf64
CFLAGS = -Wall

Snake: snake.o
	$(LD) $(LDFLAGS) $? -o $@

clean:
	rm -f *.o

snake.o: snake.asm
	$(NASM) $(NASMFLAGS) snake.asm