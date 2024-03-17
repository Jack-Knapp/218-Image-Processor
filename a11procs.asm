; *****************************************************************************
;  Description: Practice File IO, IO Buffering, and OS Interactions through image manip
; ***********************************************************************
;  Data declarations
;	Note, the error message strings should NOT be changed.
;	All other variables may changed or ignored...

section	.data

; -----
;  Define standard constants.

LF		equ	10				; line feed
NULL		equ	0			; end of string
SPACE		equ	0x20		; space

TRUE		equ	1
FALSE		equ	0

SUCCESS		equ	0			; Successful operation
NOSUCCESS	equ	1			; Unsuccessful operation

STDIN		equ	0			; standard input
STDOUT		equ	1			; standard output
STDERR		equ	2			; standard error

SYS_read	equ	0			; system call code for read
SYS_write	equ	1			; system call code for write
SYS_open	equ	2			; system call code for file open
SYS_close	equ	3			; system call code for file close
SYS_fork	equ	57			; system call code for fork
SYS_exit	equ	60			; system call code for terminate
SYS_creat	equ	85			; system call code for file open/create
SYS_time	equ	201			; system call code for get time

O_CREAT		equ	0x40
O_TRUNC		equ	0x200
O_APPEND	equ	0x400

O_RDONLY	equ	000000q			; file permission - read only
O_WRONLY	equ	000001q			; file permission - write only
O_RDWR		equ	000002q			; file permission - read and write

S_IRUSR		equ	00400q
S_IWUSR		equ	00200q
S_IXUSR		equ	00100q

; -----
;  Define program specific constants.

GRAYSCALE	equ	0
BRIGHTEN	equ	1
DARKEN		equ	2

MIN_FILE_LEN	equ	5
BUFF_SIZE	equ	1000000			; buffer size

; -----
;  Local variables for getArguments() function.

eof		db	FALSE

usageMsg	db	"Usage: ./imageCvt <-gr|-br|-dk> <inputFile.bmp> "
		db	"<outputFile.bmp>", LF, NULL
errIncomplete	db	"Error, incomplete command line arguments.", LF, NULL
errExtra	db	"Error, too many command line arguments.", LF, NULL
errOption	db	"Error, invalid image processing option.", LF, NULL
errReadName	db	"Error, invalid source file name.  Must be '.bmp' file.", LF, NULL
errWriteName	db	"Error, invalid output file name.  Must be '.bmp' file.", LF, NULL
errReadFile	db	"Error, unable to open input file.", LF, NULL
errWriteFile	db	"Error, unable to open output file.", LF, NULL

; -----
;  Local variables for processHeaders() function.

HEADER_SIZE	equ	54

errReadHdr	db	"Error, unable to read header from source image file."
		db	LF, NULL
errFileType	db	"Error, invalid file signature.", LF, NULL
errDepth	db	"Error, unsupported color depth.  Must be 24-bit color."
		db	LF, NULL
errCompType	db	"Error, only non-compressed images are supported."
		db	LF, NULL
errSize		db	"Error, bitmap block size inconsistent.", LF, NULL
errWriteHdr	db	"Error, unable to write header to output image file.", LF,
		db	"Program terminated.", LF, NULL

; -----
;  Local variables for getRow() function.

buffMax		dq	BUFF_SIZE
curr		dq	BUFF_SIZE
wasEOF		db	FALSE
pixelCount	dq	0

errRead		db	"Error, reading from source image file.", LF,
		db	"Program terminated.", LF, NULL

; -----
;  Local variables for writeRow() function.

errWrite	db	"Error, writting to output image file.", LF,
		db	"Program terminated.", LF, NULL


; ------------------------------------------------------------------------
;  Unitialized data

section	.bss

localBuffer	resb	BUFF_SIZE
header		resb	HEADER_SIZE


; ############################################################################

section	.text

; ***************************************************************
;  Routine to get arguments.
;	Check image conversion options
;	Verify files by atemptting to open the files (to make
;	sure they are valid and available).

;  NOTE:
;	ENUM variables are 32-bits.

;  Command Line format:
;	./imageCvt <-gr|-br|-dk> <inputFileName> <outputFileName>

; -----
;  Arguments:
;	argc (value)	-	-	-	-	-	-	-	-	[RDI]
;	argv table (address)	-	-	-	-	-	-	[RSI]
;	image option variable, ENUM type, (address)	-	[RDX]
;	read file descriptor (address)	-	-	-	-	[RCX]
;	write file descriptor (address)	-	-	-	-	[R8]
;  Returns:
;	TRUE or FALSE

global getArguments
getArguments:
	push rbx

	mov rbx, 1		;load in a count
	mov r10, 0		;clear a reg

	;Error checking for CL Args
	;check arg count
	cmp rdi, 1
	je erUse

	;too many, too few arg checks
	cmp rdi, 4
	ja erExt
	cmp rdi, 4
	jb erInc

	
	optionCheck:
		;check for valid processing mode
		mov rax, qword[rsi+rbx*8]
		inc rbx

	firstChar:
		mov r10b, byte[rax]
		inc rax
		cmp r10b, '-'
		jne erOpt
		jmp modeGrey

	modeGrey:
		mov r10b, byte[rax]
		inc rax
		cmp r10b, 'g'
		jne modeLight

		mov r10b, byte[rax]
		inc rax
		cmp r10b, 'r'
		jne erOpt

		mov qword[rdx], 0
		jmp charNull

	modeLight:
		cmp r10b, 'b'
		jne modeDark

		mov r10b, byte[rax]
		inc rax
		cmp r10b, 'r'
		jne erOpt

		mov qword[rdx], 1
		jmp charNull

	modeDark:
		cmp r10b, 'd'
		jne erOpt

		mov r10b, byte[rax]
		inc rax
		cmp r10b, 'k'
		jne erOpt

		mov qword[rdx], 2
		jmp charNull

	charNull:
		mov r10b, byte[rax]
		cmp r10b, NULL
		jne erOpt
		jmp firstFile


		;--------------------------------------------------------------------------------------
		;mode arg has been validated and saved, now test first file passed
	firstFile:
		;load in string to start checking file extension
		mov rax, qword[rsi+rbx*8]

	fNameLoop:
		;to verify file extension, loop until ".", then check extension
		mov r10b, byte[rax]
		inc rax

		cmp r10b, NULL
		je erRdN
		cmp r10b, '.'
		jne fNameLoop
		jmp fExtVal
	
	fExtVal:
		mov r10b, byte[rax]
		inc rax
		cmp r10b, 'b'
		jne erRdN

		mov r10b, byte[rax]
		inc rax
		cmp r10b, 'm'
		jne erRdN

		mov r10b, byte[rax]
		inc rax
		cmp r10b, 'p'
		jne erRdN

		mov r10b, byte[rax]
		inc rax
		cmp r10b, NULL
		jne erRdN

		;file extension validated, attempt to open file
	fOpenVal:
		;prepare for the syscall
		push rdi
		push rsi
		push rdx
		push rcx
		push rbx
		push r8

		;syscall
		mov rax, SYS_open
		mov rdi, qword[rsi+rbx*8]
		mov rsi, O_RDONLY
		syscall

		;restoration
		pop r8
		pop rbx
		pop rcx
		pop rdx
		pop rsi
		pop rdi

		;check for an error on file open
		cmp rax, 0
		jl erRdF
		mov qword[rcx], rax		;save file descriptor
		inc rbx
		jmp secondFile


		; -------------------------------------------------------------------------------------
		;first file (OPEN) tested and passed, now test second file (WRITE)
	secondFile:
		;load in string to start checking file extension
		mov rax, qword[rsi+rbx*8]

	sNameLoop:
		mov r10b, byte[rax]
		inc rax

		cmp r10b, NULL
		je erWrN
		cmp r10b, '.'
		jne sNameLoop
		jmp sExtVal
	
	sExtVal:
		mov r10b, byte[rax]
		inc rax
		cmp r10b, 'b'
		jne erWrN

		mov r10b, byte[rax]
		inc rax
		cmp r10b, 'm'
		jne erWrN

		mov r10b, byte[rax]
		inc rax
		cmp r10b, 'p'
		jne erWrN

		mov r10b, byte[rax]
		inc rax
		cmp r10b, NULL
		jne erWrN

		;file extension validated, attempt to create file
	sOpenVal:
		push rdi
		push rsi
		push rdx
		push rcx
		push rbx
		push r8

		mov rax, SYS_creat
		mov rdi, qword[rsi+rbx*8]
		mov rsi, S_IRUSR | S_IWUSR
		syscall

		pop r8
		pop rbx
		pop rcx
		pop rdx
		pop rsi
		pop rdi

		cmp rax, 0		;check for an error
		jl erWrF
		mov qword[r8], rax 	;save file descriptor
		jmp getArgsSuccess


	;--------------------------------------------------------------------------------------
	;Args parsing passed/failed -> Errors / Results	


	erUse:
		mov rdi,  usageMsg
		jmp getArgsPrint

	erInc:
		mov rdi,  errIncomplete
		jmp getArgsPrint

	erExt:
		mov rdi,  errExtra
		jmp getArgsPrint

	erOpt:
		mov rdi,  errOption
		jmp getArgsPrint

	erRdN:
		mov rdi,  errReadName
		jmp getArgsPrint

	erRdF:
		mov rdi,  errReadFile
		jmp getArgsPrint

	erWrN:
		mov rdi,  errWriteName
		jmp getArgsPrint

	erWrF:
		mov rdi,  errWriteFile
		jmp getArgsPrint

		;print error message and return failure
	getArgsPrint:
		call printString
		mov rax, 0
		jmp getArgsEpi

	getArgsSuccess:
		mov rax, 1
		jmp getArgsEpi


	getArgsEpi:
		pop rbx

ret

; ***************************************************************
;  Read and verify header information
;	status = processHeaders(readFileDesc, writeFileDesc,
;				fileSize, picWidth, picHeight)

; -----
;  2 -> BM				(+0)
;  4 file size				(+2)
;  4 skip				(+6)
;  4 header size			(+10)
;  4 skip				(+14)
;  4 width				(+18)
;  4 height				(+22)
;  2 skip				(+26)
;  2 depth (16/24/32)			(+28)
;  4 compression method code		(+30)
;  4 bytes of pixel data		(+34)
;  skip remaining header entries

; -----
;   Arguments:
;	read file descriptor (value)	[RDI]
;	write file descriptor (value)	[RSI]
;	file size (address)				[RDX]
;	image width (address)			[RCX]
;	image height (address)			[R8]

;  Returns:
;	file size (via reference)
;	image width (via reference)
;	image height (via reference)
;	TRUE or FALSE


	;grab read file and start reading from it starting with the header and later write some shit 
	;over to the write file ----- >> Both files are already open, so initial data will be headers
	; header is 54 bytes w/ reserved space for loading it in!

global processHeaders
processHeaders:

		push rbx
		push r12

		;attempt to read in header from file
	readHeader:
		push rdi
		push rsi
		push rdx
		push rcx
		push r8

		mov rax, SYS_read
		mov rsi, header
		mov rdx, HEADER_SIZE
		syscall

		pop r8
		pop rcx
		pop rdx
		pop rsi
		pop rdi
		
		;check for successful read
		cmp rax, 0
		jl procErRdH
		jmp testSignature
	

		;error check header values and save them
	testSignature:
		;checking the signature
		mov rbx, 0
		mov al, byte[header+rbx]
		cmp al, 'B'
		jne procErFType

		inc rbx
		mov al, byte[header+rbx]
		cmp al, 'M'
		jne procErFType
		jmp saveFileSize

	saveFileSize:
		;saving in the file size
		inc rbx
		mov r10d, dword[header+rbx] 
		mov dword[rdx], r10d
		jmp saveHeaderSize

	saveHeaderSize:
		;saving in the header size
		add rbx, 8
		mov r12d, dword[header+rbx] 
		jmp savePicSize

	savePicSize:
		;saving in the photo dimensions
		add rbx, 8
		mov eax, dword[header+rbx]
		mov dword[rcx], eax

		add rbx, 4
		mov eax, dword[header+rbx]
		mov dword[r8], eax
		jmp testBitDepth
	
	testBitDepth:
		;validation for bit depth
		add rbx, 6
		mov eax, dword[header+rbx]
		cmp eax, 24
		jne procErBDepth
		jmp testCompression

	testCompression:
		;ensuring there is no compression
		add rbx, 2
		mov eax, dword[header+rbx]
		cmp eax, 0
		jne procErCType
		jmp testFileConsistency

	testFileConsistency:
		;make sure file is internally consistent
		add rbx, 4
		mov eax, dword[header+rbx]	;load size of image
		add eax, r12d				;add header size
		cmp eax, r10d				;compare against file size
		jne procErSize
		jmp writeHeader

	writeHeader:
		;copy header over into output file
		mov rax, SYS_write
		mov rdi, rsi
		mov rsi, header
		mov rdx, HEADER_SIZE
		syscall

		;check for successful write
		cmp rax, 0
		jl procErWrtH
		jmp procHeaderSuccess


	procErRdH:
		mov rdi, errReadHdr
		jmp procHeaderPrint

	procErFType:
		mov rdi, errFileType
		jmp procHeaderPrint

	procErBDepth:
		mov rdi, errDepth
		jmp procHeaderPrint
		
	procErCType:
		mov rdi, errCompType
		jmp procHeaderPrint
		
	procErSize:
		mov rdi, errSize
		jmp procHeaderPrint
		
	procErWrtH:
		mov rdi, errWriteHdr
		jmp procHeaderPrint
	
	procHeaderPrint:
		call printString
		mov rax, 0
		jmp procHeadEpi

	procHeaderSuccess:
		mov rax, 1
		jmp procHeadEpi

	procHeadEpi:
		pop r12
		pop rbx

ret

; ***************************************************************
;  Return a row from read buffer
;	This routine performs all buffer management

; ----
;  HLL Call:
;	status = getRow(readFileDesc, picWidth, rowBuffer);

;   Arguments:
;	read file descriptor (value)	[RDI]
;	image width (value)				[RSI]
;	row buffer (address)			[RDX]
;  Returns:
;	TRUE or FALSE

; -----
;  This routine returns TRUE when row has been returned
;	and returns FALSE only if there is an
;	error on read (which would not normally occur)
;	or the end of file.

;  The read buffer itself and some misc. variables are used
;  ONLY by this routine and as such are not passed.

		;#bytes in line  = 3*Width
		;start by grabbing buff size from file and storing into local buffer
		;then grab one char at a time from local and save into cpp buff until local is empty
		;then go back to file to grab another buffer and store into local buffer
		;rinse and repeat until end of line
		; if eof is reached return data + false
		; row is gotten when rbx == rcx

global getRow
getRow:
		push rbx
		mov rbx, 0		;use rbx to count #chars passed back to cpp

		;calc/store image byte width in rax
		mov rcx, rsi
		add rcx, rsi
		add rcx, rsi

	mainBuffLoop:

		;check for end of local buffer
		mov r10, qword[buffMax]
		mov r11, qword[curr]
		cmp r10, qword[curr]
		je	refillBuff
		jmp grabChar

		;if buffer fill, grab data from file
	refillBuff:
		;make sure EOF not reached
		mov r10b, byte[wasEOF]
		cmp r10b, FALSE
		jne retFail

		push rdi			;preparing for a syscall
		push rsi	
		push rdx
		push rcx
		push rbx
	
		mov rax, SYS_read	;reading in data to local buffer
		mov rsi, localBuffer
		mov rdx, BUFF_SIZE
		syscall

		pop rbx				;restoring registers
		pop rcx
		pop rdx
		pop rsi
		pop rdi
		
		;check for successful read
		cmp rax, 0
		jl getrErRd
		jmp updateBuff
		
	updateBuff:
		;update loop variables after read in
		mov qword[curr], 0
		mov qword[buffMax], rax

		;make sure something was read in
		mov r10, qword[buffMax]
		cmp r10, 0
		je noRead

		;trip EOF flag if appropriate
		cmp r10, BUFF_SIZE
		jb setEOF

		;prepare to move data from local buff to cpp buff
		jmp grabChar

	noRead:
		mov byte[wasEOF], 1
		jmp retFail

	setEOF:
		mov byte[wasEOF], 1
		jmp grabChar


	grabChar:
		; grab curr char, inc curr
		; store into cpp buff

		mov r10, qword[curr]
		mov al, byte[localBuffer+r10]
		add qword[curr], 1

		mov byte[rdx+rbx], al

		jmp adminBuffLoop


	adminBuffLoop:
		;loop control admin work
		inc rbx
		cmp rbx, rcx
		jne mainBuffLoop

		mov rax, 1		;return success
		jmp getRowEpi


	getrErRd:
		;print an error, then fail
		mov rdi, errRead
		call printString
		jmp retFail

	retFail:
		;just fail
		mov rax, 0
		jmp getRowEpi
	
	getRowEpi:
		pop rbx

ret


; ***************************************************************
;  Write image row to output file.
;	Writes exactly (width*3) bytes to file.
;	No requirement to buffer here.

; -----
;  HLL Call:
;	status = writeRow(writeFileDesc, pciWidth, rowBuffer);

;  Arguments are:
;	write file descriptor (value)	[RDI]
;	image width (value)				[RSI]
;	row buffer (address)			[RDX]	

;  Returns:
;	TRUE or FALSE

; -----
;  This routine returns TRUE when row has been written
;	and returns FALSE only if there is an
;	error on write (which would not normally occur).

global writeRow
writeRow:
		push rbx		;push a reg

		mov rbx, rsi	
		add rbx, rsi
		add rbx, rsi		; 3*Width in rbx

		mov rax, SYS_write	;write row to file
		mov rsi, rdx
		mov rdx, rbx
		syscall

		;check for successful write
		cmp rax, 0
		jl wRowErr
		mov rax, 1
		jmp wRowEpi

	wRowErr:
		;there was an error here
		mov rdi, errWrite
		call printString
		mov rax, 0
		jmp wRowEpi

	wRowEpi:
		pop rbx
ret


; ***************************************************************
;  Convert pixels to grayscale.

; -----
;  HLL Call:
;	status = imageCvtToBW(picWidth, rowBuffer);

;  Arguments are:
;	image width (value)		[RDI]
;	row buffer (address)	[RSI]
;  Returns:
;	updated row buffer (via reference)

global imageCvtToBW
imageCvtToBW:
	push rbx
	mov rbx, 0

	mov r10, rdi
	add r10, rdi
	add r10, rdi	;3*Width

	bwLoop:
		mov rax, 0
		mov rcx, 0
		mov rdx, 0
		mov cl, byte[rsi+rbx+0]	;load in each color and sum them
		add rax, rcx

		mov cl, byte[rsi+rbx+1]
		add rax, rcx
		
		mov cl, byte[rsi+rbx+2]
		add rax, rcx

		mov r11, 3					;div sum by 3
		div r11

		mov byte[rsi+rbx+0], al		;return modified colors
		mov byte[rsi+rbx+1], al
		mov byte[rsi+rbx+2], al

		add rbx, 3					;loop control admin
		cmp rbx, r10
		jne bwLoop
		jmp bwEpi

	bwEpi:
		pop rbx
ret


; ***************************************************************
;  Update pixels to increase brightness

; -----
;  HLL Call:
;	status = imageBrighten(picWidth, rowBuffer);

;  Arguments are:
;	image width (value)		[RDI]
;	row buffer (address)	[RSI]
;  Returns:
;	updated row buffer (via reference)

global imageBrighten
imageBrighten:

	push rbx
	mov rbx, 0

	mov r10, rdi
	add r10, rdi
	add r10, rdi			;3*Width

	brLoop:
		mov rax, 0
		mov rcx, 0
		mov rdx, 0
		mov cl, byte[rsi+rbx]	;load in color
		mov rax, rcx			;store a copy

		mov r11, 2
		div r11					;divide by 2

		add rax, rcx			;add back the copy
		cmp rax, 255			;check for out of range val
		ja brMax
		jmp brSave

	brMax:
		mov rax, 255		;replace out of range w/ Max val
		jmp brSave

	brSave:
		mov byte[rsi+rbx], al	;overwrite old value

		inc rbx					;loop admin control
		cmp rbx, r10
		jne brLoop
		jmp brEpi

	brEpi:
		pop rbx

ret

; ***************************************************************
;  Update pixels to darken (decrease brightness)

; -----
;  HLL Call:
;	status = imageDarken(picWidth, rowBuffer);

;  Arguments are:
;	image width (value)
;	row buffer (address)
;  Returns:
;	updated row buffer (via reference)

global imageDarken
imageDarken:

	push rbx
	mov rbx, 0

	mov r10, rdi
	add r10, rdi
	add r10, rdi		;As you know, 3*Width

	drLoop:
		mov rax, 0
		mov rdx, 0
		mov al, byte[rsi+rbx]	;clear some regs and load a color
		
		mov r11, 2				;divide it by 2
		div r11
		
		mov byte[rsi+rbx], al	;save it, overwriting old value

		inc rbx					;loop admin control
		cmp rbx, r10
		jne drLoop
		jmp drEpi

	drEpi:
		pop rbx

ret


; ******************************************************************
;  Generic function to display a string to the screen.
;  String must be NULL terminated.

;  Algorithm:
;	Count characters in string (excluding NULL)
;	Use syscall to output characters

;  Arguments:
;	- address, string
;  Returns:
;	nothing

global	printString
printString:
	push	rbx

; -----
;  Count characters in string.

	mov	rbx, rdi			; str addr
	mov	rdx, 0
strCountLoop:
	cmp	byte [rbx], NULL
	je	strCountDone
	inc	rbx
	inc	rdx
	jmp	strCountLoop
strCountDone:

	cmp	rdx, 0
	je	prtDone

; -----
;  Call OS to output string.

	mov	rax, SYS_write			; system code for write()
	mov	rsi, rdi			; address of characters to write
	mov	rdi, STDOUT			; file descriptor for standard in
						; EDX=count to write, set above
	syscall					; system call

; -----
;  String printed, return to calling routine.

prtDone:
	pop	rbx
	ret

; ******************************************************************

