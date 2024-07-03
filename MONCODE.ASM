.386P

;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;;
		PAGE		,132
		TITLE		Protected Mode Monitor
		SUBTTL		Main Module (DOS loaded .EXE version)
;;		Author		Tony Hanratty
;;		Created		12/04/91
;;		Last Changed	02/12/92
;;
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;
;     >>>>>>> NOTE : SEGMENTS ARE LOADED IN THE FOLLOWING ORDER <<<<<<<
;
;   high memory ==>         (GDT)   <--\
;                           DUMMY	   |- Created at runtime
;                           (STACK) <--/
;                      /--> Stub GDT
;   (moved to RunSeg)  |--> DATA        (data group = DGROUP)
;                      \--> CODE        (code group = PGROUP)
;	low memory ===>			LOAD
;
;; =======================================================================

		include		moncomn.inc		;common equates
		include		moncode.inc		;strucs, equates
		include		mondesc.inc		;descriptor types


BOOTABLE_IMAGE		equ		1


; ----- Temporary declarations

		extrn	CommSetup:near
		extrn	SER_outch:near

; ----- External code declarations

		extrn	fdisk_io:near, FlopSys:near
		extrn	SetDisks:near, InitDiskSys:near

		extrn	fpinit:near, MathMon:near

		extrn	phexword:near, phexbyte:near, phexchar:near
		extrn	pstring:near, pchar:near, pcrlf:near, cls:near
		extrn	gethexword:near, gethexbyte:near
		extrn	pspace:near, pspace2:near, pspace3:near

		extrn	phexwordPRN:near, pspacePRN:near, pcrlfPRN:near
		extrn	pspace2PRN:near, pcharPRN:near, phexbytePRN:near
		extrn	enable_printer:near, disable_printer:near
		extrn	_PRNon:near, _PRNoff:near

		extrn	gkey:near, gkeye:near, Ucase:near, keystat:near

		extrn	PageModeOn:near, PageModeOff:near
		extrn	UpdateL25:near

		extrn	A20_Enable:near, KbdSys:near

		extrn	InitMemory:near, ShowMemChain:near
		extrn	AllocMem:near, DeAllocMem:near
		extrn	SaveChainStart:far

		extrn	SetdDPL:near, SetdType:near, SetdLimit:near
		extrn	SetdSystem:near, StartTask:near, GetdBase:near
		extrn	SetdBase:near, GetdLimit:near, GetdARB:near

		extrn	SetTrapVecs:near

; ----- External data declarations

		extrn	SeekStatus:byte
		extrn	IDTbase:byte, IDTlen:abs
		extrn	screenseg:word

		extrn	_dCS:byte, _dDS:byte, _dSS:byte, _dES:byte
		extrn	 dCS:abs,   dDS:abs,   dSS:abs,   dES:abs
		extrn	_dLoadSeg:byte, dLoadSeg:abs
		extrn	dScreen:abs, _dScreen:byte, dVdisk:abs, dNP:abs
		extrn	dDump:abs,   _dDump:byte
		extrn	GDTlen:abs, _dGDT:byte

; ---- Local code publics

		public	menuexit, showhelp, DSload, NewMenu
		public	getcommand, dumpseg, load_ESdumpseg
		public	_dump_block, beep, coldboot, LoadSegLen
		public	paddr, Address24


; ---- Local data publics

		;NONE

; ---- Local code publics

		;NONE




SERIAL		MACRO	c
			push	ax
			mov		al,c
			call	SER_outch
			pop		ax
			ENDM

 


;; =========================================================================
;;			REAL MODE ENTRY POINT FOR DOS
;;
;; This code is only executed once at startup, so we dont need to relocate
;; it to the runtime address. Hence, keep it in its own segment seperate
;; from the real monitor code and discard it after the relocation.
;;
;; =========================================================================


LoadSeg		SEGMENT para public 'CODE' USE16
			ASSUME	cs:LoadSeg, ds:MonData


MonInit		LABEL	near	;;;; NO 'CALLS' TILL STACK IS SETUP ;;;;;

; 1st setup a  stack somewhere harmless after the loadimage

		mov	ax,seg DummySeg		;=end of load immage
		mov	ss,ax			;SS:SP after load image for now
		mov	sp,8000h		;ie, somewhere harmless!

; ----- Setup a serial port for debug messages

		call	CommSetup

; ----- Use the BIOS (urghh!) to set 80x25 mode on display page 0

		mov	ax,3			;set video mode (80x25)
		int	10h
		mov	ax,0500h		;set active display page = 0
		int	10h
		mov	ah,1			;turn hardware cursor off
		mov	cx,0700h		;'cos we use a software one
		int	10h

; ----- Eval diff between runtime & loadtime addresses

		mov	bx,seg MonCode		;get load time MonCode
		sub	bx,RunSeg			;-RunTime = correction factor
		mov	cs:cor_factor,bx	;save loadtime/runtine diff

		mov	ax,seg MonData		;get load MonData
		mov	ds,ax				;DS --> current MonData
		sub	ax,bx				;- cor_factor = runtime DS
		mov	cs:RunTimeDS,ax		;save it

; ----- Setup RUNTIME descriptors in stub GDT (DS --> current MonData)

		mov	ax,seg MonGDT
		mov	es,ax				;ES:0000 --> load GDT

		mov	ax,cs:RunTimeDS		;get runtime MonData
		call	Address24		;DL:AX = 24 bit DS base addr

		mov	es:_dDS.sdesc_baselo,ax	;\
		mov	es:_dDS.sdesc_basehi,dl	; \  Set segment bases for
		mov	es:_dES.sdesc_baselo,ax	; /  protected mode switch
		mov	es:_dES.sdesc_basehi,dl	;/

		mov	ax,cs
		call	Address24
		mov	es:_dLoadSeg.sdesc_baselo,ax
		mov	es:_dLoadSeg.sdesc_basehi,dl

; ----- Put stack after DS (ie @ DummySeg). Limit already defined in GDT

		mov	ax,seg DummySeg			;Stack start seg
		sub	ax,cs:cor_factor		;=runtime SS
		call	Address24
		mov	es:_dSS.sdesc_baselo,ax		;set runtime SS base
		mov	es:_dSS.sdesc_basehi,dl

; ----- Setup screen descriptor base address (could be mono or colour)

		int	11h			;get equipment flag in AX
		and	al,00110000b		;keep screen type
		cmp	al,00110000b		;is it mono ?
		mov	ax,MonoSeg
		je	short SetScrBase		;yes, jump to load base addr
		mov	ax,ColorSeg
SetScrBase:	call	Address24
		mov	es:_dScreen.sdesc_baselo,ax
		mov	es:_dScreen.sdesc_basehi,dl

; ----- Set up IDT address. Its in MonData so add on its offset

		mov	ax,cs:RunTimeDS			;get runtime MonData
		call	Address24
		add	ax,offset IDTbase		;add on offset of IDT
		adc	dl,0
		mov	IDTbaselo,ax			;set 24 bit IDT address
		mov	IDTbasehi,dl

; ----- Set GDT runtime address and descriptor alias (its after the stack)

		mov	ax,seg DummySeg
		sub	ax,cs:cor_factor
		add	ax,STACK_LEN/16			;=runtime GDT segment
		push	ax				;save for stub copy
		call	Address24
		mov	GDTbaselo,ax			;save addr in MonData
		mov	GDTbasehi,dl
		mov	es:_dGDT.sdesc_baselo,ax	;and in the stubb GDT
		mov	es:_dGDT.sdesc_basehi,dl

; ----- Free RAM Starts After GDT, Pass Address And Ram Size To Memory Manager

	SERIAL	'1'

		mov	cx,ax			;save GDT address low in CX
		int	12h			;BIOS returns AX=total K
		shl	ax,6			;*64 = #paras
		mov	bx,ax			;put total paras in BX
		mov	ax,cx			;get back GDT address low

		add	ax,GDTlen		;bump past runtime GDT
		adc	dl,0			;to start of free RAM

; ----- BX=total memory paras, DL:AX=start address of free ram

	SERIAL	'2'

		call	SaveChainStart		;pass both to mem manager

	SERIAL	'3'

; ----- now shut down the DOS and the BIOS, kill all interrupts

		cli				;all interrupts off
		cld				;all furure counts upward

		mov	al,-1			;mask off all hardware ints
		out	21h,al			;from 1st and 2nd 8259
		out	0a1h,al			;dont use 2nd PIC at all

	SERIAL	'5'

; Reprogramme 1st 8259 to change interrupt vectors for IRQ 0-7
; from INTS 8-F to INTS 20 to 2F. (And say theres only 1 8259)

		mov	al,13h		;edge triggered, single mode, ICW4
		out	20h,al
		mov	al,20h		;IRQ0 = INT 20h <<<<<===== NB !!!
		out	21h,al		;    (00h-1Fh are INTEL reserved!)
		mov	al,9		;*NOT* nested, buffered, 8086 mode
		out	21h,al

	SERIAL	'6'


; Relocate monitor code & data to absolute runtime address. No need to
; copy the initialisation code in LoadSeg.

		mov	cx,seg DummySeg		;*MUST* be after last reloc seg
		sub	cx,seg MonCode		;=image length in paras
		shl	cx,3			;*8 = # words = counter

		mov	ax,RunSeg		;set ES:DI = destination
		mov	es,ax
		xor	di,di			;dest offset = 0000

		mov	ax,seg MonCode
		mov	ds,ax			;set DS:SI -> start of code
		xor	si,si			;source offset = 0000
		rep	movsw			;copy code and data

	SERIAL	'7'



; Now move stub GDT to end of relocated code (after stack)

		mov	ax,seg MonGDT		;point DS:SI to MonGDT
		mov	ds,ax
		xor	si,si

		pop	es			;get back runtime GDT seg
		xor	di,di
		mov	cx,GDTlen
		rep	movsb			;move it

	SERIAL	'8'


;;======================================================================;;
;;									;;
;;			SWITCH TO PROTECTED MODE			;;
;;									;;
;; Disable A20 gate in keyboard controller to stop 1M reflection	;;
;; Load GDTR & IDTR and switch to Prot mode				;;
;; Far jmp to clear the prefetch queue decoded in real mode		;;
;; Load up prot mode DS,ES,SS descriptors and stack			;;
;; Set IOPL to 3							;;
;; Go for a beer (this really should be 1st!)				;;
;;									;;
;;======================================================================;;

		call	A20_Enable		;enable A20, ignore return CF

	SERIAL	'9'

		mov	ax,seg MonData
		mov	ds,ax			;OK to use load seg vars
		lgdt	GDT			;load GDT register
		lidt	IDT			;and the IDT reg

		smsw	ax			;get machine status word in AX
		or	al,1			;set protected mode bit 0
		lmsw	ax			;in protected mode >>NOW<<

; --------- IN PROTECTED MODE NOW  (Running at privilage level 0) ---------

		db	0eah			;clear instruction pipeline
		dw	pm_farjmp		;with a far jump
		dw	dLoadSeg		;our selector in GDT

pm_farjmp:	mov	ax,dDS			;load segment selectors
		mov	ds,ax
		mov	ax,dES
		mov	es,ax
		mov	sp,STACK_TOP
		mov	ax,dSS
		mov	ss,ax

	SERIAL	'A'


		pushf				;put flags on stack
		mov	bp,sp			;point BP to them
		or	wptr [bp],3000h		;make sure IOPL = 3
		popf				;pop flags with IOPL set


; ----- Unmask hardware ints (IF flag still clear)

		mov	al,10111100b		;keyboard,timer & disk ints
		out	21h,al

	SERIAL	'B'

; ----- Finally do a FAR JMP to monitor cold boot entry point

		db	0eah			;hard coded far jump
		dw	coldboot		;runtime code offest
		dw	dCS				;and segment


; ----- Variables used by LoadSeg

cor_factor		dw	?		;used with CS: overrides
RunTimeDS		dw	?







OneTime_mess	LABEL	byte
 db "********************************************************************************"
 db "*                                  R A T O S                                   *"
 db "*                  P R O T E C T E D   M O D E   M O N I T O R                 *"
 db "*                             B U I L D   7.81/A                               *"
 db "*                               L O A D I N G                                  *"
 db "********************************************************************************"
 db cr,lf
 db eot

LoadSegLen	LABEL	byte			;for GDT descriptor limit

LoadSeg		ENDS

;------------------------------------------------------------------------
;--------------------- END OF INITIALISATION CODE -----------------------
;------------------------------------------------------------------------







; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;
; 			START OF MONITOR DATA SEGMENT
;
; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-

MonData		SEGMENT para public 'DATA' USE16

; ======================== Read/Write Data First ==========================

dumpseg		dw	0			;used by dump memory command
dumpoff		dw	0

fillend		dw	0			;used by fill memory command
fillchar	db	0

MenusOnFlag	db	1			;1=auto menus on, 0=off


SaveGDT		LABEL	qword			;to store processor regs
			db	6 dup (?)		;during dump registers cmd
SaveIDT		LABEL	qword
			db	6 dup (?)



; ----- Descriptor Table Registers
;
; GDT	6 bytes loaded into GDT register by LGDT instruction.
; IDT	6 bytes loaded into IDT register by LIDT instruction.
;
; Both base addresses are setup by LoadSeg

GDT			LABEL	qword
			dw	GDTlen
GDTbaselo	dw	0			;base low\ set by LoadSeg
GDTbasehi	db	0			;base hi /
			db	0			;reserved

IDT			LABEL	qword
			dw	IDTlen
IDTbaselo	dw	0			;base lo\  set by LoadSeg
IDTbasehi	db	0			;base hi/
			db	0			;reserved


aDesc		SEGdesc	<>			;a descriptor copy

SegRegName	db	'CS:',null		;used in display regs cmd


; ==================== All Constant Data After Here =======================


;
; Top level menu commands
;
_dumpmem_cmd		equ	'D','M'
_fillmem_cmd		equ	'F','M'
_modifymem_cmd		equ	'M','M'
_inport_cmd			equ	'I','P'
_outport_cmd		equ	'O','P'
_floppy_cmd			equ	'F','H'
_keyboard_cmd		equ	'K','C'
_config_cmd			equ	'C','M'
_clearscrn_cmd		equ	'C','S'
_dumpregs_cmd		equ	'D','R'
_udopcode_cmd		equ	'U','O'
_segNP_cmd			equ	'N','P'
_divzero_cmd		equ	'D','Z'
_starttask_cmd		equ	'S','T'
_vdiskmem_cmd		equ	'D','V'
_memchain_cmd		equ	'M','C'
_floatpoint_cmd		equ	'F','P'



MainMenu	LABEL		byte
		CmdTabEntry		<_dumpmem_cmd, dumpmem>
		CmdTabEntry		<_modifymem_cmd, modifymem>
		CmdTabEntry		<_fillmem_cmd, fillmem>
		CmdTabEntry		<_inport_cmd, inport>
		CmdTabEntry		<_outport_cmd, outport>
		CmdTabEntry		<_floppy_cmd, FlopSys>
		CmdTabEntry		<_keyboard_cmd, KbdSys>
		CmdTabEntry		<_config_cmd, ConfigMon>
		CmdTabEntry		<_showhelp_cmd, showhelp>
		CmdTabEntry		<_clearscrn_cmd, cls>
		CmdTabEntry		<_dumpregs_cmd, pRegisters>
		CmdTabEntry		<_udopcode_cmd, udop>
		CmdTabEntry		<_segNP_cmd, SNPtest>
		CmdTabEntry		<_divzero_cmd, DivZTest>
		CmdTabEntry		<_starttask_cmd, StartTask>
		CmdTabEntry		<_vdiskmem_cmd, dumpVdisk>
		CmdTabEntry		<_memchain_cmd, ShowMemChain>
		CmdTabEntry		<_floatpoint_cmd, MathMon>
		db	0		;; End of menu


MainHelp	LABEL	byte
	db	lf,lf,cr,'MAIN MENU COMMANDS...'
	db	cr,lf,' '
	db	_dumpmem_cmd,		' Dump Memory                   '
	db	_clearscrn_cmd,		' Clear Screen'
	db	cr,lf,' '
	db	_fillmem_cmd,		' Fill Memory                   '
	db	_dumpregs_cmd,		' Display CPU Regs'
	db	cr,lf,' '
	db	_modifymem_cmd,		' Modify Memory                 '
	db	_udopcode_cmd,		' Undefined Opcode Test'
	db	cr,lf,' '
	db	_inport_cmd,		' Read I/O Port                 '
	db	_segNP_cmd,		' Seg Not Present Test'
	db	cr,lf,' '
	db	_outport_cmd,		' Write I/O Port                '
	db	_divzero_cmd,		' Divide By Zero Test'
	db	cr,lf,' '
	db	_floppy_cmd,		' Floppy Disk Menu              '
	db	_starttask_cmd,		' Start Protected Task'
	db	cr,lf,' '
	db	_keyboard_cmd,		' Keyboard Menu                 '
	db	_vdiskmem_cmd,		' Dump VDISK Mem >1M'
	db	cr,lf,' '
	db	_config_cmd,		' Config Menu                   '
	db	_memchain_cmd,		' Show Memory Chain'
	db	cr,lf,' '
	db	_showhelp_cmd,		' This Help Menu                '
	db	_floatpoint_cmd,	' Floating Point Menu'
	db	cr,lf,lf,null




;
; Config Menu Commands
;
_pageon_cmd		equ	'P','O'
_pageoff_cmd		equ	'P','F'
_enableprn_cmd		equ	'E','P'
_disableprn_cmd		equ	'D','P'
_menuson_cmd		equ	'M','O'
_menusoff_cmd		equ	'M','F'
_coldreboot_cmd		equ	'R','B'
_warmreboot_cmd		equ	'C','B'
_colourtest_cmd		equ	'C','T'
_disktype_cmd		equ	'S','D'




ConfigMenu	LABEL	byte
		CmdTabEntry		<_pageon_cmd, PageModeOn>
		CmdTabEntry		<_pageoff_cmd, PageModeOff>
		CmdTabEntry		<_enableprn_cmd, enable_printer>
		CmdTabEntry		<_disableprn_cmd, disable_printer>
		CmdTabEntry		<_menuson_cmd, menuson>
		CmdTabEntry		<_menusoff_cmd, menusoff>
		CmdTabEntry		<_coldreboot_cmd, Reboot>
		CmdTabEntry		<_warmreboot_cmd, coldboot>
		CmdTabEntry		<_colourtest_cmd, ColourTest>
		CmdTabEntry		<_showhelp_cmd, showhelp>
		CmdTabEntry		<_disktype_cmd, SetDisks>
		CmdTabEntry		<_menuexit_cmd, menuexit>
		db	0		;; End of menu



ConfigHelp	LABEL	byte
	db	lf,lf,cr,'CONFIG MENU COMMANDS...'
	db	cr,lf,' '
	db	_pageon_cmd,		' Screen Paging On              '
	db	_coldreboot_cmd,	' Cold Reboot'
	db	cr,lf,' '
	db	_pageoff_cmd,		' Screen Paging Off             '
	db	_warmreboot_cmd,	' Warm Reboot'
	db	cr,lf,' '
	db	_enableprn_cmd,		' Enable Printer                '
	db	_colourtest_cmd,	' Colour Test'
	db	cr,lf,' '
	db	_disableprn_cmd,	' Disable Printer               '
	db	_showhelp_cmd,		' Help'
	db	cr,lf,' '
	db	_menuson_cmd,		' Menu On                       '
	db	_disktype_cmd,		' Set Disk & Drive Types'
	db	cr,lf,' '
	db	_menusoff_cmd,		' Menus Off                     '
	db	_menuexit_cmd,		' Quit'
	db	cr,lf,lf,null





coltest_mess	LABEL	byte
		db	cr,lf
		db	_fg_BROWN,'This line in brown',cr,lf
		db	_fg_WHITE,'This line in white',cr,lf
		db	_fg_BOLD_ON
		db	_fg_BLUE, 'This line in bright blue',cr,lf
		db	_fg_GREEN,'This line in bright green',cr,lf
		db	_fg_CYAN, 'This line in bright cyan',cr,lf
		db	_fg_RED,'This line in bright red',cr,lf
		db	_fg_PURPLE,'This line in bright purple',cr,lf
		db	_fg_BROWN,'This line in bright brown',cr,lf
		db	_fg_WHITE,'This line in bright white',cr,lf
		db	_fg_BOLD_OFF
		db	null



signonmess	db	cr,lf,_fg_BROWN, _fg_BOLD_ON
		db	'Protected Mode Monitor (C) 1990',cr,lf
		db	'Monitor Cold Boot'
		db	_fg_WHITE, _fg_BOLD_OFF
		db	cr,lf,lf,bell, _CLR_EOL, null




prompt		db	'+++',null
badcommess	db	' ?',cr,lf,bell,null
bytevalmess	db	'  Byte value :',null
asciivalmess	db	'  Ascii char :',null

ProtMess	db	cr,lf,'Now running in protected mode',lf,cr,null
MSWmess		db	'  Machine Status Word ',null
IOPLmess	db	'I/O privilage level = ',null
pDescTabQmess	db	cr,lf,'<G>lobal, <I>nterrupt or <Q>uit : ',null
A20failMess	db	cr,lf,'8042 write failure, A20 still gated,'
		db	cr,lf,'Continuing switch to protected mode.'
		db	cr,lf,null
MenusOn_mess	db	cr,lf,'Menus On',cr,lf,null
MenusOff_mess	db	cr,lf,'Menus Off',cr,lf,null



GDTregname	db	'GDTR:  ',null
IDTregname	db	'IDTR:  ',null
LDTregname	db	'LDTR:  ',null
TRregname	db	'TR:    ',null



Limitmess	db	'Limit:',null
Basemess	db	'  Base:',null
Reservedmess	db	'  Reserved:',null

pDTtitlemess	db	cr,lf,lf,_fg_BOLD_ON
		db	'Sel  DPL Type'
		db	'               '
		db	'P C R W A E   Base   Limit Words Dest'
		db	_fg_BOLD_OFF,cr,lf,null

CODEmess	db	'CODE               ',null
DATAmess	db	'DATA               ',null

SysSeg_t0	db	'Invalid            ',null
SysSeg_t1	db	'Free 286 TSS       ',null
SysSeg_t2	db	'LDT                ',null
SysSeg_t3	db	'Busy 286 TSS       ',null
SysSeg_t4	db	'286 Call Gate      ',null
SysSeg_t5	db	'Task Gate          ',null
SysSeg_t6	db	'286 Interrupt Gate ',null
SysSeg_t7	db	'286 Trap Gate      ',null
SysSeg_t8	db	'Invalid            ',null
SysSeg_t9	db	'Free 386 TSS       ',null
SysSeg_tA	db	'Intel Reserved     ',null
SysSeg_tB	db	'Busy 386 TSS       ',null
SysSeg_tC	db	'386 Call Gate      ',null
SysSeg_tD	db	'Intel Reserved     ',null
SysSeg_tE	db	'386 Interrupt Gate ',null
SysSeg_tF	db	'386 Trap Gate      ',null


SysSegTable	dw	SysSeg_t0, SysSeg_t1, SysSeg_t2, SysSeg_t3
		dw	SysSeg_t4, SysSeg_t5, SysSeg_t6, SysSeg_t7
		dw	SysSeg_t8, SysSeg_t9, SysSeg_tA, SysSeg_tB
		dw	SysSeg_tC, SysSeg_tD, SysSeg_tE, SysSeg_tF



		PUBLIC	MonDataEnd
MonDataEnd	LABEL	byte

MonData		ENDS

;------------------------------------------------------------------------
;--------------------------- END OF MONITOR DATA ------------------------
;------------------------------------------------------------------------









; =========================================================================
;
; 			START OF MONITOR CODE SEGMENT
;
; =========================================================================


MonCode		SEGMENT	para public 'CODE' USE16
		ASSUME	cs:MonCode,ds:MonData



; ========================================================================
;
;			MONITOR COLD BOOT ENTRY POINT
;
; ========================================================================
;
; Dont use any stack till SS:SP initialised. The only regs we are sure
; about here are CS:IP, nothing else.
;
coldboot:	cli					;INTs off
		clts					;reset TS flag
		
; Load protected mode segment selectors and stack pointer

		mov	ax,dDS
		mov	ds,ax
		mov	ax,dES
		mov	es,ax
		mov	ax,dSS
		mov	ss,ax
		mov	sp,STACK_TOP

		mov	al,20h				;reset 8259 PICs
		out	20h,al
		out	0a0h,al

		in	al,61h				;reset keyboard
		or	al,80h
		out	61h,al
		and	al,7fh
		out	61h,al

; Check current printer status

		mov	bx,offset _PRNon		;point to on routine
		mov	dx,0379h			;printer status port
		in	al,dx				;read it
		and	al,11111000b			;clear boring bits
		cmp	al,11011000b			;check online, OK etc
		je	short setPRN				;jump if no probs
		mov	bx,offset _PRNoff		;else load off routine
setPRN:		call	bx				;call selected routine

		call	InitMemory			;reset memory manager
		call	InitMonTSS			;setup TSS & TR
		call	SetTrapVecs

		sti					;allow INTs

		call	InitDiskSys			;reset floppy system


; --------------------- Print the signon message ---------------------

		mov	si,offset signonmess		;print signon text
		call	pstring

		mov	si,offset MainMenu		;pnt to top level menu
		mov	di,offset MainHelp		;and its command help

; -------------------- Fall Through To GetCommand --------------------





;===========================================================================
;  Menu Handler...
;
;	DS:SI --> command table for current menu
;	DS:DI --> help text for current menu
;===========================================================================
;
getcommand	PROC	near
		push	si				;save cmd table ptr
		push	di				;save help ptr

gcloop:		mov	si,offset prompt	;print monitor prompt
		call	pstring
		call	UpdateL25

; ----- get 1st character of command

		call	gkey			;get ascii in AL (no echo)
		cmp	al,cr			;carriage return ?
		je	short cmd_blank		;yep - start again
		call	Ucase			;convert to upper case
		mov	bl,al			;and save it in BL
		call	pchar			;then print it
		cmp	bl,'A'			;check against lowest alpha
		jb	short cmd_not_fnd		;too low - bomb out

; ----- get 2nd command character

		call	gkey			;ascii in AL, scan in AH
		cmp	al,space
		jb	short cmd_not_fnd
		call	Ucase
		mov	ah,bl			;AH:AL = command
		xchg	ah,al			;AL:AH = command
		mov	bl,ah
		call	pchar

		pop	di			;and help text
		pop	si			;reload cmd table ptr
		push	si
		push	di

find_cmd:	cmp	ax,wptr [si]._cmd_letters
		je	short cmd_found
		add	si,CmdEntryLen
		cmp	bptr [si],0
		jne	find_cmd

cmd_not_fnd:	mov	si,offset badcommess
		call	pstring
		jmp	short gcloop

cmd_found:	call	[si]._cmd_address
		jmp	short gcloop

cmd_blank:	call	pcrlf
		jmp	short gcloop

menuexit:	call	pcrlf
		add	sp,2
		pop	di
		pop	si
		ret

getcommand	ENDP




;==========================================================================
;		Display Menu Help (address already in DI)
;==========================================================================
;
showhelp	PROC	near
		push	si
		mov	si,di
		call	pstring
		pop	si
		ret
showhelp	ENDP



;==========================================================================
;		   Enable/Disable Automatic Menu Display
;==========================================================================
;
menuson		PROC	near
		mov	MenusOnFlag,1
		mov	si,offset MenusOn_mess
		call	pstring
		ret
menuson		ENDP
;
menusoff	PROC	near
		mov	MenusOnFlag,0
		mov	si,offset MenusOff_mess
		call	pstring
		ret
menusoff	ENDP






;==========================================================================
;		   Monitor Configuration Menu Handler
;==========================================================================
;
ConfigMon	PROC	near
		mov	di,offset ConfigHelp
		mov	si,offset ConfigMenu
		call	NewMenu
		call	getcommand
		ret
ConfigMon	ENDP





;==========================================================================
; Called On Entry To A New Submenu - Shows Menu Help If Menus Havent Been
; Disabled In The Configuration Screen. 'HE' Command Always Gives Help.
;==========================================================================
;
NewMenu		PROC	near
		call	pcrlf
		cmp	MenusOnFlag,0			;are menus off?
		je	short nm_exit				;yes - dont show it
		call	showhelp			;else put it up
nm_exit:	ret
NewMenu		ENDP





;==========================================================================
;		  Just To Test Colour Escape Sequence Handling
;==========================================================================
;
ColourTest	PROC	near
		mov	si,offset coltest_mess
		call	pstring
		ret
ColourTest	ENDP




;==========================================================================
;		Undefined Opcode Test
;==========================================================================
;
udop		PROC	near
		TrapsOn

		nop
		nop
		call	DSload
		nop
		nop

		TrapsOff
		nop

		db	64h			;complete bollox opcode!
		ret
udop		ENDP





;==========================================================================
; Divide By Zero Trap Test. Only Tests 2 Byte Opcode Here Though Handler
; Will Cope With 3 & 4 Byte Opcodes Too.
;==========================================================================
;
DivZTest	PROC	near
		mov	dl,0
		mov	ax,7
		div	dl	;<=== triggers INT 0
		ret
DivZTest	ENDP






;==========================================================================
;		   Segment Not Present Trap Test
;==========================================================================
;
SNPtest		PROC	near
		mov	ax,dNP
		mov	ds,ax
		ret
SNPtest		ENDP






;==========================================================================
; Print 80286 processor registers and descriptor tables in protected mode
;	CS, DS, ES, SS and MSW
;	GDT, IDT, LDT, IOPL 
;==========================================================================
;
pRegisters	PROC	near
		call	pcrlf
		mov	si,offset SegRegName

		mov	SegRegName,'C'
		mov	bx,cs
		call	pr_SegReg

		mov	SegRegName,'D'
		mov	bx,ds
		call	pr_SegReg

		mov	SegRegName,'E'
		mov	bx,es
		call	pr_SegReg

		mov	SegRegName,'S'
		mov	bx,ss
		call	pr_SegReg

		mov	si,offset MSWmess
		call	pstring
		smsw	bx
		call	phexword
		call	pcrlf

		call	pProtRegs
		ret


; ----- Little Local Routine To Save Space

pr_SegReg:	call	pstring				;print reg name
		call	phexword
		call	pspace
		ret

pRegisters	ENDP









;==========================================================================
;	   Print Protected Mode Only Regs & Descriptor Table
;==========================================================================
;
pProtRegs	PROC	near
		sgdt	qword ptr SaveGDT		;save processor regs
		sidt	qword ptr SaveIDT

		mov	si,offset GDTregname
		call	pstring
		mov	di,offset SaveGDT
		call	pDTreg
		call	pcrlf

		mov	si,offset IDTregname
		call	pstring
		mov	di,offset SaveIDT
		call	pDTreg
		call	pcrlf

		mov	si,offset LDTregname
		call	pstring
		sldt	bx
		call	phexword
		call	pcrlf

		mov	si,offset TRregname
		call	pstring
		str	bx
		call	phexword
		call	pcrlf

		mov	si,offset IOPLmess
		call	pstring
		pushf
		pop	ax
		and	ah,00110000b
		shr	ah,4
		mov	bl,ah
		call	phexchar

; ----- now ask if descriptor tables are to be printed

		mov	si,offset pDescTabQmess
		call	pstring

pDesc_q:	call	gkey
		call	Ucase

		cmp	al,'G'
		je	short pPR_GDT
		cmp	al,'I'
		je	short pPR_IDT
		cmp	al,'Q'
		jne	pDesc_q
		jmp	short pPR_exit

pPR_IDT:	mov	bl,al
		call	pchar
		mov	di,offset IDTbase
		mov	cx,IDTlen
		shr	cx,3			;= # entries
		call	pIDT
		jmp	short pPR_exit

pPR_GDT:	mov	bl,al
		call	pchar
		call	pGDT
pPR_exit:
		call	pcrlf
		ret

pProtRegs	ENDP




pIDT:	ret	;tstst






;==========================================================================
;		 Display Global Descriptor Table Details
;==========================================================================
;
pGDT		PROC	near
		mov	si,offset pDTtitlemess		;print GDT title line
		call	pstring

		xor	bx,bx				;init selector to 0000
		mov	cx,GDTlen
		shr	cx,3				;= # entries

pGDT_1:		call	GetdBase			;copy to aDesc
		mov	aDesc.sdesc_baselo, ax
		mov	aDesc.sdesc_basehi, dl
		call	GetdLimit
		mov	aDesc.sdesc_limit, ax
		call	GetdARB
		mov	aDesc.sdesc_arb, al

		call	pSegDesc			;print this descriptor
		add	bx,SEGdescLen
		loop	pGDT_1

		ret
pGDT		ENDP






;==========================================================================
;		    Print Descriptor Details From 'aDesc'
;==========================================================================
;
pSegDesc	PROC	near

		push	cx				;preserve CX
		push	bx

		call	phexword			;print selector in BX
		call	pspace2				;& 2 spaces

		mov	al,aDesc.sdesc_arb		;get ARB
		mov	dl,al				;keep copy in DL
		and	al,01100000b			;keep DPL field
		shr	al,5
		mov	bl,al
		call	phexchar			;& print DPL
		call	pspace2

		test	dl,00010000b			;check system bit
		jnz	SHORT not_sys				;jmp if code or data

; ----- Is A System Segment, Say What Type

		mov	al,dl				;get ARB back in AL
		and	al,0fh				;just keep type
		add	al,al				;x2 for word table
		cbw					;as word in AX
		mov	si,offset SysSegTable
		add	si,ax
		mov	si,[si]
		call	pstring

; ----- Dont Print Bit Table If Invalid Or Reserved

		mov	al,dl				;get ARB back
		and	al,0fh				;just keey type
		test	al,00000111b
		jz	SHORT IsInvalid
		cmp	al,00001010b
		je	SHORT IsReserved
		cmp	al,00001101b
		je	SHORT IsReserved

		mov	ah,dl				;copy into AH
		call	pSysArb				;in AH

; ----- Now Split Out Gates From TSSs & LDTs

		call	IsGate				;is this a gate ?
		jc	SHORT notgate				;no, TSS or LDT then
		test	dl,3				;zero if call gates
		jnz	SHORT notcall

; Print word count for call gates

		mov	cx,13
psd_s13:	call	pspace
		loop	psd_s13
		mov	bl,aDesc.gdesc_word_count
		and	bl,1fh
		call	phexbyte
		call	pspace2
		jmp	short pgatedest

notcall:	mov	cx,13
notcall2:	call	pspace
		loop	notcall2
		call	pspace2
		call	pspace3

pgatedest:	mov	bx,aDesc.gdesc_selector
		call	phexword
		mov	bl,':'
		call	pchar
		mov	bx,[si].gdesc_offset
		call	phexword
		jmp	short pSDexit


notgate:	call	pspace2
		call	pBaseLimit			;must be TSS or LDT

IsInvalid:
IsReserved:	jmp	short pSDexit



; ----- Must Be Code Or Data Descriptor

not_sys:	test	dl,00001000b			;check E bit (1=code)
		jnz	SHORT pCODEdesc
		jmp	short pDATAdesc





; ----- print CODE descriptor (arb in DL)

pCODEdesc:	mov	si,offset CODEmess
		call	pstring

		mov	al,10000000b			;present bit
		call	pbit
		mov	al,00000100b			;conforming bit
		call	pbit
		mov	al,00000010b			;readable bit
		call	pbit
		call	pdash				;writeable N/A
		mov	al,00000001b			;accessed bit
		call	pbit
		call	pdash

		call	pspace2
		call	pBaseLimit

		jmp	short pSDexit


; ----- print DATA descriptor (arb in DL)

pDATAdesc:	mov	si,offset DATAmess
		call	pstring

		mov	al,10000000b			;present bit
		call	pbit
		call	pdash				;conforming N/A
		call	pdash				;readable N/A
		mov	al,00000010b			;writeable nit
		call	pbit
		mov	al,00000001b			;accessed bit
		call	pbit
		mov	al,00000100b			;expansion bit
		call	pbit

		call	pspace2
		call	pBaseLimit


pSDexit:	call	pcrlf
		pop	bx
		pop	cx
		ret

pSegDesc	ENDP







;==========================================================================
;		  Print System Descriptor ARB Bits In DL
;==========================================================================
;
pSysArb:	mov	al,10000000b			;present
		call	pbit
		call	pdash				;conforming
		call	pdash				;readable
		call	pdash				;writeable
		call	pdash				;accessed
		call	pdash				;expansion
		ret




;==========================================================================
;	   Print A Bit, Test Mask In AL, Test Byte(ARB) In DL
;==========================================================================
;
pbit		PROC	near
		mov	bl,'1'
		test	dl,al
		jnz	SHORT pbit1
		mov	bl,'0'
pbit1:		call	pchar
		call	pspace
		ret
pbit		ENDP






;==========================================================================
;			Print A Dash & A Space
;==========================================================================
;
pdash		PROC	near
		mov	bl,'-'
		call	pchar
		call	pspace
		ret
pdash		ENDP






;==========================================================================
; Passed ARB In DL, Returns C=0 If A Gate
; (gate types are: 4,5,6,7,C,E,F)
;==========================================================================
;
IsGate		PROC	near
		push	dx
		and	dl,0fh			;just keep type bits
		test	dl,00000100b		;must be set for above values
		jz	SHORT IsGate_NOK		;not set - exit
		test	dl,00001000b		;if clear - must be 4,5,6,7
		jz	SHORT IsGate_OK		;definately a gate
		cmp	dl,0dh			;check the odd one
		jz	SHORT IsGate_NOK

IsGate_OK:	pop	dx
		clc
		ret

IsGate_NOK:	pop	dx
		stc
		ret
IsGate		ENDP





;==========================================================================
; Print Global Or Local Desc Table Reg Base, Limit & Reserved Word
; DI Points To RAM Copy Of Register
;==========================================================================
;
pDTreg		PROC	near
		call	pstring				;display reg name

		mov	si,offset Limitmess		
		call	pstring
		mov	bx,[di]
		call	phexword

		mov	si,offset Basemess
		call	pstring
		mov	bl,[di+4]
		call	phexbyte			;print base high byte
		mov	bx,[di+2]
		call	phexword			;and base low word

		mov	si,offset Reservedmess		;reserved word contents
		call	pstring
		mov	bl,[di+5]
		call	phexbyte
		ret
pDTreg		ENDP




pBaseLimit	PROC	near
		mov	bl,aDesc.sdesc_basehi		;print base address
		call	phexbyte
		mov	bx,aDesc.sdesc_baselo
		call	phexword
		call	pspace

		mov	bx,aDesc.sdesc_limit		;print limit
		call	phexword
		call	pspace3
		ret
pBaseLimit	ENDP






;==========================================================================
;		Load runtime MonData segment/selector
;==========================================================================
;
DSload		PROC	near
		push	ax
		mov	ax,dDS
		mov	ds,ax
		pop	ax
		ret
DSload		ENDP






;==========================================================================
;			Hard Reset Machine
;
; In protected mode you give the processor a hard reset by sending the
; shutdown command to the keyboard controller.
;==========================================================================
;
Reboot		PROC	near
		cli				;interrupts off
		mov	al,0feh			;8042 shutdown command byte
		out	64h,al

halt_loop:	hlt				;bus activity interferes with
		jmp	short halt_loop		; the shutdown, so stop it!

Reboot		ENDP







;==========================================================================
;			Dump Memory Command Routine
;==========================================================================
;
dumpmem		PROC	near
		call	pspace
		call	gethexword			;get start segment
		mov	dumpseg,bx
		call	pspace
		call	gethexword			;and start offset
		mov	dumpoff,bx
		call	pspace
		call	gethexword			;and block length
		shr	bx,4				;/16 = # lines
		mov	cx,bx
		call	load_ESdumpseg			;load seg into ES
		call	pcrlf
		call	pcrlf
		mov	di,dumpoff			;load start offset
		call	_dump_block
		call	pcrlf
		ret
dumpmem		ENDP







;=======================================================================
; Dump a hunk of memory to the screen.
; Call with ES:DI --> block, CX=# 16 byte lines to dump
;=======================================================================
;
_dump_block	PROC	near
		push	cx				;save line counter
		mov	cx,16				;load byte counter
		call	paddr				;print ES:DI
		call	pspace2
dmp2:		mov	bl,es:[di]			;get byte
		inc	di
		call	phexbyte			;and print it in hex
		cmp	cx,9				;half way yet ?
		jne	SHORT dmp2_2				;jmp if not
		mov	bl,'-'				;else print dash
		call	pchar
		loop	dmp2
dmp2_2:		call	pspace
		loop	dmp2

		call	pspace3

		sub	di,16				;back to byte 1 in line
		mov	cx,16				;print 16 ASCII chars
dmp3:		mov	bl,es:[di]
		inc	di
		cmp	bl,20h
		jae	SHORT dmp4
		mov	bl,'.'
dmp4:		cmp	bl,127
		jbe	SHORT dmp5
		mov	bl,'.'
dmp5:		call	pchar
		loop	dmp3

		call	pcrlf
		pop	cx				;restore line counter
		call	keystat				;has a key been hit ?
		jz	SHORT dmp_newline			;no - carry on
		call	gkey				;else read it away
		ret					;and finish

dmp_newline:	loop	_dump_block
		ret
_dump_block	ENDP

	




;=======================================================================
;		   Print 24 Bit Address In ES:DI
;=======================================================================
;
paddr		PROC	near
		push	bx

		push	ax
		push	dx
		mov	bx,es				;get selector in BX
		call	GetdBase			;into DL:AX
		add	ax,di				;add on offset
		adc	dl,0

		mov	bl,dl
		call	phexbyte			;print high byte
		mov	bx,ax
		call	phexword			;and low byte

		pop	dx
		pop	ax
		pop	bx
		ret

paddr		ENDP






;===========================================================================
; Speaker beep, goes straight for 8254 timer/counter chip.
; Control word selects counter 2, LSB/MSB, square wave, binary count.
;===========================================================================
;
beep		PROC	near
	        push    ax				;save regs we use
		push	cx
	        mov     al,10110110b			;load control word
	        out     43h,al				;send it
	        mov     ax,400h				;load count
	        out     42h,al				;send LSB
	        mov     al,ah				;move MSB to AL
	        out     42h,al				;save it
	        in      al,61h				;get port 61 state
	        or      al,00000011b			;turn on speaker
	        out     61h,al				;speaker on now

		mov	cx,2000h			;loop for a bit
		loop	$
		and	al,11111100b			;clear speaker enable
		out	61h,al				;speaker off now
		pop	cx				;restore regs
	        pop     ax
	        ret					;return
beep		ENDP






;===========================================================================
; Step through memory from a given address and allow changes to be entered
; as either hex bytes or ascii chars.
;===========================================================================
;
modifymem	PROC	near
		call	pspace
		call	gethexword			;start segment in BX
		mov	dumpseg,bx			;sace it
		call	pspace
		call	gethexword			;start offset
		mov	di,bx				;load into DI
		call	pcrlf

		call	load_ESdumpseg			;point ES to segment

mmpad:		call	pcrlf
		call	paddr				;print current address
		call	pspace
		mov	bl,es:[di]			;read the byte there
		call	phexbyte			;and print it
		call	pspace

mm_0:		call	gkey				;get a key press
		cmp	al,'-'				;step back 1 byte ?
		jne	SHORT mm_1				;not this time, jump
		dec	di				;else dec address
		jmp	short mmpad			;and repeat

mm_1:		cmp	al,' '				;step forward 1 byte?
		jne	SHORT mm_2				;no, jump
		inc	di				;else bump address
		jmp	short mmpad			;and loop

mm_2:		cmp	al,cr				;return = all done ?
		jne	SHORT mm_3				;no, jump
		call	pcrlf
		ret					;else return to caller

mm_3:		cmp	al,'.'				;change to hex value ?
		jne	SHORT mm_4				;no, jump
		mov	si,offset bytevalmess		;else prompt new val
		call	pstring
		call	gethexbyte			;get new value
		mov	al,bl				;put into AL
		stosb					;store it & bump DI
		jmp	short mmpad			;loop

mm_4:		cmp	al,"'"				;ammend as ASCII char ?
		jne	SHORT mm_0				;no, get another key
		mov	si,offset asciivalmess		;else prompt for char
		call	pstring
		call	gkeye				;get ascii
		stosb					;store it & bump DI
		jmp	short mmpad			;loop

modifymem	ENDP





;===========================================================================
; Load the segment value from dumpseg into ES. For protected mode fill in
; the dDump descriptor in the GDT and load its selector into ES.
;===========================================================================
;
load_ESdumpseg	PROC	near
		push	ax			;save regs we use
		push	bx
		push	dx
		mov	ax,dumpseg		;get segment address
		call	Address24		;24 bit base in DL:AX
		mov	bx,dDump		;BX=dump selector
		call	SetdBase		;set descriptor base
		mov	es,bx
		pop	dx			;restore regs
		pop	bx
		pop	ax
		ret	 			;and return
load_ESdumpseg	ENDP





;===========================================================================
;		Fill an address range up with a bytes value
;===========================================================================
;
fillmem		PROC	near
		call	pspace
		call	gethexword			;get start segment
		mov	dumpseg,bx			;save it
		call	pspace
		call	gethexword			;get start offset
		mov	dumpoff,bx			;save that too
		call	pspace
		call	gethexword			;get end offset
		cmp	bx,dumpoff			;lower than start ?
		jb	SHORT fmend				;yes, nothing to do
		mov	fillend,bx			;else save it
		call	pspace
		call	gethexbyte			;get fil byte
		mov	fillchar,bl

		call	load_ESdumpseg			;load segment in ES
		mov	di,dumpoff			;and offset in DI

		mov	al,fillchar			;load the fill char
		mov	cx,fillend			;and end offset
		sub	cx,dumpoff			;-start = byte count
		jz	$+3				;if equal jmp to STOSB
		rep	stosb				;else fill the RAM
fmend:		call	pcrlf
		ret
fillmem		ENDP






; ===========================================================================
; Just a little routine to dump the 1st 256 bytes of extended memory above
; the 1M boundary to the screen, so you can see if the A20 address line is
; gated on. If you have/had VDISK.SYS loaded for a ramdisk in extended
; memory when you ran the monitor this will show the boot sector of that
; ramdisk. If not, see if these bytes are different from thoses at 000000
; physical - they should be if A20 is enabled.
; ===========================================================================
;
dumpVdisk	PROC	near
		call	pcrlf
		call	pcrlf
		mov	ax,dVdisk
		mov	es,ax

		xor	di,di
		mov	cx,16			;dump 16 lines, 256 bytes
		call	_dump_block
		ret
dumpVdisk	ENDP



		

;=======================================================================
;			Read A Byte From An I/O Port
;=======================================================================
;
inport		PROC	near
		call	pspace
		call	gethexword		;get port number
		mov	dx,bx			;move to DX for the read
		in	al,dx			;get a byte from the port
		call	pspace
		mov	bl,al			;move value read to BL
		call	phexbyte		;and print it
		call	pcrlf
		ret
inport		ENDP



;=======================================================================
;			Output A Byte To An I/O Port
;=======================================================================
;
outport		PROC	near
		call	pspace
		call	gethexword		;get port #
		mov	dx,bx			;keep in DX
		call	pspace			;nice tidy space
		call	gethexbyte		;get byte to send in BL
		mov	al,bl			;move to AL
		out	dx,al			;send it
		call	pcrlf
		ret
outport		ENDP









;========================================================================
;	Convert paragraph address in AX to 20 bit address in DX:AX
;========================================================================
;
Address24	PROC	near
		mov	dx,ax			;copy segment to DX
		shl	ax,4			;*16 = bytes, loose top nibble
		shr	dx,12			;shift top nibble to DL(lo)
		ret
Address24	ENDP




; =======================================================================
; Create a TSS and load it into the task register. If there is a memory
; allocation error the Task Register (TR) is loaded with zero, the dummy
; 1st entry in the GDT, so any reference to it causes an error.
; =======================================================================
;
InitMonTSS	PROC	near
		mov	dx,(TSSlen+15)/16		;TSS length in parags
		call	AllocMem			;ask nicely for it
		mov	bx,0				;leaves cary flag alone
		jc	SHORT IMT_exit			;jump if alloc error

		mov	bx,ax				;TSS selector in BX
		call	SetdSystem			;change to system seg
		mov	al,dtype_free286TSS		;set type to free TSS
		call	SetdType
		mov	al,0				;set DPL to 0
		call	SetdDPL
		mov	ax,TSSlen-1			;set true TSS limit
		call	SetdLimit

IMT_exit:	ltr	bx				;load Task Register
		ret
InitMonTSS	ENDP





;
;------------------------------------------------------------------------
;--------------------------- END OF MONITOR CODE ------------------------
;------------------------------------------------------------------------
;
				EVEN						;force an even address
				PUBLIC	MonCodeEnd
MonCodeEnd 		LABEL	byte				;end of local code offset

MonCode			ENDS
;
;------------------------------------------------------------------------
;--------------------------- END OF MONITOR CODE ------------------------
;------------------------------------------------------------------------
;




MonGDT			SEGMENT para public 'DATA' USE16
MonGDT			ENDS


DummySeg		SEGMENT para public USE16	;last physical seg to be linked
DummySeg		ENDS


;	>>>>> This must be the only module with a start address <<<<<

		END	MonInit

