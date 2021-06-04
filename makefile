CPPCOMPILER=g++
ASMBIN=nasm
RUNNABLE=program

all : asm_compile cpp_compile link clean run
asm_compile : 
	$(ASMBIN) -o turtle.o -f elf32 -g -l turtle.lst turtle.asm
cpp_compile :
	$(CPPCOMPILER) -m32 -c -g -O0 ECOAR_Lab2.cpp
link :
	$(CPPCOMPILER) -m32 -g -o program ECOAR_Lab2.o turtle.o
clean :
	rm *.o
	rm *.lst
run :
	./$(RUNNABLE)