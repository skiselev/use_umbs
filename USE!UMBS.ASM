; 1 tab = 4 spaces

;
; This is a rewrite of Marco van Zwetselaar's USE!UMBS.SYS v2.0 from 1991.
;
; Changes in this version (v2.3);
; * Segment addresses given as parameters are now verified to be in the UMA.
; * UMBs are now verified to be writable (ROM/bad RAM/no RAM will generate an error).
; * Added support for the XTMax (based on work by Matthieu Bucchianeri).
; * Minor size optimizations.
;
; Changes in the previous version (v2.2);
; * UMBs are now initialized to avoid parity errors.
; * Minor size optimizations.
;
; Changes in the version before that (v2.1);
; * This file assembles in NASM.
; * Optimizations to reduce memory usage.
; * Command line parameters are now used in CONFIG.SYS to specify address ranges for UMBs.
;
;   Example for a single 128 KB UMB starting at segment D000h:
;
;   DEVICE=USE!UMBS.SYS D000-F000
;
; Please report bugs to me at krille_n_@hotmail.com
;
; Thanks!
;
; Krister Nordvall
;

; This define enables support for the XTMax.
;%define XTMAX


;--------------------------------------------------------------------
; Skips the immediately following 1 byte instruction by using it
; as an immediate value to a dummy instruction.
; Destroys the contents of %1.
;
; SKIP1B
;	Parameters:
;		%1:		Any 8 bit general purpose register or F for flags.
;	Returns:
;		Nothing
;	Corrupts registers:
;		%1
;--------------------------------------------------------------------
%macro SKIP1B 1.nolist
	%ifidni		%1, f
		db	03Ch					; Opcode byte for CMP AL, <immed>
		;db	0A8h					; Alt. version TEST AL, <immed>
	%elifidni	%1, al
		db	0B0h					; Opcode byte for MOV AL, <immed>
	%elifidni	%1, ah
		db	0B4h					; Opcode byte for MOV AH, <immed>
	%elifidni	%1, bl
		db	0B3h					; Opcode byte for MOV BL, <immed>
	%elifidni	%1, bh
		db	0B7h					; Opcode byte for MOV BH, <immed>
	%elifidni	%1, cl
		db	0B1h					; Opcode byte for MOV CL, <immed>
	%elifidni	%1, ch
		db	0B5h					; Opcode byte for MOV CH, <immed>
	%elifidni	%1, dl
		db	0B2h					; Opcode byte for MOV DL, <immed>
	%elifidni	%1, dh
		db	0B6h					; Opcode byte for MOV DH, <immed>
	%else
		%error "Invalid parameter passed to SKIP1B"
	%endif
%endmacro

;--------------------------------------------------------------------
; Skips the immediately following 2 byte instruction by using it
; as an immediate value to a dummy instruction.
; Destroys the contents of %1.
;
; SKIP2B
;	Parameters:
;		%1:		Any 16 bit general purpose register or F for flags.
;	Returns:
;		Nothing
;	Corrupts registers:
;		%1
;--------------------------------------------------------------------
%macro SKIP2B 1.nolist
	%ifidni		%1, f
		db	03Dh					; Opcode byte for CMP AX, <immed>
		;db	0A9h					; Alt. version TEST AX, <immed>
	%elifidni	%1, ax
		db	0B8h					; Opcode byte for MOV AX, <immed>
	%elifidni	%1, cx
		db	0B9h					; Opcode byte for MOV CX, <immed>
	%elifidni	%1, dx
		db	0BAh					; Opcode byte for MOV DX, <immed>
	%elifidni	%1, bx
		db	0BBh					; Opcode byte for MOV BX, <immed>
	%elifidni	%1, sp
		db	0BCh					; Opcode byte for MOV SP, <immed>
	%elifidni	%1, bp
		db	0BDh					; Opcode byte for MOV BP, <immed>
	%elifidni	%1, si
		db	0BEh					; Opcode byte for MOV SI, <immed>
	%elifidni	%1, di
		db	0BFh					; Opcode byte for MOV DI, <immed>
	%else
		%error "Invalid parameter passed to SKIP2B"
	%endif
%endmacro

		NULL					equ		0
		TAB						equ		9
		LF						equ		10
		CR						equ		13
		SPACE					equ		32

		bRH_Command				equ		2
		wRH_Status				equ		3
		fpRH_BreakAddress		equ		14
		fpRH_CommandLine		equ		18


		org 0


		fpNextDeviceDriver		dd		-1
		wDeviceAttributeWord	dw		0E000h
		wOffsetStrategyRoutine	dw		StrategyRoutine
		wOffsetInterruptRoutine	dw		InterruptRoutine
		sDeviceName				db		'ZwetsUMB'

		fpRequestHeader			dd		0

Interrupt2FhHandler:
		cmp		ah, 43h
		je		SHORT RequestIsForMe

		db		0EAh					; Far jump opcode
fpOldInterrupt2FhHandler:
		dd		0						; Pointer filled in during initialization

RequestIsForMe:
		cmp		al, 10h
		jne		SHORT ReturnHandlerExists

		mov		bx, UMBController
		push	cs
		pop		es
		iret

ReturnHandlerExists:
		mov		al, 80h
		iret


StrategyRoutine:
		mov		[cs:fpRequestHeader], bx
		mov		[cs:fpRequestHeader+2], es
		retf


InterruptRoutine:
		push	es
		push	bx
		push	ax

		les		bx, [cs:fpRequestHeader]
		cmp		BYTE [es:bx+bRH_Command], 16
		jbe		SHORT .NotImplemented
		mov		ax, 8103h				; "Error: Unknown command" + "Done"
		SKIP2B	f
.NotImplemented:
Return:
		jmp		SHORT Install			; <-- Will be patched into 'mov ah, 1' - Set Done bit
		mov		[es:bx+wRH_Status], ax

		pop		ax
		pop		bx
		pop		es
		retf


UMBController:
; The first 5 bytes of Himem handlers are special and must not be changed.
		jmp		SHORT .CheckIfUMBorXMSrequest
		nop
		nop
		nop

.CheckIfUMBorXMSrequest:
		cmp		ah, 10h
		je		SHORT UMBrequest

JMPtoOurXMShandler:
		jmp		SHORT XMSrequest		; This jump is patched out during init if an existing XMS handler is detected
fpOldXMShandler	equ	JMPtoOurXMShandler+1
		db		0
		db		0
		db		0

UMBrequest:
		push	si
		push	cx
		push	bx

		SKIP2B	si
.wOffsetFreeUMBs:
		dw		0						; Offset filled in during init

		xor		cx, cx
		xchg	dx, cx					; DX = 0, CX = Requested block size

.Search:
		cs
		lodsw							; Load start address of range
		test	ax, ax					; Are we at the end of the list?
		jz		SHORT .NoBlockFound		; Jump if so
		mov		bx, ax					; Segment is returned in BX
		inc		ax						; Block already given away?
		cs
		lodsw							; Load length of block
		jz		SHORT .Search			; If yes, get next block
		cmp		dx, ax					; Is it larger than the largest found so far?
		ja		SHORT .CheckSize		; If not, check size to see if it's large enough
		mov		dx, ax					; It is so save it as the largest so far

.CheckSize:
		cmp		cx, ax					; Large enough to fulfill request?
		ja		SHORT .Search			; Jump if not

		mov		WORD [cs:si-4], 0FFFFh	; Mark as given away
		mov		dx, 1					; Return Success in AX and size of block in DX
		xchg	dx, ax
		pop		cx						; Remove BX from stack
		jmp		SHORT .Return

.NoBlockFound:
		pop		bx						; Restore BX
		mov		bl, 0B0h				; Return "Smaller UMB available" in BL
		test	dx, dx					; Size of largest block found = 0?
		jnz		SHORT .Return			; If not, assumption was correct
		inc		bx						; Yes, return "No UMBs available" instead

.Return:
		pop		cx
		pop		si
		retf


XMSrequest:
		test	ah, ah					; Get XMS version?
		jnz		SHORT .NotGetVersion

		xor		bx, bx					; Internal revision number
		cwd								; HMA not present
		jmp		SHORT .Return

.NotGetVersion:
		cmp		ah, 8					; Query extended memory?
		jne		SHORT .NotQueryExtendedMem
		cwd								; 0 KB extended memory

.NotQueryExtendedMem:
		mov		bl, 80h					; Error: Not implemented

.Return:
		xor		ax, ax					; Always return failure
		retf


Install:
		push	cx
		push	dx
		push	ds
		push	si

		push	cs
		pop		ds
		mov		WORD [Return], 01B4h	; 'mov ah, 1'

		mov		ah, 9
		mov		dx, s$Hello1
		int		21h
		mov		dx, s$Hello2
		int		21h
		mov		dx, s$Empty
		int		21h
		mov		dx, s$Hello3
		int		21h
		mov		dx, s$Empty
		int		21h
		mov		dx, s$Author
		int		21h
		mov		dx, s$Empty
		int		21h

		; Is there an XMS handler already?
		mov		ax, 4300h
		int		2Fh
		cmp		al, 80h
		jne		SHORT .OKtoInstall		; No, it's OK to install (with our handler)

		; Yes, patch out the short unconditional jump to our XMS handler
		mov		BYTE [JMPtoOurXMShandler], 0EAh		; 'jmp far ...'

		; Then get the address to the old handler and store it
		mov		ax, 4310h
		int		2Fh
		mov		[fpOldXMShandler], bx
		mov		[fpOldXMShandler+2], es

		; To reduce memory usage we also move the breakpoint to exclude our XMS handler
		mov		WORD [.wOffsetBreakpoint], XMSrequest

		; Tell the user we found an existing handler
		mov		ah, 9
		mov		dx, s$XMMfound
		int		21h
		mov		dx, s$Empty
		int		21h

		; Check if it services UMBs by trying to allocate far too much
		mov		ah, 10h
		cwd
		dec		dx
		call	FAR [fpOldXMShandler]

		; Assume we are not needed
		mov		dx, s$NotInstalled
		xor		ax, ax

		cmp		bl, 80h					; Error: Not implemented?
		je		SHORT .OKtoInstall
		jmp		.StoreBreakPointer

.OKtoInstall:
		; Get the breakpoint (Install or XMSrequest) to BX and store it as the start of the FreeUMBs list
		mov		bx, [.wOffsetBreakpoint]
		mov		[UMBrequest.wOffsetFreeUMBs], bx

		; Time to parse the command line in CONFIG.SYS
		lds		si, [fpRequestHeader]
		lds		si, [si+fpRH_CommandLine]

		push	cs						; For restoring DS later

		mov		cx, 4					; Hex digit count in CH = 0, Shift count in CL = 4
		xor		ah, ah					; WORD parameter count in AH
		; Scan for the end of the path+filename
.SearchForEndOfPathAndFilename:
		lodsb
		test	al, al					; MS-DOS 2.11 ends the path+filename with a NULL
		jz		SHORT .SearchForParameter
		cmp		al, SPACE				; MS-DOS 3.00 and 6.22 ends the path+filename with a SPACE
		jne		SHORT .SearchForEndOfPathAndFilename

		; We've found the end of the path+filename
.SearchForParameter:
		lodsb
		cmp		al, CR
		je		SHORT .EndOfLineEncountered
		cmp		al, LF					; This is only needed for the case where there are no parameters (DOS overwrites the CR with a SPACE or NULL)
		je		SHORT .EndOfLineEncountered
		cmp		al, SPACE
		je		SHORT .SearchForParameter
		cmp		al, TAB
		je		SHORT .SearchForParameter

		; We have the first byte of a parameter
		SKIP1B	dl
.NextHexDigit:
		lodsb
		inc		ch
		cmp		al, '9'
		jbe		SHORT .NotAtoF
		; Note that DOS converts everything to upper case so we don't have to!
		cmp		al, 'F'
		ja		SHORT .ParameterError
		cmp		al, 'A'
		jb		SHORT .ParameterError
		sub		al, 7
.NotAtoF:
		sub		al, '0'
		jb		SHORT .ParameterError
		shl		dx, cl
		or		dl, al
		and		ch, 3
		jnz		SHORT .NextHexDigit

		; We have a complete WORD in DX
		cmp		dh, 0A0h
		jb		SHORT .ParameterError	; Segment address given is below UMA
		inc		ah						; Increment WORD count
		sahf							; WORD count Odd or Even?
		jc		SHORT .FirstWordOfParameter
		sub		dx, [cs:bx-2]			; Convert end of range to length
		jbe		SHORT .ParameterError	; End of range below or equal to start of range

%ifdef XTMAX
		; Program the range
		push	ax
		push	bx
		mov		ax, [cs:bx-2]
		mov		bx, dx
		mov		dx, 26Dh				; UMB base register
		out		dx, ax
		add		dl, dh					; UMB pages count register
		xchg	bx, ax
		mov		cl, 7
		pop		bx
		shr		ax, cl					; Paragraphs to 2K pages
		out		dx, al
		shl		ax, cl					; 2K pages back to paragraphs (Clears CF)
		pop		dx
		jz		SHORT .ParameterError	; Range was smaller than 2KB
		xchg	dx, ax
		mov		cl, 4
%endif ; XTMAX

.FirstWordOfParameter:
		mov		[cs:bx], dx
		inc		bx
		inc		bx
		lodsb
		jc		SHORT .CheckIfDash
		cmp		al, CR
		je		SHORT .EndOfLineEncountered
		cmp		al, SPACE
		je		SHORT .SearchForParameter
		cmp		al, TAB
		je		SHORT .SearchForParameter
		SKIP2B	ax						; Fall through to .ParameterError
.CheckIfDash:
		cmp		al, '-'
		je		SHORT .NextHexDigit

.ParameterError:
		pop		ds						; DS = CS

		mov		dx, s$ParamError
		xor		ax, ax
		jmp		.StoreBreakPointer

.EndOfLineEncountered:
		test	ah, ah
		jz		SHORT .ParameterError	; No parameters at all

		pop		ds						; DS = CS

		mov		WORD [bx], 0			; End of Free UMBs block marker
		inc		bx
		mov		[.wOffsetBreakpoint], bx

		; We need to initialize the UMBs by writing to every address to avoid parity errors later when reading
		mov		si, [UMBrequest.wOffsetFreeUMBs]
		push	di

.InitNextBlock:
		lodsw							; Segment address of UMB to AX
		test	ax, ax
		jz		SHORT .AllBlocksInitialized
		xchg	bx, ax					; Save address in BX
		lodsw							; Block size in paragraphs to AX
		cwd
		xchg	dx, ax					; DX = Paragraph count, AX = Zero
		mov		di, ax					; Point ES:DI to start of UMB
.InitNextSegment:
		dec		ax						; AX = 0FFFFh (or -1)
		mov		es, bx
		cmp		dh, 10h					; Block larger than or equal to a full segment?
		jb		SHORT .LessThan64KB
.VerifyAgain1:
		mov		cx, 8000h				; We need to write (at least) a full 64 KB segment
		rep		stosw
		mov		ch, 80h
		repe	scasw					; Did what we just wrote stick?
		jne		SHORT .BadUMB			; No, either it's bad RAM (hardware problem) or ROM or just nothing (user error)
		inc		ax						; Yes, increment AX to zero and try again in case it was just a coincidental match
		jz		SHORT .VerifyAgain1
		dec		ax
		add		bh, 10h					; Add 64 KB to the segment address for the next iteration (if any)
		sub		dh, 10h					; Subtract 64 KB from the paragraph count
		jmp		SHORT .InitNextSegment
.LessThan64KB:
		mov		cl, 3
		shl		dx, cl					; Paragraphs to WORDs
		mov		bx, dx
		shl		bx, 1					; WORDs to BYTEs
.VerifyAgain2:
		mov		cx, dx					; WORD count to CX
		rep		stosw
		mov		cx, dx
		sub		di, bx
		repe	scasw
		jne		SHORT .BadUMB
		sub		di, bx
		inc		ax
		jz		SHORT .VerifyAgain2
		jmp		SHORT .InitNextBlock

.BadUMB:
		mov		ax, es
		mov		bx, s$BadSegment
		mov		cl, 4
.NextNibble:
		push	ax
		and		al, 0Fh
		cmp		al, 10
		sbb		al, 69h
		das
		mov		[bx], al
		pop		ax
		dec		bx
		shr		ax, cl
		jnz		SHORT .NextNibble
		mov		dx, s$BadUMB
		jmp		SHORT .StoreBreakPointer

.AllBlocksInitialized:
		pop		di

		; Get the handler for Interrupt 2Fh and store it
		mov		ax, 352Fh
		int		21h
		mov		[fpOldInterrupt2FhHandler], bx
		mov		[fpOldInterrupt2FhHandler+2], es

		; Then hook it
		mov		ax, 252Fh
		mov		dx, Interrupt2FhHandler
		int		21h

		; Tell the user we are installed
		mov		dx, s$Installed
		SKIP2B	ax
.wOffsetBreakpoint:
		dw		Install					; Default breakpoint offset is Install

.StoreBreakPointer:
		les		bx, [fpRequestHeader]
		mov		[es:bx+fpRH_BreakAddress], ax
		mov		[es:bx+fpRH_BreakAddress+2], cs

		mov		ah, 9
		int		21h						; Print Installed/NotInstalled/ParamError/BadUMB

		pop		si
		pop		ds
		pop		dx
		pop		cx
		jmp		Return


s$Hello1		db	  CR,LF,'ÕÍÍÍÍÍÍÍÍÍÍÍÍÍÍµ   Use!UMBs   ÆÍÍÍÍÍÍÍÍÍÍÍÍÍ¸',CR,LF
s$Empty			db			'³                                           ³',CR,LF,'$'
s$Hello2		db			'³        Upper Memory Block - Manager       ³',CR,LF,'$'
s$Hello3		db			'³   Works on any PC/XT/AT, either with or   ³',CR,LF
				db			'³    without Extended or Expanded Memory!   ³',CR,LF,'$'
s$XMMfound		db			'³     * found extended memory manager *     ³',CR,LF,'$'
s$Author		db			'³        Author: Marco van Zwetselaar       ³',CR,LF
				db			'³   dedicated it to the Public Domain 1991  ³',CR,LF,'$'
s$Installed		db			'ÔÍÍµ Version 2.3 ÆÍÍÍÍÍÍÍÍÍÍµ Installed! ÆÍÍ¾',CR,LF,LF,'$'
s$NotInstalled	db			'ÔÍµ Not Installed!  UMBs Managed Already! ÆÍ¾',CR,LF,LF,'$'
s$ParamError	db			'ÔÍµ Not Installed!  Invalid Command Line! ÆÍ¾',CR,LF,LF,'$'
s$BadUMB		db			'ÔÍµ Not Installed!  Bad UMB @ seg: 0000h! ÆÍ¾',CR,LF,LF,'$'
s$BadSegment equ s$BadUMB+38
