/* ------------------------------------------------------------------------------ -
	author: Gabriel Skowron-Rodriguez
	description: The C++ part of my implementation of project 6.20 "Binary turtle graphics - version 6"
   ------------------------------------------------------------------------------ -
 */
#include "ECOAR_Lab2.h"

int main()
{
#if COMPILATION_MODE >= 0
	std::cout << userMessages::PROGRAM_START;
#endif
	bool normalExit = true;
	bool reachedEndOfFile = false;

	unsigned char* destinationBitmap = InitializeDestinationBitmap();
	unsigned char* commands = new unsigned char[constants::INSTRUCTIONS_BUFFER_SIZE];
	unsigned char* turtle_attributes = InitializeTurtleAttributes(); // used store the turtle arguments between turtle() calls (non-compressed)
	int commandsSize = 0;
	int nextCommandToRead = 0;
#if COMPILATION_MODE >= 0
	std::cout << userMessages::PROGRAM_INSTRUCTIONS_OPENING << constants::INPUT_FILE <<"\n";
#endif
	while (!reachedEndOfFile)
	{
		commandsSize = ReadInstructions(commands, nextCommandToRead);
		if (commandsSize > 0)
		{
			nextCommandToRead += commandsSize; // so we know where to start reading next time

#if COMPILATION_MODE >= 2
			std::cout << "Turtle Command Size:  " << commandsSize << " :";
			for (int i = 0; i < commandsSize; i++)
			{
				std::cout << (int)commands[i] << " ";
			}
			std::cout << "\n";
			std::cout << "Turtle attributes :" << turtle_attributes << "\n";
			DebugPrintCharArrayAsInt(turtle_attributes, constants::TURTLE_ATTRIBUTES_SIZE);
			std::cout << "Turtle starting:\n";
#endif
			int turtleResult = turtle(destinationBitmap, commands, commandsSize, turtle_attributes);
#if COMPILATION_MODE >= 2
			std::cout << "Turtle finishing with result: " << turtleResult << "\n";
			std::cout << "Turtle attributes :" << turtle_attributes << "\n";
			DebugPrintCharArrayAsInt(turtle_attributes, constants::TURTLE_ATTRIBUTES_SIZE);
#endif
			if (turtleResult == 1) // detected a two-word command that was cut in half
			{
				if (commandsSize > 2 && commandsSize <= constants::INSTRUCTIONS_BUFFER_SIZE)// if we are reading more than one word at a time and the set_position command was cut in half (is at the end of the buffer)
				{
#if COMPILATION_MODE >= 1
					std::cout << userMessages::DISJOINT_WORD_ENCOUNTERED_1 << nextCommandToRead << userMessages::DISJOINT_WORD_ENCOUNTERED_2;
#endif
					nextCommandToRead -= 1; // read the severed word as the first one in the next batch of instructions
				}
				else
				{
#if COMPILATION_MODE >= 0
					std::cout << userMessages::SEVERED_WORD_ENCOUNTERED_1 << nextCommandToRead + commandsSize - 1 << userMessages::SEVERED_WORD_ENCOUNTERED_2;
#endif
					reachedEndOfFile = true; // the first word of the set_position command was at the end of the file: we should ignore it
				}
			}
			else if (turtleResult == 2) // detected a two-word command whose second word is cut in half (a byte missing)
			{
				if (commandsSize > 3 && commandsSize <= constants::INSTRUCTIONS_BUFFER_SIZE)// if we are reading more than one word at a time and the set_position command was cut in half (is at the end of the buffer)
				{
#if COMPILATION_MODE >= 1
					int missingByteNumber = nextCommandToRead + 1;
					std::cout << userMessages::DISJOINT_SET_POSITION_ENCOUNTERED_1 << missingByteNumber << userMessages::DISJOINT_SET_POSITION_ENCOUNTERED_2;
#endif
					nextCommandToRead -= 3; // read the incomplete set_position command as the first one in the next batch of instructions
				}
				else
				{
#if COMPILATION_MODE >= 0
					std::cout << userMessages::SEVERED_SET_POSITION_ENCOUNTERED_1 << nextCommandToRead + commandsSize << userMessages::SEVERED_SET_POSITION_ENCOUNTERED_2;
#endif
					reachedEndOfFile = true; // the first word of the set_position command was at the end of the file: we should ignore it and finish drawing
				}
			}
			else if (turtleResult == 3) // detected a two-word command that was cut in half (two bytes missing)
			{
				if (commandsSize > 2 && commandsSize <= constants::INSTRUCTIONS_BUFFER_SIZE)// if we are reading more than one word at a time and the set_position command was cut in half (is at the end of the buffer)
				{
#if COMPILATION_MODE >= 1
					int missingByteNumber = nextCommandToRead + 1;
					std::cout << userMessages::DISJOINT_SET_POSITION_ENCOUNTERED_3 << missingByteNumber << " and " << missingByteNumber + 1 << userMessages::DISJOINT_SET_POSITION_ENCOUNTERED_4;
#endif
					nextCommandToRead -= 2; // read the incomplete set_position command as the first one in the next batch of instructions
				}
				else
				{
#if COMPILATION_MODE >= 0
					std::cout << userMessages::SEVERED_SET_POSITION_ENCOUNTERED_3 << nextCommandToRead + commandsSize << userMessages::SEVERED_SET_POSITION_ENCOUNTERED_4;
#endif
					reachedEndOfFile = true; // the first word of the set_position command was at the end of the file: we should ignore it and finish drawing
				}
			}
		}
		else if (commandsSize == 0) // we have reached the end of file
		{
			reachedEndOfFile = true;
		}
		else // an error happened
		{
			reachedEndOfFile = true;
			normalExit = false;
		}
	}
	if (normalExit)
	{
#if COMPILATION_MODE >= 0
		std::cout << userMessages::FINISHED_DRAWING;
#endif
		SaveBMP(destinationBitmap);
#if COMPILATION_MODE >= 0
		std::cout << userMessages::SAVED_TO_FILE << "\"" << constants::OUTPUT_FILE << "\"\n";
#endif
		delete destinationBitmap;
		delete commands;
		delete turtle_attributes;
#if COMPILATION_MODE >= 0
		std::cout << userMessages::PROGRAM_END;
#endif
		return 0;
	}
#if COMPILATION_MODE >= 0
	std::cout << userMessages::PROGRAM_END;
#endif
	return 1;
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

int ReadInstructions(unsigned char* commandsBuffer, int whereToStart)
{
	std::ifstream inputFile(constants::INPUT_FILE, std::ios::in | std::ios::binary);
	if (inputFile.is_open())
	{
		int readBytesCount = 0;
		inputFile.seekg(whereToStart, std::ios::beg);
		inputFile.read((char*)commandsBuffer, constants::INSTRUCTIONS_BUFFER_SIZE);
		readBytesCount = (int)inputFile.gcount();

		inputFile.close();

		return readBytesCount;
	} // else there was an error when opening the file
#if COMPILATION_MODE >= 0
	std::cout << userMessages::OPEN_FILE_ERROR << "\"" << constants::INPUT_FILE << "\"\n";
#endif
	return -1;
}

bool SaveBMP(unsigned char* bitmapToSave)
{
	std::ofstream outputFile(constants::OUTPUT_FILE, std::ios::out | std::ios::binary | std::ios::trunc);
	if (outputFile.is_open())
	{
		outputFile.write((char*)bitmapToSave, constants::BMP_FILE_SIZE);
		return true;
	} // else there was an error when creating the file to write
	return false;
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

void DebugPrintCharArrayAsInt(unsigned char* charArray, int length)
{
	std::cout << "Char array as ints: ";
	for (int i = 0; i < length; i++)
	{
		std::cout << (int)charArray[i] << " ";
	}
	std::cout << "\n";
}
