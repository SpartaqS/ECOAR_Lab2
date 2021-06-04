// ECOAR_Lab2.h: plik dołączany dla standardowych systemowych plików dołączanych,
// lub pliki dołączane specyficzne dla projektu.

#ifndef ECOAR_LAB2
#define ECOAR_LAB2
#include <iostream>
#include <fstream>


extern "C" int turtle(unsigned char* dest_bitmap, unsigned char* commands, unsigned int commands_size, unsigned char* turtle_attributes); // the assembly function (executes the instructions) "C" - signifies not to mangle the function name
unsigned char* InitializeDestinationBitmap(); // allocate the memory, fill in the header and initialize all pixels to white
unsigned char* InitializeTurtleAttributes(); // allocate the memory and set the starting turtle parameters
void WriteIntToChar(int integerToWrite, unsigned char* targetCharArray, unsigned int startingChar, unsigned int howManyCharsToWrite); // write a multibyte unsigned integer into chars (Little-endian style) // startingChar - the index of the first char that has to be written

int ReadInstructions(unsigned char* commandsBuffer, int whereToStart); // try to read at most INSTRUCTION_BUFFER_SIZE bytes of instructions into the 'commandsBuffer', returns the number of bytes that have been read
bool SaveBMP(unsigned char* bitmapToSave); // try to save the bitmap to BMP, return true if succeeded

namespace constants
{
	const int BMP_FILE_SIZE = 90054;
	const int BMP_HEADER_SIZE = 54;
	const int IMAGE_WIDTH = 600;
	const int IMAGE_HEIGHT = 50;
	const int TURTLE_ATTRIBUTES_SIZE = 9; // how many bytes are needed to keep track of the turtle's parameters for the whole program's life
	const int INSTRUCTIONS_BUFFER_SIZE = 100; // should be an even number, not smaller than 4, (because the longest instruction is 4 words long)
}

#endif
// TODO: W tym miejscu przywołaj dodatkowe nagłówki wymagane przez program.
