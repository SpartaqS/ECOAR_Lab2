;-------------------------------------------------------------------------------
;	author: Gabriel Skowron-Rodriguez
;	description : The x86 (32bit) part of my implementation of project 6.20 "Binary turtle graphics - version 6"
;-------------------------------------------------------------------------------

SECTION .DATA

; TEMP DEBUG PRINT
    printf_format: db "Result: %d",0xA,0 ; debug code
	extern printf

%macro debug_log 1
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
MASK_MOVE_DISTANCE_6MSB equ 63 ; 3rd, 4th, 5th, 6th, 7th and 8th encode the 6 most significant bits of the move distance, so we need 00000000 00111111 mask to read them (since when loading the word from the file we get B1 B0 into the register) ;Yes, I am "defining" '63' twice, but that is for the better readability in the "logic part" of the code
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
	push ebx ; will be using those so they should be preserved
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

	mov ebx, esp
	;debug_log ebx ; log turtle attributes pointer

	mov ebx, [esp + ARGUMENT_OFFSET_dest_bitmap]
	;debug_log ebx ; log bitmap pointer

;	execute the given batch of commands

	mov ebx, 0; start reading from the beginning of the commands
read_next_instruction:	
	add ebx, 2;
	mov eax, [esp + ARGUMENT_OFFSET_commands_size] ; read commands_size
	cmp ebx, eax ; check if we have finished reading (if the commands_size is odd, will ignore the last byte)
	jg exit_normal ; we have successfully finished processing the batch of instructions: return control to the caller

	; if we have not read all instructions: decode the instruction

	mov esi, [esp + ARGUMENT_OFFSET_commands]; get pointer to the commands
	;debug_log esi
	;debug_log ebx
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

	;debug_log 7710
	;debug_log ebx

	jmp read_next_instruction ; finished executing set_position command, read the next instruction

; set direction command decoding
read_set_direction_command:
	
	;debug_log 7711
	;debug_log ebx
	;jmp read_next_instruction ;; TEMP

	; decode the direction 
	; contents of the register ax :  { - - - - - - - - | 1 1 - - D D - - }
	and ax, MASK_SET_DIRECTION ; read the correct 2 bits ( ax == DD00)
	shr ax, 2 ; ax == DD (direction code)
	mov word [esp + TURTLE_OFFSET_DIRECTION], ax; rotate the turtle accordingly
	jmp read_next_instruction ; finished executing set_direction command, read the next instruction

; set pen state command decoding
read_set_pen_state_command:
	
	;debug_log 7701
	;debug_log ebx
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

; move command decoding
read_move_command: 
	
	;debug_log 7700
	;debug_log ebx

	;jmp read_next_instruction ;; TEMP
		; ax register's contents: { m3 m2 m1 m0  - - - - | 0 0 m9 m8  m7 m6 m5 m4 }
		; and we need to provide the move distance in the form: { (22 zeros) m9 m8 | m7 m6 m5 m4 m3 m2 m1 m0 }
	mov ecx, eax; make a copy of the word (we will again need it soon)
	and ax, MASK_MOVE_DISTANCE_6MSB ; retrieve the 6 most significant bits
	shl ax, 4 ; move the 6 most significant bits to their appropriate positions ("make space" for the remaining 4 bits)
	and cx, MASK_MOVE_DISTANCE_4LSB ; retrieve the 4 least significant bits
	shr cx, 12 ; move the 4 least significant bits to the appropriate spot ("get ready to fill in the space made 2 lines earlier")
	or cx, ax ; obtain the desired move distance and store it as the correct argument for the move_turtle function
	
	; calling the movement function
	push ecx; prepare the turtle's movement distance argument (3nd)
	mov ecx, ebp; prepare the turtle's current attributes pointer
	add ecx, TURTLE_OFFSET_POSITION_X - TURTLE_ATTRIBUTES_SIZE - PRESERVED_REGISTERS_SIZE; obtain the attributes' adress
	push ecx; push the turtle's attributes pointer (2nd argument)
	mov ecx, [esp + ARGUMENT_OFFSET_dest_bitmap + 8]; ; prepare the bitmap pointer 
	push ecx; push the bitmap pointer (1st argument)
	call move_turtle ; execute the movement
	add esp, 3*4; clear the stack ("deallocate" the parameters)

	jmp read_next_instruction ; finished executing move_turtle command, read the next instruction

; DEBUG CODE AHEAD
	jmp exit_normal ; comment out to start debug
	; TEMP : CHANGE PEN COLOR BY 1

	mov ebx, [esp + TURTLE_OFFSET_PEN_COLOR]; read the pen_color
	debug_log ebx
	add ebx, 1; increment pen_color
	debug_log ebx
	mov dword [esp + TURTLE_OFFSET_PEN_COLOR], ebx; apply the change to pen_color

	; TEMP : CHANGE PEN STATE BY 2

	mov ebx, 0
	mov bx, [esp + TURTLE_OFFSET_PEN_STATE]; read the pen_color
	debug_log ebx
	add bx, 2; increment pen_state
	debug_log ebx
	mov word [esp + TURTLE_OFFSET_PEN_STATE], bx; apply the change to pen_color

	; TEMP : CHANGE DIRECTION BY 3

	mov ebx, 0
	mov bx, [esp + TURTLE_OFFSET_DIRECTION]; read the pen_color
	debug_log ebx
	add bx, 3; increment pen_state
	debug_log ebx
	mov word [esp + TURTLE_OFFSET_DIRECTION], bx; apply the change to pen_color

	; TEMP : CHANGE Y POSITION BY 4

	mov ebx, 0
	mov bx, [esp + TURTLE_OFFSET_POSITION_Y]; read the pen_color
	debug_log ebx
	add bx, 4; increment pen_state
	debug_log ebx
	mov word [esp + TURTLE_OFFSET_POSITION_Y], bx; apply the change to pen_color

	; TEMP : CHANGE X POSITION BY 5

	mov ebx, 0
	mov bx, [esp + TURTLE_OFFSET_POSITION_X]; read the pen_color
	debug_log ebx
	add bx, 5; increment pen_state
	debug_log ebx
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
	mov ecx, 1; '1' means "incomplete set_position command detected, please provide both words at the same time"
	jmp epilogue


; ======== Turtle Manipulation : move the turtle ========
move_turtle:
;description: 
;	moves the turtle by 'distance' number of pixels in a specified direction, if the turtle would leave the image, it will go as far as it can without leaving the image
;arguments: 'size of reccomended register to load', adress as after the prologue)
;	'dword', (ebp + 16) 3rd - distance
;	'dword', (ebp + 12) 2nd - pointer to current turtle's state (x86 attributes)
;	'dword', (ebp + 8) 1st - pointer to bitmap (turtle() argument) 
; turtle attributes (add the "OFFSET" to the 1st argument value to obtain):
;	'word', TURTLE_OFFSET_POSITION_X - x coordinate (if direction is left or right)
;	'byte', TURTLE_OFFSET_POSITION_Y - y coordinate (if direction is up or down)
;	'byte', TURTLE_OFFSET_DIRECTION - direction (00 - up, 01 - left, 10 - down, 11 - right, other should not happen: we always read only 2 bits in the set direction command)
;	'byte', TURTLE_OFFSET_PEN_STATE - pen state (0 - lowered, 1 - raised)
;	'dword', TURTLE_OFFSET_PEN_COLOR - color (if pen is lowered then will leave a trail in this color)

;return value: none
	; prologue
	; save the caller's frame pointer
	push ebp
	mov ebp, esp
	push ebx; will be using these registers, so need to preserve them
	push esi

	; get the direction
	mov esi, [ebp + 12]; get the adress of turtle attributes
	mov ebx, 0
	mov bl, [esi + TURTLE_OFFSET_DIRECTION]; read the turtle's direction

	; decode the direction
	mov ecx, ebx; copy the direction code
	and cl, 1 ; read the least significant bit of the direction code
	cmp cl, 0
	je move_decode_vertical_movement ; turtle is supposed to move vertically, decide whether up ot down
	;(otherwise) turtle is supposed to move horizontally, decide whether left or right


move_decode_horizontal_movement:
	mov ecx, [ebp + 16]; get the distance to move
	push ecx; supply the get_[positive/negative]_move_destination with the 'distance' argument
	mov ecx,0
	mov cx, [esi + TURTLE_OFFSET_POSITION_X] ; get the turtle's 'x' coordinate
	push ecx ; supply the turtle's 'x' coordinate for destination calculation (since we know we will be moving horizontally)
	cmp bl, 1
	je move_left ; if direction == 01 , then we move left, otherwise we move right
move_right:	; move right
	mov ecx, IMAGE_WIDTH - 1; 
	push ecx; provide IMAGE_WIDTH - 1 as the "edge coordinate"
	call get_positive_move_destination
	add esp, 3*4; clear the stack
	; check if turtle has to leave a trail
	mov cx, [esi + TURTLE_OFFSET_PEN_STATE]
	cmp cx, 0
	je move_right_loop_start ; if pen is lowered, then we need to paint all pixels on the path
	; the pen is raised => we can just "teleport" to the target position
	mov [esi + TURTLE_OFFSET_POSITION_X], ax  ; we can just set the x coordinate (no need to call set_position since y will not change)
	jmp move_finish

move_right_loop_start:
	; prepare arguments for 'paint_current_position' (arguments in registers because this will speed up execution significantly + it is a leaf function)
	; esi already contains the pointer to attributes
	mov ebx, [ebp + 8] ; prepare the pointer to bitmap
move_right_loop:
	push ax
	call paint_current_position ; we have just "arrived" at this current position, so we should paint it.
	pop ax
	mov cx, [esi + TURTLE_OFFSET_POSITION_X]; get the current 'x' position
	cmp cx, ax
	jge move_finish ; if we have arrived at the target position : exit the loop
	add cx, 1; get the next coordinate to move to
	mov [esi + TURTLE_OFFSET_POSITION_X], cx ; actually move to that coordinate
	jmp move_right_loop
	
move_left:	; move left
	; the distance and turtle's position have already been provided: just get the move destination
	call get_negative_move_destination
	add esp, 2*4; clear the stack
	; check if turtle has to leave a trail
	mov cx, [esi + TURTLE_OFFSET_PEN_STATE]
	cmp cx, 0
	je move_left_loop_start ; if pen is lowered, then we need to paint all pixels on the path
	; the pen is raised => we can just "teleport" to the target position
	mov [esi + TURTLE_OFFSET_POSITION_X], ax  ; we can just set the x coordinate (no need to call set_position since y will not change)
	jmp move_finish

move_left_loop_start:
	; prepare arguments for 'paint_current_position' (arguments in registers because this will speed up execution significantly + it is a leaf function)
	; esi already contains the pointer to attributes
	mov ebx, [ebp + 8] ; prepare the pointer to bitmap
move_left_loop:
	push ax
	call paint_current_position ; we have just "arrived" at this current position, so we should paint it.
	pop ax
	mov cx, [esi + TURTLE_OFFSET_POSITION_X]; get the current 'x' position

	cmp cx, ax
	jle move_finish ; if we have arrived at the target position : exit the loop
	sub cx, 1; get the next coordinate to move to
	mov [esi + TURTLE_OFFSET_POSITION_X], cx ; actually move to that coordinate
	jmp move_left_loop
	
	; turtle is supposed to move vertically, decide whether up or down
move_decode_vertical_movement: 
	mov ecx, [ebp + 16]; get the distance to move
	push ecx; supply the get_[positive/negative]_move_destination with the 'distance' argument
	mov ecx,0
	mov cx, [esi + TURTLE_OFFSET_POSITION_Y] ; get the turtle's 'y' coordinate
	push ecx ; supply the turtle's 'y' coordinate for destination calculation (since we know we will be moving horizontally)
	cmp bl, 2
	je move_down ; if direction == 10 , then we move down, otherwise we move up
move_up:	; move up
	mov ecx, IMAGE_WIDTH - 1; 
	push ecx; provide IMAGE_WIDTH - 1 as the "edge coordinate"
	call get_positive_move_destination
	add esp, 3*4; clear the stack
	; check if turtle has to leave a trail
	mov cx, [esi + TURTLE_OFFSET_PEN_STATE]
	cmp cx, 0
	je move_up_loop_start ; if pen is lowered, then we need to paint all pixels on the path
	; the pen is raised => we can just "teleport" to the target position
	mov [esi + TURTLE_OFFSET_POSITION_Y], ax  ; we can just set the x coordinate (no need to call set_position since y will not change)
	jmp move_finish

move_up_loop_start:
	; prepare arguments for 'paint_current_position' (arguments in registers because this will speed up execution significantly + it is a leaf function)
	; esi already contains the pointer to attributes
	mov ebx, [ebp + 8] ; prepare the pointer to bitmap
move_up_loop:
	push ax
	call paint_current_position ; we have just "arrived" at this current position, so we should paint it.
	pop ax
	mov cx, [esi + TURTLE_OFFSET_POSITION_Y]; get the current 'y' position
	cmp cx, ax
	jge move_finish ; if we have arrived at the target position : exit the loop
	add cx, 1; get the next coordinate to move to
	mov [esi + TURTLE_OFFSET_POSITION_Y], cx ; actually move to that coordinate
	jmp move_up_loop
	
move_down:	; move down
	; the distance and turtle's position have already been provided: just get the move destination
	call get_negative_move_destination
	add esp, 2*4; clear the stack
	; check if turtle has to leave a trail
	mov cx, [esi + TURTLE_OFFSET_PEN_STATE]
	cmp cx, 0
	je move_down_loop_start ; if pen is lowered, then we need to paint all pixels on the path
	; the pen is raised => we can just "teleport" to the target position
	mov [esi + TURTLE_OFFSET_POSITION_Y], ax  ; we can just set the y coordinate (no need to call set_position since x will not change)
	jmp move_finish

move_down_loop_start:
	; prepare arguments for 'paint_current_position' (arguments in registers because this will speed up execution significantly + it is a leaf function)
	; esi already contains the pointer to attributes
	mov ebx, [ebp + 8] ; prepare the pointer to bitmap
move_down_loop:
	push ax
	call paint_current_position ; we have just "arrived" at this current position, so we should paint it.
	pop ax
	mov cx, [esi + TURTLE_OFFSET_POSITION_Y]; get the current 'y' position

	cmp cx, ax
	jle move_finish ; if we have arrived at the target position : exit the loop
	sub cx, 1; get the next coordinate to move to
	mov [esi + TURTLE_OFFSET_POSITION_Y], cx ; actually move to that coordinate
	jmp move_down_loop
	
move_finish:	; epilogue (exit the function)		
	pop esi; restore non-volatile the registers
	pop ebx
	mov esp, ebp
	pop ebp 
    ret         ; Return control to the caller


; ======== Tool: Calculate negative movement destination ========
get_negative_move_destination:
;description: 
;	returns clamped destination position (if turtle requests a destination off the image, will return 0 - position at the edge
;arguments:
;	[esp + 12] - distance to move in the negative direction
;	[esp + 8] - starting position on an axis (pass here the current coordinate of the turtle)
;return value:
;	eax - the final, valid destination coordinate
	; prologue
	; save the caller's frame pointer
	push ebp
	mov ebp, esp

	; try to move exactly as instructions say
	mov eax, [esp + 8]
	sub eax, [esp + 12]

	jo get_negative_move_destination_fix ; no overflow happened: we can return the calculated destination
	jc get_negative_move_destination_fix ; no carry happened: we can return the calculated destination
	; no overflow happened: turtle tries to move to a valid coordinate
get_negative_move_destination_finish:	; epilogue (exit the function)		
	mov esp, ebp
	pop ebp 
    ret         ; Return control to the caller (eax contains the valid target coordinate value)
get_negative_move_destination_fix:
	mov eax, 0; turtle should stop at the edge of the image
	jmp get_negative_move_destination_finish

; ======== Tool: Calculate positive movement destination ========
get_positive_move_destination:
;description: 
;	returns clamped destination position (if turtle requests a destination off the image, will return $a2 - position at the edge
;arguments:
;	[esp + 16] - distance to move in the positive direction
;	[esp + 12] - starting position on an axis (pass here the current coordinate of the turtle)
;	[esp + 8] - greatest valid coordinate in an axis (the "edge" of the image)
;return value:
;	eax - the final, valid destination coordinate
	; prologue
	; save the caller's frame pointer
	push ebp
	mov ebp, esp

	; try to move exactly as instructions say
	mov eax, 0
	mov ax, [esp + 12]; load the starting position
	add ax, [esp + 16]; add the distance to move
	; check if target coordinate is valid
	jo get_positive_move_destination_fix ; turtle tries to move off the image so much that an overflow happened (we are treating the numbers as unsigned, so overflow happens)
	jc get_positive_move_destination_fix ; if we somehow ended up adding two "negative" (two's complement-wise) numbers, we will treat this as an overflow as well
	cmp ax, [esp + 8]; check how the target coordinate relates to the greatest valid coordinate
	jg get_positive_move_destination_fix ; turtle tries to move off the image	
	
	; turtle tries to move to a valid spot: simply allow it to do so
get_positive_move_destination_finish:	; epilogue (exit the function)	
	mov esp, ebp
	pop ebp 
    ret         ; Return control to the caller (eax contains the valid target coordinate value)
get_positive_move_destination_fix:
	mov ax, [esp+8]; turtle should stop at the edge of the image
	jmp get_positive_move_destination_finish
	
; ======== Tool: return smaller value ========
min:
;description: 
;	returns the smaller argument's value (both arguments and output are expected to be unsigned)
;arguments:
;	[esp + 12] - 1st value to compare
;	[esp + 8] - 2nd value to compare
;return value:
;	eax - the value of the smaller argument
	; prologue
	; save the caller's frame pointer
	push ebp
	mov ebp, esp
	;compare the arguments
	mov eax, [esp + 8]
	mov ecx, [esp + 12]
	cmp eax, ecx
	jle min_finish ; eax is is smaller than (or equal) ecx : do nothing (we will just return eax)
	; ecx is smaller than eax
	mov eax, ecx; make sure to return the smaller value
min_finish:	; epilogue (exit the function)				
	mov esp, ebp
	pop ebp 
    ret         ; Return control to the caller

paint_current_position:
;description: 
;	sets the color of specified pixel
;	should be called only if the pen is lowered
;arguments:
;	esi - pointer to turtle attributes
;	ebx - pointer to bitmap
;read turtle attributes:
;	'word', [esi + TURTLE_OFFSET_POSITION_X] - x coordinate
;	'byte', [esi + TURTLE_OFFSET_POSITION_Y] - y coordinate - (0,0) - bottom left corner
;	'dword', [esi + TURTLE_OFFSET_PEN_COLOR] - 0x00RRGGBB - pixel color

;return value: none
	; prologue (save the caller's frame pointer)
	push ebp
	mov ebp, esp
		
	; pixel address calculation
	mov ecx, 0
	mov cx, [esi + TURTLE_OFFSET_POSITION_Y] ; cx = 'Y'

	mov eax, 0
	mov ax, BYTES_PER_ROW
	mul ecx ; eax = 'Y' * BYTES_PER_ROW
	mov ecx, 0
	mov cx, [esi + TURTLE_OFFSET_POSITION_X] ; cx = 'X'
	mov edx, ecx ; edx = 'X'
	shl ecx, 1 ; ecx = 2 * 'X'
	add ecx, edx ; ecx = 3 * 'X' = (3 * 'X' + 'X')
	add eax, ecx ; eax = 3 * 'X' + 'Y' * BYTES_PER_ROW

	mov ecx, [ebx + 10] ; obtain the offset of the pixel array
	add ecx, ebx; obtain the adress of the pixel array
	add eax, ecx; obtain the adress of the pixel	
	; set new color

	mov ecx ,[esi + TURTLE_OFFSET_PEN_COLOR]; load the pen color
	mov [eax], cl; store B
	shr ecx, 8 ; prepare G
	mov [eax+1], cl; store G
	shr ecx, 8 ; prepare R
	mov [eax+2], cl; store R

;	move $t0, $s3 		#load the pen color
;	sb $t0, ($t2)		#store B
;	srl $t0, $t0,8
;	sb $t0, 1($t2)		#store G
;	srl $t0, $t0,8
;	sb $t0, 2($t2)		#store R
	; epilogue (exit the function)				
	mov esp, ebp
	pop ebp 
    ret         ; Return control to the caller
	