.286P

;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;;
;;              PAGE            ,132
;;              TITLE           Real/Protected Mode Monitor
;;              SUBTTL          Floating Point Maths
;;              Author          Tony Hanratty
;;              Created         19/03/93
;;              Changed         23/12/00
;;
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-



                include moncomn.inc             ;load common equates



; ----- Temporary Code Declarations

		public	copy_fac
		public	fac1_to_4, fac4_to_1
		public	swap_1and4, swap_1and2,

		public	fac2_load10, fac2_load16

		public	shl_man, shr_man, sub_mans
		public	add_mans, add_man_abs, norm_fac1

; ----- External Code Declarations

                extrn   pcrlf:near, pstring:near
		extrn	pchar:near, phexchar:near
		extrn	phexword:near, phexbyte:near, pspace:near
		extrn	gethexchar:near, gkeye:near
		extrn	IsAsciiDigit:near

		extrn	getcommand:near, NewMenu:near
		extrn	showhelp:near, menuexit:near


; ----- External Data Declarations


; ----- Local Code Publics

		public	fpinput, fpoutput
		public	fpadd, fpsub, fpmult, fpdiv
		public	fpsqrt, fpsine
		public	fpinit
		public	MathMon

; ----- Local Data Publics

		public	_fperror
		public	fac1,fac2,fac3





; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;
; 				LOCAL CONSTANTS
;
; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-

digits_out	equ	10
sqrt_loop_count	equ	5


SQRT_MINUS	equ	1		;return error codes
OVERFLOW	equ	2
UNDERFLOW	equ	3
DIV_BY_ZERO	equ	4





; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;
; 			LOCAL MACROS AND STRUCTURES
;
; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-

PushRegs	MACRO
		push	ax
		push	bx
		push	cx
		push	dx
		push	si
		push	di
		ENDM


PopRegs		MACRO
		pop	di
		pop	si
		pop	dx
		pop	cx
		pop	bx
		pop	ax
		ENDM






; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;
; 			START OF MONITOR DATA SEGMENT
;
; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-

MonData		SEGMENT para public 'DATA'


; ======================== Read-Only Data ==========================

_showfacs_cmd		equ	'F','S'
_zerofac_cmd		equ	'Z','F'
_loadfac_cmd		equ	'L','F'
_copyfac_cmd		equ	'C','F'
_addfac_cmd		equ	'A','F'
_subfac_cmd		equ	'S','F'
_mulfac_cmd		equ	'M','F'
_divfac_cmd		equ	'D','F'
_sqrt_cmd		equ	'S','R'
_sin_cmd		equ	'S','I'


MathMenu	LABEL		byte
		CmdTabEntry		<_showfacs_cmd, ShowFacs>
		CmdTabEntry		<_zerofac_cmd, ZeroFac>
		CmdTabEntry		<_loadfac_cmd, LoadFac>
		CmdTabEntry		<_copyfac_cmd, CopyFac>
		CmdTabEntry		<_addfac_cmd, AddFac>
		CmdTabEntry		<_subfac_cmd, SubFac>
		CmdTabEntry		<_mulfac_cmd, MulFac>
		CmdTabEntry		<_divfac_cmd, DivFac>
		CmdTabEntry		<_sqrt_cmd, SqrtFac>
		CmdTabEntry		<_sin_cmd, SinFac>
		CmdTabEntry		<_showhelp_cmd, showhelp>
		CmdTabEntry		<_menuexit_cmd, menuexit>
		db	0		;; End of menu


MathHelp	LABEL	byte
	db	lf,lf,cr,'MATHS MENU COMMANDS...'
	db	cr,lf,' '
	db	_showfacs_cmd,		' Show All FACs                 '
	db	_addfac_cmd,		' Add FAC2 to FAC1'
	db	cr,lf,' '
	db	_loadfac_cmd,		' Load FAC1                     '
	db	_subfac_cmd,		' Subtract FAC2 From FAC1'
	db	cr,lf,' '
	db	_zerofac_cmd,		' Zero A Fac                    '
	db	_mulfac_cmd,		' Multiply FAC2 onto FAC1'
	db	cr,lf,' '
	db	_copyfac_cmd,		' Copy a FAC                    '
	db	_divfac_cmd,		' Divide FAC1 by FAC2'
	db	cr,lf,' '
	db	_showhelp_cmd,		' This Help Menu                '
	db	_menuexit_cmd,		' Exit Menu'
	db	cr,lf,lf,null




;; Floating point constants 10, 2, 16, 1 for use by routines

fp_10		LABEL	byte
		db	0			;sign
		db	01010000b		;mantissa
		db	9 dup(0)		;= ditto = 
		dw	EXP_BIAS+4		;exponent

fp_2		LABEL	byte
		db	0
		db	01000000b
		db	9 dup(0)
		dw	EXP_BIAS+2

fp_16		LABEL	byte
		db	0
		db	01000000b
		db	9 dup(0)
		dw	EXP_BIAS+5

fp_1		LABEL	byte
		db	0
		db	01000000b
		db	9 dup(0)
		dw	EXP_BIAS+1




;; Powers of ten used in hex2dec routine

tenpowers	dw	10000
		dw	1000
		dw	100
ten		dw	10
		dw	1
tenpowend	LABEL	byte



;; Table of divisors for power series (still in ASCII. Should really be
;; changed to binary.)

c1		db	'+6.0E+0',0
c2		db	'+2.0E+1',0
c3		db	'+4.2E+1',0
c4		db	'+7.2E+1',0
c5		db	'+1.1E+2',0
c6		db	'+1.56E+2',0
c7		db	'+2.1E+2',0
c8		db	'+2.72E+2',0
c9		db	'+3.42E+2',0


SineDivisorTable	LABEL	word
		dw	c1,c2,c3,c4
		dw	c5,c5,c6,c8

fpinit_mess	db	cr,lf,'Floating point registers initialised'
		db	cr,lf,null


f1title_mess	db	'FAC1 = ',null
f2title_mess	db	'FAC2 = ',null
f3title_mess	db	'FAC3 = ',null
f4title_mess	db	'FAC4 = ',null

qfaczero_mess	db	cr,lf,'Select FAC to zero (1-4) ',null

srcfac_mess	db	cr,lf,'Enter source FAC (1-4) ',null
destfac_mess	db	cr,lf,'Destination FAC (1-4)  ',null
BadFac_mess	db	cr,lf,'Bad FAC number',cr,lf,null
inp_mess	db	cr,lf,'Input number: ',null

fac_table	dw	fac1, fac2, fac3, fac4


; ======================== Read/Write Data ==========================

	; Of the six floating point accumulators within the package
	; only the first two are visible by external routine.

fac1		Fac	<?>
fac2		Fac	<?>
fac3		Fac	<?>	;; Temp for divide, multiply, add and subtract
fac4		Fac	<?>	;; Temp for comparisons, square roots and output


snum		Fac	<?>	;; Number to square root
gues		Fac	<?>	;; Square root guess

dec_exp		dw	0
exp_sign        db      0
exp_val		dw	0
_fac1_sign	db	0

_fperror	db	0		;return floating point error

pushpopret	dw	0		;return address for Push/Pop FAC

src_fac		dw	0		;for menu driven copy command
dest_fac	dw	0

; Accumulators used in sine calculation

_a2		Fac	<?>		;square of angle
_sine		Fac	<?>		;partial sum
_sineterm	Fac	<?>		;last term in series

INP_BUF_LEN	equ	32
inp_buffer	db	INP_BUF_LEN dup (0)

MonData		ENDS





; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;
; 			START OF MONITOR CODE SEGMENT
;
; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-


MonCode		SEGMENT para public 'CODE'
		ASSUME	cs:MonCode, ds:MonData



;==========================================================================
;		   Monitor Configuration Menu Handler
;==========================================================================
;
MathMon		PROC	near
		mov	di,offset MathHelp
		mov	si,offset MathMenu
		call	NewMenu
		call	getcommand
		ret
MathMon		ENDP




;;==========================================================================
;; NAME:	ShowFacs
;;
;; INPUT:	None
;;
;; OUTPUT:	None
;;
;; DESC:	Output all FACs to screen. All FACs preserved.
;;
;; Destroys:	Nothing (much)
;;==========================================================================

ShowFacs	PROC	near
		call	PushAllFacs

		call	pcrlf
		mov	si,offset f1title_mess
		call	pstring
		call	fpoutput			;FAC1 out

		mov	si,offset f2title_mess
		call	pstring
		call	PopAllFacs
		call	PushAllFacs
		mov	si,offset fac2
		mov	di,offset fac1
		call	copy_fac
		call	fpoutput

		mov	si,offset f3title_mess
		call	pstring
		call	PopAllFacs
		call	PushAllFacs
		mov	si,offset fac3
		mov	di,offset fac1
		call	copy_fac
		call	fpoutput

		mov	si,offset f4title_mess
		call	pstring
		call	PopAllFacs
		call	PushAllFacs
		mov	si,offset fac4
		mov	di,offset fac1
		call	copy_fac
		call	fpoutput

		call	PopAllFacs
		call	pcrlf
		ret

ShowFacs	ENDP




;;==========================================================================
;; NAME:	ZeroFac
;;
;; INPUT:	None
;;
;; OUTPUT:	The user selected FAC is cleared to zero
;;
;; DESC:	User selects a FAC. It is cleared. All FACs then displayed.
;;
;; Destroys:	Nothing (much)
;;==========================================================================

ZeroFac		PROC	near
		mov	si,offset qfaczero_mess
		call	pstring
		call	gethexchar
		dec	bl
		cmp	bl,3
		ja	ZF_error
		mov	bh,0
		add	bx,bx
		mov	si,fac_table[bx]
		call	clear_fac
		call	ShowFacs
		ret

ZF_error:	mov	si,offset BadFac_mess
		call	pstring
		ret
ZeroFac		ENDP






;;==========================================================================
;; NAME:	CopyFac
;;
;; INPUT:	None
;;
;; OUTPUT:	None
;;
;; DESC:	User selects source & dest FACs, contents are copied.
;;
;; Destroys:	Nothing (much)
;;==========================================================================

CopyFac		PROC	near
		mov	si,offset srcfac_mess
		call	pstring
		call	gethexchar
		dec	bl
		cmp	bl,3
		ja	CF_error
		mov	bh,0
		mov	src_fac, bx

		mov	si,offset destfac_mess
		call	pstring
		call	gethexchar
		dec	bl
		cmp	bl,3
		ja	CF_error
		mov	bh,0
		mov	dest_fac, bx

		mov	bx,src_fac
		add	bx,bx
		mov	si,fac_table[bx]
		mov	bx,dest_fac
		add	bx,bx
		mov	di,fac_table[bx]

		push	ds
		pop	es
		call	copy_fac

		call	ShowFacs
		ret

CF_error:	mov	si,offset BadFac_mess
		call	pstring
		ret

CopyFac		ENDP







;;==========================================================================
;; NAME:	LoadFac
;;
;; INPUT:	None
;;
;; OUTPUT:	FAC<x> loaded
;;
;; DESC:	Loads an ASCII string value into a FAC
;;
;; Destroys:	Nothing
;;==========================================================================

LoadFac		PROC	near

		mov	si,offset inp_mess
		call	pstring
		call	getstring
		call	pcrlf

		mov	si,offset fac2
		call	PushFac
		mov	si,offset fac3
		call	PushFac

		mov	si,offset inp_buffer
		call	fpinput

		mov	si,offset fac3
		call	PopFac
		mov	si,offset fac2
		call	PopFac

		call	ShowFacs
		ret

LoadFac		ENDP






getstring	PROC	near
		push	ds
		pop	es
		mov	di,offset inp_buffer

gs_loop:	call	gkeye
		cmp	al,cr
		je	gs_done
		stosb
		jmp	short gs_loop

gs_done:	mov	byte ptr es:[di], 0
		ret

getstring	ENDP







;;==========================================================================
;; NAME:	AddFac
;;
;; INPUT:	FAC1, FAC2
;;
;; OUTPUT:	FAC1 = FAC1 + FAC2
;;
;; DESC:	Adds FAC2 onto FAC1
;;
;; Destroys:	Nothing
;;==========================================================================

AddFac		PROC	near
		mov	si,offset fac2
		call	PushFac
		mov	si,offset fac3
		call	PushFac
		call	fpadd
		mov	si,offset fac3
		call	PopFac
		mov	si,offset fac2
		call	PopFac
		call	ShowFacs
		ret
AddFac		ENDP








;;==========================================================================
;; NAME:	SubFac
;;
;; INPUT:	FAC1, FAC2
;;
;; OUTPUT:	FAC1 = FAC1 - FAC2
;;
;; DESC:	Subtracts FAC2 from FAC1
;;
;; Destroys:	Nothing
;;==========================================================================

SubFac		PROC	near
		mov	si,offset fac2
		call	PushFac
		mov	si,offset fac3
		call	PushFac
		call	fpsub
		mov	si,offset fac3
		call	PopFac
		mov	si,offset fac2
		call	PopFac
		call	ShowFacs
		ret
SubFac		ENDP







;;==========================================================================
;; NAME:	MulFac
;;
;; INPUT:	FAC1, FAC2
;;
;; OUTPUT:	FAC1 = FAC1 * FAC2
;;
;; DESC:	Multiplies FAC2 onto FAC1
;;
;; Destroys:	Nothing
;;==========================================================================

MulFac		PROC	near
		mov	si,offset fac3
		call	PushFac
		call	fpmult
		mov	si,offset fac3
		call	PopFac
		call	ShowFacs
		ret
MulFac		ENDP





;;==========================================================================
;; NAME:	DivFac
;;
;; INPUT:	FAC1, FAC2
;;
;; OUTPUT:	FAC1 = FAC1 / FAC2
;;
;; DESC:	Divides FAC1 by FAC2
;;
;; Destroys:	Nothing
;;==========================================================================

DivFac		PROC	near
		mov	si,offset fac3
		call	PushFac
		call	fpdiv
		mov	si,offset fac3
		call	PopFac
		call	ShowFacs
		ret
DivFac		ENDP





SqrtFac:		;; Still a bit of work to do here mate!
SinFac:
		call	pcrlf
		ret





;;==========================================================================
;; NAME:	fpinit
;;
;; INPUT:	None
;;
;; OUTPUT:	Nothing
;;
;; DESC:	Zeros and initialises all FACs
;;
;; Destroys:	N/A
;;==========================================================================

fpinit		PROC	near

		push	si
		push	di

		push	es
		pop	ds

		mov	si,offset fac1
		call	clear_fac
		mov	si,offset fac2
		call	clear_fac
		mov	si,offset fac3
		call	clear_fac
		mov	si,offset fac4
		call	clear_fac

		mov	si,offset fpinit_mess
		call	pstring

		pop	di
		pop	si
		ret

fpinit		ENDP





;;==========================================================================
;; NAME:	fpintput
;;
;; INPUT:	SI --> ASCII string to parse in
;;
;; OUTPUT:	FAC 1 = number in floating point
;;
;; DESC:	Parse an ASCIIZ string into FAC1. String format must
;;		be correct since there's practically no error checking.
;;
;; DESTROYS:	FAC2 & FAC3
;;==========================================================================

fpinput		PROC	near
		PushRegs

		call	clear_fac1		;SI preserved
		mov	dec_exp,0
		mov	exp_val,0
		mov	exp_sign,0

		lodsb
		cmp	al,'-'
		jne	gotsign
		mov	fac1.Fac_sign, 80h

gotsign:	lodsb				;get 1st digit
		call	IsAsciiDigit		;returns 0 - 9 in AL
		call	addigit			;add char in AL to fac1_man

		lodsb				;read and discard decimal point

get_decimal:	lodsb				;get next char
		call	IsAsciiDigit		;AL = 0 - 9
		jc	get_exp_sgn		;must be 'E' for exponent
		call	addigit
		dec	dec_exp
		jmp	SHORT get_decimal

get_exp_sgn:	lodsb				;get exponent sign
		cmp	al,'-'
		jne	exp_get_dgts
		mov	exp_sign,128

exp_get_dgts:	lodsb				;get next char
		call	IsAsciiDigit
		jc	exp_done		;Oops!
		cbw				;nov AX = 0-9
		mov	bx,ax			;save binary digit in bl
		mov	ax,exp_val
		mul	ten			;check for overflow here
		add	ax,bx
		mov	exp_val,ax
		jmp	short exp_get_dgts

exp_done:	mov	ax,exp_val
		cmp	exp_sign,0
		je	exp5
		neg	ax
exp5:		add	dec_exp,ax

		mov	fac1.Fac_exp, EXP_BIAS+79

; These 4 lines of wierd crap are to get round the jump to 'popret'
; at the end of norm_fac1. The 6 words on the stack are popped into
; ax bx cx dx si di and the 'ret' instruction will return to expo5_5
; And all this because you cant use a simple 'call' !

		push	offset exp_ret		;push return address
		sub	sp,12			;fake 6 words on stack
		jmp	norm_fac1		;normalise, return next line

exp_ret:	call	fac2_load10
		mov	bx,offset fpmult
		mov	cx,dec_exp

		or	cx,cx
		jz	expo20
		jns	expo10			;+ve decimal exponent

		neg	cx			; CX = abs(dec_exp)
		mov	bx,offset fpdiv

expo10:		call	bx
		loop	expo10

expo20:		jmp	popret

fpinput		ENDP





;;==========================================================================
;; NAME:	fpoutput
;;
;; INPUT:	None
;;
;; OUTPUT:	FAC 1 displayed in ASCII
;;
;; DESC:	Translates FAC1 and prints it as ASCII
;;		be correct.
;;
;; DESTROYS:	Destroys FAC1, FAC2, FAC3, FAC4 - and probably some
;;		others as well !!
;;==========================================================================

fpoutput	PROC	near
		PushRegs

		mov	dec_exp,0
		cmp	fac1.Fac_exp, 0
		jnz	save_sign
		jmp	fout7

; The following two comparisons need fac1 as a +ve number, so save its
; sign and restore it later.

save_sign:	mov	al,fac1.Fac_sign	;get sign
		mov	_fac1_sign,al		;save it
		mov	fac1.Fac_sign,0		;set FAC1 as +ve

fout1:		call	fac1_to_4		;keep copy of FAC1 in FAC4
		call	fac2_load16
		call	fpsub			;fac1 = fac1 - 16
		cmp	fac1.Fac_sign,0
		jne	fout2			;sign is -ve if fac1 <= 15

		call	fac4_to_1		;get fac1 back
		call	fac2_load10		;put 10 in fac2
		call	fpdiv			;fac1=fac1/10
		inc	dec_exp
		jmp	short fout1

fout2:		call	fac4_to_1		;get fac1 back

fout3:		call	fac1_to_4
		call	fac2_load1
		call	fpsub			;fac1 = fac1 - 1
		cmp	fac1.Fac_sign, 0
		je	fout4			;sign is 0 if fac1 not < 1
		call	fac2_load10		;put 10 in fac2
		call	fac4_to_1		;get fac1 back
		call	fpmult

		dec	dec_exp
		jmp	short fout3

fout4:		call	fac4_to_1
		call	fac2_load10
		call	fpsub
		mov	al,fac1.Fac_sign
		or	al,al			;check if sign is 0
		pushf				;save flags
		call	fac4_to_1		;reload number
		popf				;restore flags to check sign
		jnz	rest_sign		;sign is <>0 if fac1 < 10
		call	fac2_load10
		call	fpdiv
		inc	dec_exp

rest_sign:	mov	al,_fac1_sign
		mov	fac1.Fac_sign,al	;restore fac1's sign
		call	fac1_to_4		;copy into fac4

		cmp	fac1.Fac_exp, EXP_BIAS+4
		jne	fout6
		mov	si,offset fac1.Fac_man
		call	shl_man
		jmp	short fout7
fout6:
		cmp	fac1.Fac_exp, EXP_BIAS+3
		jae	fout_round
		mov	si,offset fac1.Fac_man
		call	shr_man
		inc	fac1.Fac_exp
		jmp	short fout6

fout_round:	mov	si,offset fac1.Fac_man
		mov	al,93h
		call	add_man_abs
		mov	al,93h
		call	add_man_abs_short

fout7:		mov	bl,'+'
		cmp	fac1.Fac_sign, 0
		jz	fout8
		mov	bl,'-'
fout8:		call	pchar

		mov	bl,fac1.Fac_man
		shr	bl,4
		call	phexchar			;0-9 is hex!
		mov	bl,'.'
		call	pchar

		mov	cx,digits_out			;# of digits to print
fout9:		push	cx
		and	fac1.Fac_man, 0fh		;clr top nibble
		call	fac1x10
		mov	bl,fac1.Fac_man
		shr	bl,4
		call	phexchar
		pop	cx
		loop	fout9

fout_pexp:	mov	bl,'E'
		call	pchar

		mov	bl,'+'
		cmp	dec_exp,0
		jge	fout10
		mov	bl,'-'
		neg	dec_exp
fout10:		call	pchar

		mov	ax,dec_exp
		call	hex2dec
		call	pcrlf
		jmp	popret
fpoutput	ENDP









;;==========================================================================
;; NAME:	fpadd
;;
;; INPUT:	FAC1 & FAC2
;;
;; OUTPUT:	FAC1  = FAC1 + FAC2
;;
;; DESC:	Adds two floating point numbers
;;		be correct.
;;
;; DESTROYS:	Destroys FAC2, FAC3
;;==========================================================================

fpadd		PROC	near
		PushRegs

		mov	ax,fac1.Fac_exp
		cmp	ax,fac2.Fac_exp
		jae	fpa1
		call	swap_1and2
fpa1:		mov	ax,fac1.Fac_exp
		sub	ax,fac2.Fac_exp
		cmp	ax,78
		jbe	fpa2
		jmp	popret			;fac2 too small to effect fac1

fpa2:		mov	cx,ax			;put shift count into CX
		jcxz	fpa4			;shift count = 0
		mov	si,offset fac2.Fac_man
fpa3:		call	shr_man			;shift FAC2 to align dec pts
		loop	fpa3

fpa4:		mov	al,fac1.Fac_sign	;get FAC1 sign
		cmp	al,fac2.Fac_sign	;compare to FAC2 sign
		je	fpa5			;skip if equal ( +/+ or -/- )
		mov	si,offset fac2.Fac_man	;otherwise negate FAC2 mantissa
		call	neg_man

fpa5:		mov	di,offset fac1.Fac_man
		mov	si,offset fac2.Fac_man
		call	add_mans

		mov	al,fac1.Fac_sign
		cmp	al,fac2.Fac_sign
		je	fpa_done		;exit if same sign
		test	fac1.Fac_man, 80h	;check bit 79 of mantissa
		jz	fpa_done		;no overflow on subtraction
		mov	si,offset fac1.Fac_man
		call	neg_man
		mov	al,fac2.Fac_sign
		mov	fac1.Fac_sign,al
fpa_done:
		jmp	norm_fac1

fpadd		ENDP





;;==========================================================================
;; NAME:	fpsub
;;
;; INPUT:	FAC1, FAC2
;;
;; OUTPUT:	FAC1  = FAC1 - FAC2 = FAC1 + (-FAC2)
;;
;; DESC:	Subtracts FAC 2 from FAC 1. This is implemented by
;;		negating FAC2 and adding it to FAC 1.
;;
;; DESTROYS:	Destroys FAC2, FAC3
;;==========================================================================

fpsub		PROC	near
		xor	fac2.Fac_sign, 80h	;invert fac2's sign and add
		jmp	fpadd
fpsub		ENDP









;;==========================================================================
;; NAME:	fpmult
;;
;; INPUT:	FAC1 & FAC2
;;
;; OUTPUT:	FAC1  = FAC1 * FAC2
;;
;; DESC:	Multiplies FAC1 by FAC1 and leaves the reult in FAC1.
;;
;; DESTROYS:	FAC3
;;==========================================================================

fpmult		PROC	near
		PushRegs
		mov	al,fac2.Fac_sign
		xor	fac1.Fac_sign, al

		mov	ax,fac2.Fac_exp
		add	ax,fac1.Fac_exp
		sub	fac1.Fac_exp,EXP_BIAS+1

		mov	si,offset fac3
		call	clear_man

		;; Now shift for each bit, ie 79 times

		mov	cx,79

mult1:		mov	si,offset fac3.Fac_man
		call	shr_man
		mov	si,offset fac1.Fac_man
		call	shr_man
		jnc	mult2
		mov	si,offset fac2.Fac_man
		mov	di,offset fac3.Fac_man
		call	add_mans			;fac3_man += fac2_man
mult2:		loop	mult1

		mov	si,offset fac3.Fac_man
		mov	di,offset fac1.Fac_man
		call	copy_man
		jmp	norm_fac1
fpmult		ENDP







;;==========================================================================
;; NAME:	fpdiv
;;
;; INPUT:	FAC1 & FAC2
;;
;; OUTPUT:	FAC1  = FAC1 / FAC2
;;
;; DESC:	Divide FAC1 by FAC2. Result in FAC1
;;
;; DESTROYS:	FAC2 and FAC3
;;==========================================================================

fpdiv		PROC	near
		test	fac2.Fac_exp, 0ffffh
		jz	_div_zero

		PushRegs
		mov	al,fac2.Fac_sign
		xor	fac1.Fac_sign,al

		mov	ax,fac2.Fac_exp
		sub	fac1.Fac_exp, ax
		add	fac1.Fac_exp,EXP_BIAS

		mov	si,offset fac3
		call	clear_man

		mov	di,offset fac1.Fac_man
		mov	si,offset fac2.Fac_man
		call	sub_mans			;fac1_man -= fac2_man

		mov	cx,80

fpd1:		mov	si,offset fac3.Fac_man
		call	shl_man
		mov	si,offset fac1.Fac_man
		call	shl_man
		jnc	fpd2

		mov	si,offset fac2.Fac_man
		mov	di,offset fac1.Fac_man
		call	add_mans
		jmp	short fpd3

fpd2:		mov	di,offset fac1.Fac_man
		mov	si,offset fac2.Fac_man
		call	sub_mans
		mov	si,offset fac3.Fac_man+9	;pt to low order byte
		or	byte ptr [si],1			;set bit of fac3_man

fpd3:		loop	fpd1

		mov	si,offset fac3.Fac_man
		mov	di,offset fac1.Fac_man
		call	copy_man
		jmp	norm_fac1

fpdiv		ENDP


_div_zero:	mov	_fperror,DIV_BY_ZERO
		ret








; 'Add' binary 0-9 in AL to fac1_man
; destroys FAC3

addigit		PROC	near
		push	si
		push	ax
		call	fac1x10
		pop	ax
		mov	si,offset fac1.Fac_man
		call	add_man_abs		;add number to mantissa
		pop	si
		ret
addigit		ENDP







; Multiply fac1_man by 10 using 10a = 2a+8a
; destroys FAC3

fac1x10		PROC	near
		push	si
		push	di

		mov	si,offset fac1.Fac_man
		call	shl_man				;x 2
		mov	si,offset fac1.Fac_man
		mov	di,offset fac3.Fac_man
		call	copy_man			;fac3_man = fac1_man
		mov	si,offset fac1.Fac_man
		call	shl_man
		call	shl_man				;it's now x 8
		mov	di,offset fac1.Fac_man
		mov	si,offset fac3.Fac_man
		call	add_mans			;fac1_man += fac3_man

		pop	di
		pop	si
		ret
fac1x10		ENDP







; Adds mantissa pointed @ SI onto mantissa @ DI, result left at DI

add_mans	PROC	near
		mov	bx,9			;10 bytes in mantissa
		xor	dx,dx

am1:		mov	al,[si+bx]		;get a byte
		add	[di+bx],al		;add 2nd byte
		adc	dl,0			;keep any carry in DL
		add	[di+bx],dh		;add on any previous carry
		adc	dl,0			;accumulate carry in DL
		mov	dh,dl			;put any carry into dh
		mov	dl,0			;and clear dl for next pass
		dec	bx			;dec counter/offset
		jns	am1			;if not -1, loop

		ret
add_mans	ENDP





; Subtract mantissa @ SI from mantissa @ DI, result left at DI

sub_mans	PROC	near
		mov	bx,9			;10 bytes in mantissa
		xor	dx,dx			;clear saved carrys
sm1:
		mov	al,[si+bx]		;get a byte
		sub	[di+bx],al		;subtract 2nd byte
		adc	dl,0			;save any carry in dl
		sub	[di+bx],dh		;subtract any previous borrow
		adc	dl,0			;save any borrow in dl
		mov	dh,dl			;put any borrow into dh
		mov	dl,0			;and clear dl for next pass
		dec	bx			;dec counter/offset
		jns	sm1			;if not -1, loop

		ret
sub_mans	ENDP






;; Adds binary number in AL to mantissa pointed to by SI

add_man_abs_short:
		push	bx
		mov	bx,8			;2nd least sig mantissa byte
		jmp	short	ama1		;only rounding enters here


add_man_abs	PROC	near
		push	bx
		mov	bx,9
ama1:		add	[si+bx],al
		jnc	ama_done
ama_carry:	or	bx,bx			;BX=0 on top byte ?
		jz	ama_done		;yes, ignore it
		dec	bx
		inc	byte ptr [si+bx]
		jz	ama_carry		;repeat if wrapped round to zero
ama_done:	pop	bx
		ret
add_man_abs	ENDP






;; Normalise FAC 1. Destroys all regs but no FAC's
;
norm_fac1	PROC	near
		mov	ax,word ptr fac1.Fac_man[0]
		or	ax,word ptr fac1.Fac_man[2]
		or	ax,word ptr fac1.Fac_man[4]
		or	ax,word ptr fac1.Fac_man[6]
		or	ax,word ptr fac1.Fac_man[8]
		jz	norm_zero		;jump if mantissa is zero

		mov	si,offset fac1.Fac_man
		test	byte ptr [si],80h	;test bit 79 of mantissa
		jz	norm4			;skip if not set
		call	shr_man			;shift mantissa right
		inc	fac1.Fac_exp

norm4:		test	byte ptr [si],40h	;check bit 78
		jnz	norm6			;jump if set
		call	shl_man			;shift mantissa left
		dec	fac1.Fac_exp
		jmp	short norm4

norm6:		mov	ax,fac1.Fac_exp
		test	ax,ax
		js	norm_oflow
		jz	norm_uflow
		jmp	short popret
norm_fac1	ENDP


norm_zero:	mov	fac1.Fac_sign,0		;zero all the bits
		mov	fac1.Fac_exp,0
		jmp	short popret

norm_oflow:	mov	_fperror,OVERFLOW
		jmp	short popret

norm_uflow:	mov	_fperror,UNDERFLOW

popret:		PopRegs
		ret










;; Negates mantissa pointed to by SI
;; No registers preserved.
;
neg_man		PROC	near
		not	word ptr [si]
		not	word ptr [si+2]
		not	word ptr [si+4]
		not	word ptr [si+6]
		not	word ptr [si+8]

		mov	al,1
		call	add_man_abs			;add 1 to mantissa

		ret
neg_man		ENDP












;; Convert hex word in AX to decimal and print. Destroys every
;; bloody register in sight !

hex2dec		PROC	near
		mov	bx,offset tenpowers
		or	ax,ax
		jnz	ha1
		push	ax
		mov	bx,offset tenpowend-2
		jmp	short ha4

ha1:		xor     dx,dx			;zero for division
        	div     word ptr [bx]
		or	al,al			;check quotient
		jnz	ha2			;jump if char to output
		mov	ax,dx			;remainder = new dividend
		add	bx,2			;point to next divisor
		jmp	short ha1		;and repeat
ha2:
		push	dx			;save remainder
		push	bx
	        mov	bl,al
		call	phexchar		;0-9 is hex
		pop	bx
		pop	ax			;get remainder back

ha3:		add	bx,2
		cmp	bx,offset tenpowend
		je	ha5
		xor     dx,dx			;zero for division
        	div     word ptr [bx]
		push	dx			;save remainder

ha4:		push	bx
		mov	bl,al
		call	phexchar
		pop	bx
		pop	ax
		jmp	short ha3
ha5:
		ret
hex2dec		ENDP





;; Passed number in FAC1 - square root returned in FAC1
;
fpsqrt		PROC	near
		push	ax
		mov	ax,fac1.Fac_exp
		or	ax,ax
		pop	ax
		jnz	not_zero
		ret				;return since SQR(0) = 0

not_zero:	jns	get_guess
		mov	_fperror,SQRT_MINUS	;cant root a -ve number
		ret

get_guess:	PushRegs
		mov	si,offset fac1
		mov	di,offset snum
		call	copy_fac
		mov	di,offset gues
		call	copy_fac

		mov	si,offset gues
		call	clear_man
		mov	byte ptr [si],40h	;put 1 into mantissa
		mov	ax,gues.Fac_exp
		sub	ax,EXP_BIAS
		shr	ax,1
		or	ax,ax
		jnz	get_guess2
		inc	ax			;dont want exponent of zero
get_guess2:
		add	ax,EXP_BIAS
		mov	gues.Fac_exp,ax		;exp/2 to give 1st guess


; to compute (g^2 + N)/2g    ....as per Newtons method of approximation

; 1...put g in FAC1 and FAC2, multiply to give g*g
; 2...put N in FAC2 and add to give g*g + N in FAC1
; 3...put 1st 2 then g in FAC2 and divide to give next guess at root


		mov	cx,sqrt_loop_count

sqrt_loop:	mov	si,offset gues
		mov	di,offset fac1
		call	copy_fac
		mov	di,offset fac2
		call	copy_fac
		call	fpmult			;now have g*g in FAC1

		mov	si,offset snum
		mov	di,offset fac2
		call	copy_fac
		call	fpadd			;now have g*g + N in FAC1

		mov	si,offset fp_2
		mov	di,offset fac2
		call	copy_fac
		call	fpdiv			;now have (g*g + N)/2

		mov	si,offset gues
		mov	di,offset fac2
		call	copy_fac
		call	fpdiv			;no (g*g + N)/2g = new guess

		mov	si,offset fac1		;save it in gues
		mov	di,offset gues
		call	copy_fac

		loop	sqrt_loop		;loop required # of times

		mov	si,offset gues
		mov	di,offset fac1		;copy answer into FAC1
		call	copy_fac
		jmp	popret

fpsqrt		ENDP





; Compute sine of angle in FAC1 - angle expressed in radians

		PUBLIC	fpsine
fpsine		PROC	near
		PushRegs
		mov	si,offset fac1
		mov	di,offset _sine
		call	copy_fac		;1st term in sine
		mov	di,offset _sineterm
		call	copy_fac		;and also last term

		mov	di,offset fac2
		call	copy_fac
		call	fpmult			;now have a*a

		mov	si,offset fac1
		mov	di,offset _a2
		call	copy_fac

		mov	cx,0			;0 to access SineDivisorTable

sl1:		push	cx
		mov	si,offset _sineterm
		mov	di,offset fac1
		call	copy_fac		;term in fac1
		xor	fac1.Fac_sign,80h	;flip sign of fac1

		mov	si,offset _a2
		mov	di,offset fac2
		call	copy_fac		;get a*a into fac2 and multiply
		call	fpmult			;to give -t*a*a
		mov	si,offset fac1
		mov	di,offset _sineterm
		call	copy_fac		;save it

		mov	si,offset SineDivisorTable
		add	si,cx
		add	si,cx
		mov	si,[si]			;get address of next divisor
		call	fpinput			;read number into fac1

		mov	si,offset fac1
		mov	di,offset fac2
		call	copy_fac		;put divisor into fac2
		mov	si,offset _sineterm
		mov	di,offset fac1
		call	copy_fac		;get term back into fac1
		call	fpdiv			;now have next full term in fac1

		mov	si,offset fac1
		mov	di,offset _sineterm
		call	copy_fac		;save it for next pass

		mov	si,offset _sine
		mov	di,offset fac2
		call	copy_fac		;get sine sum back
		call	fpadd			;add new term, new sine in fac1
		mov	si,offset fac1
		mov	di,offset _sine
		call	copy_fac		;save new sine

		pop	cx
		inc	cx
		cmp	cx,8
		jne	sl1

		jmp	popret
fpsine		ENDP






; Returns signed integer of fac1 in AX - bit 7 = sign

		PUBLIC	fpint
fpint		PROC	near

		push	bx
		push	cx
		xor	ax,ax
		mov	bh,0
		mov	cx,word ptr [fac1+11]		;get fac1 exponent
		sub	cx,EXP_BIAS
		jbe	int_zero
		mov	bh,byte ptr [fac1]	;get sign
		mov	si,offset fac1.Fac_man	;point to mantissa
		call	shl_man			;up into bit 79 ready
fpi1:
		call	shl_man			;shift bits out of mantissa
		rcl	ax,1			;and into ax
		loop	fpi1
int_zero:
		or	ah,bh			;or on any sign
		pop	cx
		pop	bx
		ret
fpint		ENDP



;======================================================================
;
;		>>SIMPLE<< 'helper' functions after here!
;
;======================================================================



;; Load floating point 10 into FAC2
;
fac2_load10	PROC	near
		mov	si,offset fp_10
		mov	di,offset fac2
		call	copy_fac
		ret
fac2_load10	ENDP


;; Load floating point 16 into FAC2
;
fac2_load16	PROC	near
		mov	si,offset fp_16
		mov	di,offset fac2
		call	copy_fac
		ret
fac2_load16	ENDP


;; Load floating point 1 into FAC2
;
fac2_load1	PROC	near
		mov	si,offset fp_1
		mov	di,offset fac2
		call	copy_fac		;put 1 into fac2
		ret
fac2_load1	ENDP


;; Swaps FAC1 and FAC2 via FAC3
;
swap_1and2	PROC	near
		mov	si,offset fac1			;fac 1 --> 3
		mov	di,offset fac3
		call	copy_fac
		mov	si,offset fac2			;fac 2 --> 1
		mov	di,offset fac1
		call	copy_fac
		mov	si,offset fac3			;fac 3 --> 2
		mov	di,offset fac2
		call	copy_fac
		ret
swap_1and2	ENDP


;; Swaps FAC1 and FAC4 via FAC3
;
swap_1and4	PROC	near
		mov	si,offset fac4
		mov	di,offset fac3
		call	copy_fac
		call	fac1_to_4
		mov	si,offset fac3
		mov	di,offset fac1
		call	copy_fac
		ret
swap_1and4	ENDP


;; Copy FAC1 into FAC4
;
fac1_to_4	PROC	near
		mov	si,offset fac1
		mov	di,offset fac4
		call	copy_fac
		ret
fac1_to_4	ENDP


;; Copy FAC4 into FAC1
;
fac4_to_1	PROC	near
		mov	si,offset fac4
		mov	di,offset fac1
		call	copy_fac
		ret
fac4_to_1	ENDP


;; Copy FAC pointed to by SI to DI. Preserves AX, SI
;
copy_fac	PROC	near
		push	si
		push	di
		push	cx
		mov	cx,FAC_LEN
		rep	movsb
		pop	cx
		pop	di
		pop	si
		ret
copy_fac	ENDP


;; Shift left 1 bit mantissa pointed to by SI. Returns last carry flag
;; ** USE NO REGS !!! **
;
shl_man		PROC	near
		shl	byte ptr [si+9],1
		rcl	byte ptr [si+8],1
		rcl	byte ptr [si+7],1
		rcl	byte ptr [si+6],1
		rcl	byte ptr [si+5],1
		rcl	byte ptr [si+4],1
		rcl	byte ptr [si+3],1
		rcl	byte ptr [si+2],1
		rcl	byte ptr [si+1],1
		rcl	byte ptr [si],1
		ret
shl_man		ENDP


;; Shift mantissa @ SI right 1 bit. Returns last carry flag
;
shr_man		PROC	near
		shr	byte ptr [si],1
		rcr	byte ptr [si+1],1
		rcr	byte ptr [si+2],1
		rcr	byte ptr [si+3],1
		rcr	byte ptr [si+4],1
		rcr	byte ptr [si+5],1
		rcr	byte ptr [si+6],1
		rcr	byte ptr [si+7],1
		rcr	byte ptr [si+8],1
		rcr	byte ptr [si+9],1
		ret
shr_man		ENDP


;; Zero the mantissa of the FAC pointed to by si
;
clear_man	PROC	near
		mov	word ptr [si].Fac_man[0],0	;set mantissa to 0
		mov	word ptr [si].Fac_man[2],0
		mov	word ptr [si].Fac_man[4],0
		mov	word ptr [si].Fac_man[6],0
		mov	word ptr [si].Fac_man[8],0
		ret
clear_man	ENDP


;; Zero all bytes in FAC pointer to by SI. Must preserve SI
;
clear_fac	PROC	near
		call	clear_man
		mov	[si].Fac_sign,0
		mov	[si].Fac_exp,0
		ret
clear_fac	ENDP


clear_fac1	PROC	near
		push	si
		mov	si,offset fac1
		call	clear_fac
		pop	si
		ret
clear_fac1	ENDP


;; Copy mantissa pointed to by SI to DI
;
copy_man	PROC	near
		movsw
		movsw
		movsw
		movsw
		movsw
		ret
copy_man	ENDP


;; Save FAC @ SI on stack
;
PushFac		PROC	near
		pop	pushpopret
		push	wptr [si]
		push	wptr [si+2]
		push	wptr [si+4]
		push	wptr [si+6]
		push	wptr [si+8]
		push	wptr [si+10]
		push	wptr [si+12]
		jmp	pushpopret
PushFac		ENDP


;; Pop FAC From Stack to SI
;
PopFac		PROC	near
		pop	pushpopret
		pop	[si+12]
		pop	[si+10]
		pop	[si+8]
		pop	[si+6]
		pop	[si+4]
		pop	[si+2]
		pop	[si]
		jmp	pushpopret

PopFac		ENDP


PushAllFacs	PROC	near
		pop	ax
		mov	si,offset fac1
		call	PushFac
		mov	si,offset fac2
		call	PushFac
		mov	si,offset fac3
		call	PushFac
		mov	si,offset fac4
		call	PushFac
		jmp	ax
PushAllFacs	ENDP


PopAllFacs	PROC	near
		pop	ax
		mov	si,offset fac4
		call	PopFac
		mov	si,offset fac3
		call	PopFac
		mov	si,offset fac2
		call	PopFac
		mov	si,offset fac1
		call	PopFac
		jmp	ax
PopAllFacs	ENDP



MonCode		ENDS
		END

