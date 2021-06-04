SECTION .DATA
; turtle attributes ; location on the stack (after the start of the function)
;	position_x: dd 0
;	position_y db 0
;	direction db 0
;	pen_color dd 0x00RRGGBB
;	pen_state db 0

; where to find the turtle's attributes on the stack (conting from ESP just after loading in the initial state of the turtle)
TURTLE_ATTRIBUTES_SIZE equ 12; all attributes except for color take up 2 bytes + color takes 4, so 4*2 + 4 = 12

TURTLE_OFFSET_POSITION_X equ 0
TURTLE_OFFSET_POSITION_Y equ 2 + TURTLE_OFFSET_POSITION_X ; 2
TURTLE_OFFSET_DIRECTION equ 2 + TURTLE_OFFSET_POSITION_Y ; 4
TURTLE_OFFSET_PEN_STATE equ 2 + TURTLE_OFFSET_DIRECTION ; 6
TURTLE_OFFSET_PEN_COLOR equ 2 + TURTLE_OFFSET_PEN_STATE; 8

; where to find turtle() arguments on the stack (counting from ESP at the beginning of the turtle() function) - adding TURTLE_ATTRIBUTES_SIZE in trivial cases to locate an argument exactly
ARGUMENT_OFFSET_dest_bitmap equ 8 + TURTLE_ATTRIBUTES_SIZE
ARGUMENT_OFFSET_commands equ 12 + TURTLE_ATTRIBUTES_SIZE
ARGUMENT_OFFSET_commands_size equ 16 + TURTLE_ATTRIBUTES_SIZE
ARGUMENT_OFFSET_turtle_attributes equ 20 + TURTLE_ATTRIBUTES_SIZE

; image processing constants
; only 24-bits 600x50 pixels BMP files are supported
BYTES_PER_ROW equ 1800
HEADER_SIZE equ 54
IMAGE_WIDTH equ 600 ; x can be a value between 0 and 599 (inclusive)
IMAGE_HEIGHT equ 50 ; y can be a value between 0 and 49 (inclusive)
INSTRUCTION_WORD_SIZE equ 2 ; how many bytes encode an instruction word (words are 16 bits long, so 2 bytes are needed)
; all the folling mask descriptions assume that the 16 most significant bits are all 0s (since the program reads 16 bits at a time, while the registers are 32 bit long)
MASK_COMMAND_TYPE equ 192 ; first 2 bits of the word encode the instruction type, so we need 00000000 11000000 mask to read them (since when loading the word from the file we get B1 B0)

MASK_SET_POSITION_Y equ 63 ; 3rd, 4th, 5th, 6th, 7th and 8th bits encode the target y position, so we need 00000000 00111111 mask to read them (since when loading the word from the file we get B1 B0)
MASK_SET_POSITION_X8MSB equ 255 ; the first 8 bits of the second word encode the 8 most significant bits of the target y position, so we need 00000000 11111111 mask to read them (since when loading the word from the file we get B1 B0)
MASK_SET_POSITION_X2LSB equ 49152 ; 9th and 10th bits of the second word encode the 2 least significant bits of the target y position, so we need 11000000 00000000 mask to read them (since when loading the word from the file we get B1 B0)

MASK_SET_DIRECTION equ 12 ; 5th and 6th bit of the "set command" word encode the direction, so we need 00000000 00001100 mask to read them (since when loading the word from the file we get B1 B0)
MASK_PEN_IS_UP equ 16 ; 4th bit of the "set pen state" word tells whether the pen in raised or lowered, so we need 00000000 00010000 mask to read it (since when loading the word from the file we get B1 B0)
MASK_PEN_COLOR equ 7; 6th,7th and 8th bits of the "set pen state" word encode color, so we need 00000000 00000111 mask to read them (since when loading the word from the file we get B1 B0)
MASK_MOVE_DISTANCE_6MSB equ 63 ; 3rd, 4th, 5th, 6th, 7th and 8th encode the 6 most significant bits of the move distance, so we need 00000000 00111111 mask to read them (since when loading the word from the file we get B1 B0 into the register) ;Yes, I am "defining" '77' twice, but that is for the better readability in the "logic part" of the code
MASK_MOVE_DISTANCE_4LSB equ 61440 ; 9th, 10th, 11th and 12th bits encode the 4 least significant bits of the value to move, so we need 11110000 00000000 to read them (they are on more significant positions in the register since the register is filled in the B1 B0 order)

SECTION .TEXT
	GLOBAL turtle
turtle:
; arguments:
; esp + 8 : 1st (unsigned char * 'dest_bitmap')
; esp + 12 : 2nd (unsigned char * 'commands')
; esp + 16 : 3rd (unsigned int(32bit) 'commands_size')
; esp + 20 : 4th (unsigned char * 'turtle_attributes') ; need 9 bytes to keep them around ( 4 - color, 1 - pen state , 1 - direction, 2 - position_y, 1 - position_x)


; prologue
;	save the caller's frame pointer
	push ebp
	mov ebp, esp

;	load and store the turtle parameters
	
	mov eax, 0x00000000 ; load turtle's pen color
	push eax;	in the end, it is located at [esp+8] (but it takes up 4 bytes) / [esp + TURTLE_OFFSET_PEN_COLOR]
	
	mov eax, 0; make sure that the register is fully zeroed
	
	mov ax, 0; load turtle's pen state
	push ax;	in the end, it is located at [esp+6] / [esp + TURTLE_OFFSET_PEN_STATE]
	
	mov ax, 0; load turtle's direction
	push ax;	in the end, it is located at [esp+4] / [esp + TURTLE_OFFSET_DIRECTION]

	mov ax, 0; load turtle's position_y
	push ax;	in the end, it is located at [esp+2] / [esp + TURTLE_OFFSET_POSITION_Y]

	mov ax, 0; load turtle's position_x
	push ax;	in the end, it is located at [esp] / [esp + TURTLE_OFFSET_POSITION_X]

;	execute the given batch of commands
; FOR NOW ASSUMING THAT '* commands' PROVIDE ONLY THE INSTRUCTIONS


; random temporary stuff
	; how to read the 2nd element of an array pointed by esp+8
	mov ecx, [esp + ARGUMENT_OFFSET_dest_bitmap] ; read the address of the destination bit map
	mov edx, ecx ; read the number that is stored in the register (the adress)

	mov ecx, 0; prepare the 32 bit register to read only the first 8 bits
	mov cl, [edx+2] ; read the "2nd" number under the adress stored in edx

	; how referencing and dereferencing works
	; [reg] - read the register's content as value
	; reg - read the register's content as adress


	;mov eax, 0 ; need to clear the whole register if we want to output the thing as a 32 bit integer
	;mov al, [position_y]	; since the target register is 8 bits long, only the first 8 bits under the adress of 'position_y' are loaded
	;add al, [direction]		; again, because the target register is 8 bits long, the first 8 bits under the adress of 'direction' are subtracted from al
	;mov ecx, eax ; USE TO SEE THE OUTPUT OF MANIPULATING STATIC VARS

;	epilogue
;	save the turtle attributes (pass them back so if called again, the turtle resumes from the state it has ended in)
	
	mov eax, 0; make sure that the register is fully zeroed
	
	pop ax
	mov ax, 0; store turtle's position_x

	pop ax
	mov ax, 0; store turtle's position_y

	pop ax;
	mov ax, 0; store turtle's direction

	pop ax
	mov ax, 0; store turtle's pen state

	pop eax
	mov eax, 0x00FFFFFF; store turtle's pen color

; return caller's frame pointer
	mov eax, ecx ; turtle return value (temp: ecx - to read the 2nd char from dest_bitmap)

	mov esp, ebp
	pop ebp 
    ret         ; Return control to the caller