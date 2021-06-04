/* example.c */

#include "ECOAR_Lab2.h"

//extern "C" int turtle(unsigned int dest_bitmap, unsigned int commands, unsigned int commands_size); // "C" - signifies to not mangle the function name

int main()
{
	bool reachedEndOfFile = false;

	unsigned char* destinationBitmap = InitializeDestinationBitmap();
	unsigned char* commands = new unsigned char[constants::INSTRUCTIONS_BUFFER_SIZE];
	unsigned char* turtle_attributes = InitializeTurtleAttributes(); // used store the turtle arguments between turtle() calls (non-compressed)
	int commandsSize = 0;
	int nextCommandToRead = 0;
	
	while (!reachedEndOfFile)
	{
		commandsSize = ReadInstructions(commands, nextCommandToRead);
		if (commandsSize > 0)
		{
			nextCommandToRead += commandsSize; // so we know where to start reading next time
			std::cout << "Turtle Commands ( " << commandsSize << " total ) :";
			for (int i = 0; i < commandsSize; i++)
			{
				std::cout << (int)commands[i] << " ";
			}

			std::cout << "\n";

			std::cout << "Turtle attributes :" << turtle_attributes << "\n";
			std::cout << "Turtle starting:\n";
			int turtleResult = turtle(destinationBitmap, commands, commandsSize, turtle_attributes);
			std::cout << "Turtle finishing with result: " << turtleResult << "\n";
			std::cout << "Turtle attributes :" << turtle_attributes << "\n";

			if (turtleResult == -1) // detected a two-word command that was cut in half
			{
				if (commandsSize > 2 && commandsSize < constants::INSTRUCTIONS_BUFFER_SIZE)// if we are reading more than one word at a time and the set_position command was cut in half (is at the end of the buffer)
				{
					nextCommandToRead -= 2; // read the severed set_position command as the first one in the next batch of instructions
				}
				else
				{
					reachedEndOfFile = true; // the first word of the set_position command was at the end of the file: we should ignore it
				}
			}
		}
		else
		{
			reachedEndOfFile = true;
		}
	}

	SaveBMP(destinationBitmap);

	delete destinationBitmap;
	delete commands;
	delete turtle_attributes;
	return 0;
}

unsigned char * InitializeDestinationBitmap()
{
	unsigned char * initializedBitmap = new unsigned char[constants::BMP_FILE_SIZE];

	// header initialization
	initializedBitmap[0] = 'B';
	initializedBitmap[1] = 'M';
	WriteIntToChar(constants::BMP_FILE_SIZE, initializedBitmap, 2, 4); // file size
	// 4 reserved bytes
	WriteIntToChar(constants::BMP_HEADER_SIZE, initializedBitmap, 10, 4); // offset of pixel data
	WriteIntToChar(40, initializedBitmap, 14, 4); // header size (remaining bytes of the header)
	WriteIntToChar(constants::IMAGE_WIDTH, initializedBitmap, 18, 4); // image width
	WriteIntToChar(constants::IMAGE_HEIGHT, initializedBitmap, 22, 4); // image height
	WriteIntToChar(1, initializedBitmap, 26, 2); // planes
	WriteIntToChar(24, initializedBitmap, 28, 2); // bits per pixel
	WriteIntToChar(0, initializedBitmap, 30, 4); // compression type
	WriteIntToChar(constants::BMP_FILE_SIZE - constants::BMP_HEADER_SIZE, initializedBitmap, 34, 4); // how much space the pixels occupy
	WriteIntToChar(2835, initializedBitmap, 38, 4); // X pixels per meter
	WriteIntToChar(2835, initializedBitmap, 42, 4); // Y pixels per meter
	WriteIntToChar(0, initializedBitmap, 46, 4); // color palette
	WriteIntToChar(0, initializedBitmap, 50, 4); // important colors
	// pixels intialization
	for (int i = constants::BMP_HEADER_SIZE; i < constants::BMP_FILE_SIZE; i++) // initialize all pixels as white
	{
		initializedBitmap[i] = 255;
	}

	return initializedBitmap;
}

unsigned char* InitializeTurtleAttributes()
{
	unsigned char* initializedAttributes = new unsigned char[constants::TURTLE_ATTRIBUTES_SIZE];

	for (int i = 0; i < constants::TURTLE_ATTRIBUTES_SIZE; i++) // sets initial coordinates to (0,0), direction to 'up', pen color to black, pen state to 'lowered'
	{
		initializedAttributes[i] = 48;
	}

	return initializedAttributes;
}

void WriteIntToChar(int integerToWrite, unsigned char* targetCharArray, unsigned int startingChar, unsigned int howManyCharsToWrite)
{
	for (int i = 0; i < howManyCharsToWrite; i++)
	{
		char charToWrite = (char)(integerToWrite % 256);
		targetCharArray[startingChar + i] = charToWrite;
		integerToWrite = integerToWrite /256; // shift by 4 bits (1 byte)
	}
}

int ReadInstructions(unsigned char* commandsBuffer, int whereToStart)
{
	std::ifstream inputFile("input.bin", std::ios::in | std::ios::binary);
	if (inputFile.is_open())
	{
		int readBytesCount = 0;
		inputFile.seekg(whereToStart, std::ios::beg);
		inputFile.read((char*)commandsBuffer, constants::INSTRUCTIONS_BUFFER_SIZE);
		readBytesCount = (int)inputFile.gcount();

		inputFile.close();

		return readBytesCount;
	} // else there was an error when opening the file
	return 0;
}

bool SaveBMP(unsigned char* bitmapToSave)
{
	std::ofstream outputFile("output.bmp", std::ios::out | std::ios::binary | std::ios::trunc);
	if (outputFile.is_open())
	{
		outputFile.write((char*)bitmapToSave, constants::BMP_FILE_SIZE);
		return true;
	} // else there was an error when creating the file to write
	return false;
}