;-------------------------------------------------------------------------------
;	author: Gabriel Skowron-Rodriguez
;	description : My x86 32bit implementation of project 6.20 "Binary turtle graphics - version 6"
;-------------------------------------------------------------------------------

SECTION .DATA
; turtle attributes ; location on the stack (after the start of the function)
;	position_x: dd 0
;	position_y db 0
;	direction db 0
;	pen_color dd 0x00RRGGBB
;	pen_state db 0


; TEMP DEBUG PRINT
    printf_format: db "Result: %d",0xA,0 ; debug code
	extern printf

%macro debug_print 1
	pushad; store all registers (so they do not get spoiled by the printf)
	push dword %1 ; 2nd printf argument
	push dword printf_format ; 1st printf argument
	call printf ; printf(printf_format, 1);
	add esp, 2*4; clear the stack
	popad; restore all registers
%endmacro

; where to find the turtle's attributes on the stack (conting from ESP just after loading in the initial state of the turtle)
PRESERVED_REGISTERS_SIZE equ 8; how much space non-volatile registers occupy after the prologue
TURTLE_ATTRIBUTES_SIZE equ 12; all attributes except for color take up 2 bytes + color takes 4, so 4*2 + 4 = 12; those 1 byte long data have to occupy at least 2 byets because push works for at least 2 byte long data

TURTLE_OFFSET_POSITION_X equ 0; it is at the top of the stack
TURTLE_OFFSET_POSITION_Y equ 2 + TURTLE_OFFSET_POSITION_X ; 2
TURTLE_OFFSET_DIRECTION equ 2 + TURTLE_OFFSET_POSITION_Y ; 4
TURTLE_OFFSET_PEN_STATE equ 2 + TURTLE_OFFSET_DIRECTION ; 6
TURTLE_OFFSET_PEN_COLOR equ 2 + TURTLE_OFFSET_PEN_STATE; 8

; where to find turtle() arguments on the stack (counting from ESP at the beginning of the turtle() function) - adding TURTLE_ATTRIBUTES_SIZE in trivial cases to locate an argument exactly
ARGUMENT_OFFSET_dest_bitmap equ 8 + TURTLE_ATTRIBUTES_SIZE + PRESERVED_REGISTERS_SIZE
ARGUMENT_OFFSET_commands equ 12 + TURTLE_ATTRIBUTES_SIZE + PRESERVED_REGISTERS_SIZE
ARGUMENT_OFFSET_commands_size equ 16 + TURTLE_ATTRIBUTES_SIZE + PRESERVED_REGISTERS_SIZE
ARGUMENT_OFFSET_turtle_attributes equ 20 + TURTLE_ATTRIBUTES_SIZE + PRESERVED_REGISTERS_SIZE

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
	push ebx ; proably will be using this so it should be preserved
	push esi

;	load and store the turtle parameters on the stack (for faster access)
	
	mov esi, [esp + 20 + PRESERVED_REGISTERS_SIZE] ; get pointer to turtle attributes
	mov ebx, [esi + 0] ; load turtle's pen color
	push ebx;	in the end, it is located at [esp+8] (but it takes up 4 bytes) / [esp + TURTLE_OFFSET_PEN_COLOR]
	mov ebx, 0; make sure that the register is fully zeroed
	
	mov bl, [esi + 4]; load turtle's pen state
	push bx;	in the end, it is located at [esp+6] / [esp + TURTLE_OFFSET_PEN_STATE]
	
	mov bl, [esi + 5]; load turtle's direction
	push bx;	in the end, it is located at [esp+4] / [esp + TURTLE_OFFSET_DIRECTION]

	mov bl, [esi + 6]; load turtle's position_y
	push bx;	in the end, it is located at [esp+2] / [esp + TURTLE_OFFSET_POSITION_Y]

	mov bx, [esi + 7]; load turtle's position_x
	push bx;	in the end, it is located at [esp] / [esp + TURTLE_OFFSET_POSITION_X]

;	execute the given batch of commands

	mov ebx, 0; start reading from the beginning of the commands
read_next_instruction:	
	add ebx, 2;
	mov eax, [esp + ARGUMENT_OFFSET_commands_size] ; read commands_size
	cmp ebx, eax ; check if we have finished reading
	jg exit_normal ; we have successfully finished processing the batch of instructions: return control to the caller

	; if we have not read all instructions: decode the instruction

	mov esi, [esp + ARGUMENT_OFFSET_commands]; get pointer to the commands
	;debug_print esi
	;debug_print ebx
	mov ax, 0
	mov ax, [esi + ebx - 2]; load the command word (-2 to account for the checking of availability of 2 bytes - a full word)
	mov ecx, eax; copy the commad word so we can decode it

	and cx, MASK_COMMAND_TYPE ; read command type
	cmp cx, 192;  (11)000000 - set direction command
	je read_set_direction_command
	cmp cx, 64;  (01)000000 - set pen state command
	je read_set_pen_state_command
	cmp cx, 0;  (00)000000 - move command X
	je read_move_command
	; the masked out bits are equal to (10)000000 - set position command X

; set position command decoding
	; check if there is a next word to read 'X' from
	mov ecx, [esp + ARGUMENT_OFFSET_commands_size] ; read commands_size
	add ebx, 2; the second command word has been provided if and only if (ebx + 2) <= commands_size
	cmp ebx, ecx ; check if( (ebx + 2) <= commands_size)
	jg exit_request_full_set_position_command ; we found out that the set_position command's first word is at the end of the commands "list": exit and ask for both command words at once
	
	; we do have both set_position command's words
	
	; decode the target 'Y' coordinate
	; the first word of the set_position command is already loaded into eax
		; the ax register's contents: { (8 irrelevant bits) | 1 0 y5 y4 y3 y2 y1 y0 }
		; so we can just mask out the correct bits to get the 'Y' coordinate in the appropriate form
	and ax, MASK_SET_POSITION_Y; directly obtain the value of 'Y'
	mov word [esp + TURTLE_OFFSET_POSITION_Y], ax; set the new value of turtle's 'Y'

	; decode the target 'X' coordinate
	mov ax, [esi + ebx - 2]; load second word of the set_position command
		; the ax register's contents: { x1 x0 - - - - - - | x9 x8 x7 x6 x5 x4 x3 x2 }
		; and we need to provide the x coordinate in the form: { (6 zeros) x9 x8 | x7 x6 x5 x4 x3 x2 x1 x0 }
	mov cx, ax ; copy the word to extract the 8MSbs
	and cx, MASK_SET_POSITION_X8MSB ; retrieve the 8 most significant bits of 'X'
	shl cx, 2 ; "make space" for the 2 least significant bits	
	and ax, MASK_SET_POSITION_X2LSB ; retrieve the 2 least significant bits of 'X'
	shr ax, 14 ; put the 4 least significant bits into their approptiate "spot"
	or ax, cx ; obtain the desired 'X' coordinate
	mov word [esp + TURTLE_OFFSET_POSITION_X], ax; set the new value of turtle's 'X'

	debug_print 7710
	debug_print ebx

	jmp read_next_instruction ; finished executing set_position command, read the next instruction

; set direction command decoding
read_set_direction_command:
	
	debug_print 7711
	debug_print ebx
	;jmp read_next_instruction ;; TEMP

	; decode the direction 
	; contents of the register ax :  { - - - - - - - - | 1 1 - - D D - - }
	and ax, MASK_SET_DIRECTION ; read the correct 2 bits ( ax == DD00)
	shr ax, 2 ; ax == DD (direction code)
	mov word [esp + TURTLE_OFFSET_DIRECTION], ax; rotate the turtle accordingly

	jmp read_next_instruction ; finished executing set_direction command, read the next instruction

; MIPS CODE START
;# set pen state command decoding
read_set_pen_state_command:
	
	debug_print 7701
	debug_print ebx
	;jmp read_next_instruction ;; TEMP

	; contents of the register ax :  { - - - - - - - - | 0 1 - A - C C C }
	; decode pen "altitude" (whether it is raised or lowered)
	mov ecx, eax ; copy the word since it will be needed later
	and cx, MASK_PEN_IS_UP ; cx == 000A0000
	shr cx, 4 ; now cx is either == 1 or == 0 (in the correct form for set_pen_state)
	mov word [esp + TURTLE_OFFSET_PEN_STATE], cx; apply pen_state
	; decode the pen color
	and ax, MASK_PEN_COLOR ; ax == 00000CCC
	cmp ax, 7
	je read_pen_state_decoded_white
	cmp ax, 6
	je read_pen_state_decoded_red
	cmp ax, 5
	je read_pen_state_decoded_green
	cmp ax, 4
	je read_pen_state_decoded_blue
	cmp ax, 3
	je read_pen_state_decoded_yellow
	cmp ax, 2
	je read_pen_state_decoded_cyan
	cmp ax, 1
	je read_pen_state_decoded_purple
	; none of the options were hit, so ax contains 000 - black
	mov eax, 0x00000000 ; set color to black
read_set_pen_state_apply: ; color has been saved to ax, execute the color change
	mov dword [esp + TURTLE_OFFSET_PEN_COLOR], eax; apply pen_color
	debug_print eax
	jmp read_next_instruction ; finished executing set_pen_state command, read the next instruction
		; set pen state : color decoding
read_pen_state_decoded_white:
	mov eax, 0x00FFFFFF
	jmp read_set_pen_state_apply
read_pen_state_decoded_red:
	mov eax, 0x00FF0000
	jmp read_set_pen_state_apply
read_pen_state_decoded_green:
	mov eax, 0x0000FF00
	jmp read_set_pen_state_apply
read_pen_state_decoded_blue:
	mov eax, 0x000000FF
	jmp read_set_pen_state_apply
read_pen_state_decoded_yellow:
	mov eax, 0x00FFFF00
	jmp read_set_pen_state_apply
read_pen_state_decoded_cyan:
	mov eax, 0x0000FFFF
	jmp read_set_pen_state_apply
read_pen_state_decoded_purple:
	mov eax, 0x00B803FF
	jmp read_set_pen_state_apply	

;# move command decoding
read_move_command: ;# the register's contents: { (16 irrelevant ("-") bits) | m3 m2 m1 m0  - - - - | 0 0 m9 m8  m7 m6 m5 m4 }
	
	debug_print 7700
	debug_print ebx

	jmp read_next_instruction ;; TEMP
;		   # and we need to provide the move distance in the form: { (22 zeros) m9 m8 | m7 m6 m5 m4 m3 m2 m1 m0 }
;	and $t0, $s6, MASK_MOVE_DISTANCE_6MSB # retrieve the 6 most significant bits
;	sll $t0, $t0, 4 # move the 6 most significant bits to their appropriate positions ("make space" for the remaining 4 bits)
;	and $a0, $s6, MASK_MOVE_DISTANCE_4LSB # retrieve the 4 least significant bits
;	srl $a0, $a0, 12 # move the 4 least significant bits to the appropriate spot ("get ready to fill in the space made 2 lines earlier")
;	or $a0, $a0, $t0 # obtain the desired move distance and store it as the correct argument for the move_turtle function
;	jal move_turtle
;	j read_next_instruction # finished executing move_turtle command, read the next instruction
; MIPS CODE END


; DEBUG CODE AHEAD
	jmp exit_normal ; comment out to start debug
	; TEMP : CHANGE PEN COLOR BY 1

	mov ebx, [esp + TURTLE_OFFSET_PEN_COLOR]; read the pen_color
	debug_print ebx
	add ebx, 1; increment pen_color
	debug_print ebx
	mov dword [esp + TURTLE_OFFSET_PEN_COLOR], ebx; apply the change to pen_color

	; TEMP : CHANGE PEN STATE BY 2

	mov ebx, 0
	mov bx, [esp + TURTLE_OFFSET_PEN_STATE]; read the pen_color
	debug_print ebx
	add bx, 2; increment pen_state
	debug_print ebx
	mov word [esp + TURTLE_OFFSET_PEN_STATE], bx; apply the change to pen_color

	; TEMP : CHANGE DIRECTION BY 3

	mov ebx, 0
	mov bx, [esp + TURTLE_OFFSET_DIRECTION]; read the pen_color
	debug_print ebx
	add bx, 3; increment pen_state
	debug_print ebx
	mov word [esp + TURTLE_OFFSET_DIRECTION], bx; apply the change to pen_color

	; TEMP : CHANGE Y POSITION BY 4

	mov ebx, 0
	mov bx, [esp + TURTLE_OFFSET_POSITION_Y]; read the pen_color
	debug_print ebx
	add bx, 4; increment pen_state
	debug_print ebx
	mov word [esp + TURTLE_OFFSET_POSITION_Y], bx; apply the change to pen_color

	; TEMP : CHANGE X POSITION BY 5

	mov ebx, 0
	mov bx, [esp + TURTLE_OFFSET_POSITION_X]; read the pen_color
	debug_print ebx
	add bx, 5; increment pen_state
	debug_print ebx
	mov word [esp + TURTLE_OFFSET_POSITION_X], bx; apply the change to pen_color

; random temporary stuff
	; how to read the 2nd element of an array pointed by esp+8
	mov ecx, [esp + ARGUMENT_OFFSET_dest_bitmap] ; read the address of the destination bit map
	mov edx, ecx ; read the number that is stored in the register (the adress)

	mov ebx, 0; prepare the 32 bit register to read only the first 8 bits
	mov bx, [edx+2] ; read the "2nd" number under the adress stored in edx

	; how referencing and dereferencing works
	; [reg] - read the register's content as value
	; reg - read the register's content as adress


	;mov eax, 0 ; need to clear the whole register if we want to output the thing as a 32 bit integer
	;mov al, [position_y]	; since the target register is 8 bits long, only the first 8 bits under the adress of 'position_y' are loaded
	;add al, [direction]		; again, because the target register is 8 bits long, the first 8 bits under the adress of 'direction' are subtracted from al
	;mov ecx, eax ; USE TO SEE THE OUTPUT OF MANIPULATING STATIC VARS

epilogue:
;	save the turtle attributes (pass them back so if called again, the turtle resumes from the state it has ended in)
	
	mov esi, [esp + ARGUMENT_OFFSET_turtle_attributes]; store the pointer to attributes
	mov ebx, 0; make sure that the register is fully zeroed
	
	pop bx
	mov word [esi + 7], bx; store turtle's position_x

	pop bx
	mov byte [esi + 6], bl; store turtle's position_y

	pop bx;
	mov byte [esi + 5], bl; store turtle's direction

	pop bx
	mov byte [esi + 4], bl; store the turtle's pen state

	pop ebx ; update the adress of the pen color
	mov dword [esi + 0], ebx; store turtle's pen color

; return caller's frame pointer and non-volatile registers
	mov eax, ecx ; turtle return value (TEMP for now we return the pen_color)
	pop esi
	pop ebx
	mov esp, ebp
	pop ebp 
    ret         ; Return control to the caller

; exit codes
; normal exit code
exit_normal:
	mov ecx, 0; '0' means "OK"
	jmp epilogue

; request both words of the set_postition command
exit_request_full_set_position_command:
	mov ecx, -1; '-1' means "incomplete set_position command detected, please provide both words at the same time"
	jmp epilogue