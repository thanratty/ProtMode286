;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;;
;;		PAGE		,132
;;		TITLE		Real/Protected Mode Monitor
;;		SUBTTL		Common Include File For All .ASMs
;;		Author		Tony Hanratty
;;		Created		11/06/92
;;		Changed		11/06/92
;;
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-


.xlist

; ----- Simple character ASCII equates...

lf		equ	10			;line feed
cr		equ	13			;carriage return
bs		equ	8			;back space
space		equ	20h			;space key/char
null		equ	0			;null character
tab		equ	9			;tab key
bell		equ	7			;bell/beep
escape		equ	27			;escape key
eot		equ	'$'			;DOS end of text marker

;; Handy assembler equates for shorter lines

bptr		equ	byte ptr
wptr		equ	word ptr
dptr		equ	dword ptr


;; General equates

_ON		equ	1
_OFF		equ	2


;; Escape command bytes

_EC_FGCOL_CMD	equ	1			;+ colour #
_EC_BOLD_CMD	equ	2			;+ _ON/_OFF
_EC_MOVE_ABS	equ	3			;+ (X,Y)
_EC_MOVE_REL	equ	4			;+ +/- X +/- Y (wont wrap)
_EC_CLR_EOL	equ	5			;clear to end of line
_EC_CLR_EOS	equ	6			;clear to end of screen
_EC_RPT_CHAR	equ	7			;+ char 'c', 'n' times


;; Escape command sequences

_CLR_EOL	equ	escape, _EC_CLR_EOL
_STRING		equ	escape, _EC_RPT_CHAR


;; Change text foreground colour. Escape command sequences

_fg_BLUE	equ	escape, _EC_FGCOL_CMD, 1
_fg_GREEN	equ	escape, _EC_FGCOL_CMD, 2
_fg_CYAN	equ	escape, _EC_FGCOL_CMD, 3
_fg_RED		equ	escape, _EC_FGCOL_CMD, 4
_fg_PURPLE	equ	escape, _EC_FGCOL_CMD, 5
_fg_BROWN	equ	escape, _EC_FGCOL_CMD, 6
_fg_WHITE	equ	escape, _EC_FGCOL_CMD, 7

_fg_MIN_COL	equ	1
_fg_MAX_COL	equ	7


;; Change text bold attribute. Escape command sequences.

_fg_BOLD_ON	equ	escape, _EC_BOLD_CMD, _ON
_fg_BOLD_OFF	equ	escape, _EC_BOLD_CMD, _OFF




;; Video memory location

ColorSeg	equ	0b800h
MonoSeg		equ	0b000h


; ----- General Monitor Equates...

uppermask	equ	11011111b		;uppercase char AND mask
kbufflen	equ	20			;keyboard buffer length


; ----- Set runtime address to 64k from start of memory

RunSeg		equ	1000h
RunSeg_lo	equ	(RunSeg AND 00fffh) SHL 4
RunSeg_hi	equ	(RunSeg AND 0f000h) SHR 12



; ----- Menu command table format

CmdTabEntry		STRUC
_cmd_letters		db	?
			db	?
_cmd_address		dw	?
CmdTabEntry		ENDS
CmdEntryLen		equ	size CmdTabEntry


; ----- Handy bit masks

BIT7   		equ	80h
BIT6   		equ	40h
BIT5   		equ	20h
BIT4   		equ	10h
BIT3   		equ	08h
BIT2   		equ	04h
BIT1   		equ	02h
BIT0   		equ	01h


; ----- Disk Service Call Return Codes (Old INT 13)

TIME_OUT	equ	080h
BAD_SEEK	equ	040h
BAD_FDC		equ	020h
BAD_CRC		equ	010h
INVALID_MEDIA	equ	0c0h
DMA_BOUNDARY	equ	009h
BAD_DMA		equ	008h
MEDIA_CHANGED	equ	006h
RECORD_NOT_FND	equ	004h
WRITE_PROTECT	equ	003h
BAD_ADDR_MARK	equ	002h
BAD_CMD		equ	001h


; ----- Disk Service Call Functions (Old INT 13 ish)

RESET_FDC		equ	0
READ_SECTORS		equ	1
WRITE_SECTORS		equ	2
VERIFY_SECTORS		equ	3
FORMAT_TRACK		equ	4

MAX_FDC_FUNCTION	equ	4


; ----- Bit Definitions For 'SeekStatus' Byte

DRIVE0_RECAL		equ	01h	;0=must recal on next access
DRIVE1_RECAL		equ	02h
DISK_INT_FLAG		equ	80h	;1=floppy interrupt detected


; ----- Bit Definitions For 'MotorStatus' Byte

DRIVE0_MOTOR_ON		equ	01h
DRIVE1_MOTOR_ON		equ	02h
WRITE_OR_FORMAT		equ	80h	;1=current cmd  is a write or format


; ----- Command common to all menus (no quit in top level though)

_showhelp_cmd		equ	'H','E'
_menuexit_cmd		equ	'Q','U'


;
;	IF YOU CHANGE ANY OF THESE INTERRUPT NUMBERS YOU MUST ALSO
;	CHANGE THEIR ENTRIES IN THE INTERRUPT DESCRIPTOR TABLE
;
; Ints 00-1F hex reserved by Intel (the swines!)
; Ints 20-27 hex are now H/W ints from 8259 PIC
;
Timer_hw_Int		equ	20h
Kybd_hw_Int		equ	21h
Floppy_hw_Int		equ	26h
;
; Ints 28-FF are user definable
;
FloppyInt		equ	28h
TrapsOnInt		equ	29h
TrapsOffInt		equ	2Ah



; ----- Turns Single Step Flag on and off (Debug Macros)

TrapsOff	MACRO
		int	TrapsOffInt
		ENDM

TrapsOn		MACRO
		int	TrapsOnInt
		ENDM


		;; Move these back to monfp.asm when finished!

EXP_BIAS	equ	16384			;; Exponent bias
MANTISSA_LEN	equ	10			;; <<< Must be even !!!
FAC_LEN		equ	13

Fac		STRUC
Fac_sign	db	?
Fac_man		db	MANTISSA_LEN dup (?)
Fac_exp		dw	?
		db	?			;; even size
Fac		ENDS


.list
