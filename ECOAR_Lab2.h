/* ------------------------------------------------------------------------------ -
	author: Gabriel Skowron-Rodriguez
	description: The header of my implementation of project 6.20 "Binary turtle graphics - version 6"
   ------------------------------------------------------------------------------ -
 */

#ifndef ECOAR_LAB2
#define ECOAR_LAB2
#include <iostream>
#include <fstream>
// config START
#define DEBUG_MODE 0 // set to 1 to compile the cpp code in debug mode
// config END
extern "C" int turtle(unsigned char* dest_bitmap, unsigned char* commands, unsigned int commands_size, unsigned char* turtle_attributes); // the assembly function (executes the instructions) //"C" - signifies not to mangle the function name
unsigned char* InitializeDestinationBitmap(); // allocate the memory, fill in the header and initialize all pixels to white
unsigned char* InitializeTurtleAttributes(); // allocate the memory and set the starting turtle parameters
void WriteIntToChar(int integerToWrite, unsigned char* targetCharArray, unsigned int startingChar, unsigned int howManyCharsToWrite); // write a multibyte unsigned integer into chars (Little-endian style) // startingChar - the index of the first char that has to be written

int ReadInstructions(unsigned char* commandsBuffer, int whereToStart); // try to read at most INSTRUCTION_BUFFER_SIZE bytes of instructions into the 'commandsBuffer', returns the number of bytes that have been read
bool SaveBMP(unsigned char* bitmapToSave); // try to save the bitmap to BMP, return true if succeeded

void DebugPrintCharArrayAsInt(unsigned char* charArray, int length); // write an array of chars to std::cout in an integer form

namespace constants
{
	const char* INPUT_FILE = "input_corr.bin";
	const char* OUTPUT_FILE = "output.bmp";
	const int BMP_FILE_SIZE = 90054;
	const int BMP_HEADER_SIZE = 54;
	const int IMAGE_WIDTH = 600;
	const int IMAGE_HEIGHT = 50;
	const int TURTLE_ATTRIBUTES_SIZE = 9; // how many bytes are needed to keep track of the turtle's parameters for the whole program's life
	const int INSTRUCTIONS_BUFFER_SIZE = 100; // should be an even number, not smaller than 4, (because the longest instruction is 4 bytes)
}

namespace userMessages
{
	const char* PROGRAM_START = "Binary Turtle Graphics flavour 6:\n Starting up!\n";
	const char* FINISHED_DRAWING = " Drawing complete. Saving...\n";
	const char* SAVED_TO_FILE = " Picture saved as: ";
	const char* PROGRAM_END = " Shutting down the Binary Turtle Graphics flavour 6\n";
	// error messages
	const char* OPEN_FILE_ERROR = " Error: Unable to open the instructions file: ";
	const char* DISJOINT_SET_POSITION_ENCOUNTERED_1 = " Encountered incomplete \"set_position\" command at the end of the command block (byte no. ";
	const char* DISJOINT_SET_POSITION_ENCOUNTERED_2 = "):\n The next command block will start with executing this \"set_position\" command\n";
	const char* SEVERED_SET_POSITION_ENCOUNTERED_1 = " Error: Encountered incomplete \"set_position\" command at the end of the file (byte no. ";
	const char* SEVERED_SET_POSITION_ENCOUNTERED_2 = "):\n Stopping execution due to the lack of the second word (2 bytes missing?)\n";
}
#endif
