;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;;
;;		PAGE		,132
;;		TITLE		Real/Protected Mode Monitor
;;		SUBTTL		Disk Specific Include File
;;		Author		Tony Hanratty
;;		Created		11/06/92
;;		Changed		29/09/92
;;
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-


.xlist

;---------------------------------------------------------------------
;		Floppy Disk Manager Equates
;---------------------------------------------------------------------
;
; N.B.  All wait routines presume a 10 MHz processor clock speed.
;
;
FDC_wait	MACRO
		LOCAL	lp1
		push	ax
		mov	ax,150
lp1:		dec	ax
		jnz	lp1
		pop	ax
		ENDM



WAIT8THS	MACRO
		LOCAL	lp1,lp2
lp1:		push	ax
		mov	ax,62000		;only needs 60000 really
lp2:		dec	ax
		jnz	lp2
		pop	ax
		dec	al
		jnz	lp1
		ENDM


waitmilli	MACRO
		LOCAL	lp1,lp2
lp1:		push	ax
		mov	ax,600
lp2:		dec	ax
		jnz	lp2
		pop	ax
		dec	al
		jnz	lp1
		ENDM


; ----- Intel 82072 FDC port/bit definitions

RQM		equ	BIT7			;bits in status port
DIO		equ	BIT6
BUSY		equ	BIT4

DOR_PORT	equ	3f2h
MSR_PORT	equ	3f4h
DATA_PORT	equ	3f5h
DRR_PORT	equ	3f7h


; ----- DMA port definitions

DMA_MASK	equ	0ah
DMA_MODE	equ	0bh
DMA_FLFF	equ	0ch
DMA_ADR		equ	04h
DMA_BASE	equ	05h
DMA_PAGE	equ	81h

; ----- DMA command definitions

DMA_ON		equ	02h
DMA_OFF		equ	06h
DMA_RX_MODE	equ	46h
DMA_TX_MODE	equ	4ah
DMA_VRFY_MODE	equ	42h
TX_DIR		equ	01h
RX_DIR		equ	00h

; ----- Intel 82072 FDC controller commands for FM and MFM encoding

_MFM_FDC_Read		equ	0e6h
_MFM_FDC_Write		equ	0c5h
_MFM_FDC_Format		equ	04dh
_MFM_FDC_ReadID		equ	04ah
_MFM_FDC_ReadTrack	equ	042h
_MFM_FDC_SenseIntStat	equ	008h

_FM_FDC_Read		equ	0a6h
_FM_FDC_Write		equ	085h
_FM_FDC_Format		equ	00dh
_FM_FDC_ReadID		equ	00ah
_FM_FDC_ReadTrack	equ	002h
_FM_FDC_SenseIntStat	equ	008h



; ----- Data Rate Register Values, Drive Types, And Double Step Control
;	( N.B.  All BBC disks are DD)

RATE_500	equ	0		;QD drive, QD diskette\
RATE_300	equ	1		;QD drive, DD diskette > Usually !
RATE_250	equ	2		;DD drive, DD diskette/

_DBL_STEP_FLAG	equ	00000001b
_BBC_DISK_FLAG	equ	00000010b
_FM_DISK_FLAG	equ	00000100b


; MSB = bits flags defined above
; LSB = data rate

DOS_QD_QD_5_RATE	equ	RATE_500		;type 0
DOS_QD_DD_5_RATE	equ	RATE_300		;type 1
DOS_DD_DD_5_RATE	equ	RATE_250		;type 2

BBC_QD_80_RATE		equ	RATE_300		;type 3
BBC_QD_40_RATE		equ	RATE_300		;type 4
BBC_DD_40_RATE		equ	RATE_250		;type 5

DOS_QD_QD_3_RATE	equ	RATE_500		;type 6
DOS_QD_DD_3_RATE	equ	RATE_250		;type 7
DOS_DD_DD_3_RATE	equ	RATE_250		;type 8

ARC_QD_1600_RATE	equ	RATE_500		;type 9

DOS_QD_QD_5_FLAGS	equ	0
DOS_QD_DD_5_FLAGS	equ	_DBL_STEP_FLAG
DOS_DD_DD_5_FLAGS	equ	0

BBC_QD_80_FLAGS		equ	_BBC_DISK_FLAG + _FM_DISK_FLAG
BBC_QD_40_FLAGS		equ	_BBC_DISK_FLAG + _FM_DISK_FLAG + _DBL_STEP_FLAG
BBC_DD_40_FLAGS		equ	_BBC_DISK_FLAG + _FM_DISK_FLAG

DOS_QD_QD_3_FLAGS	equ	0
DOS_QD_DD_3_FLAGS	equ	0
DOS_DD_DD_3_FLAGS	equ	0

ARC_QD_1600_FLAGS	equ	0


NUM_DRIVE_TYPES		equ	10		; 3 BBC, 6 DOS types, 1 ARCHI

DRIVEA_DEFAULT_TYPE	equ	4		; BBC_QD_40
DRIVEB_DEFAULT_TYPE	equ	6		; DOS_QD_QD_3

_GLOBAL_DBL_DEFAULT	equ	1		;dbl step enabled by default
_AUTO_PARAMS_DEFAULT	equ	1		;auto load parameter table


; ----- Stack frame used in floppy disk function interrupt handler

i13stak			STRUC
i13_SaveBP		dw	?
i13_SaveDI		dw	?
i13_SaveSI		dw	?
i13_SaveDS		dw	?
i13_Drive		db	?
i13_Head		db	?
i13_Sector		db	?
i13_Track		db	?
i13_Buffer		dd	?
i13_NumSectors		db	?
i13_Func		db	?
i13_retaddr		dd	?
i13_retflags		dw	?
i13stak			ENDS


DiskBufferSeg		equ	4000h		;where to read/write sectors
DiskBufferLen		equ	0ffffh		;bytes


; ==================== Offsets In param_table =========================

DT_SPEC1	equ	0	;4 bit step rate & 4 bit head unload times
DT_SPEC2	equ	1	;7 bit head load time & 1 bit DMA flag
DT_OFF_TIM	equ	2	;motor off count in clock ticks (36 typical)
DT_BYT_SEC	equ	3	;bytes/sector (0=128, 1=256, 2=512, 3=1024 etc)
DT_SEC_TRK	equ	4	;physical sectors per track
DT_GAP		equ	5	;intersector gap on read/write (42 typical)
DT_DTL		equ	6	;data transfer length (255 typical)
DT_GAP3		equ	7	;intersector gap on format (80 typical)
DT_FIL_BYT	equ	8	;fill byte for format command (F6 usually)
DT_HD_TIM	equ	9	;head settle time sfter seek in ms (25 typical)
DT_STR_TIM	equ	10	;motor startup time (1/8 secs)
DT_LOG_HEADS	equ	11	;number of logical heads (BBC=1, DOS=2|1)
DT_SEC1_NUM	equ	12	;logical number of 1st sector on track (0 or 1)
DT_EOT_SEC	equ	13	;logical number of last sector on track
DT_NUM_TRACKS	equ	14	;number of tracks on disk - 1
DT_INTERLEAVE	equ	15	;interleave, obviously
DT_DATA_RATE	equ	16	;data transfer rate & spindle speed control
DT_DISK_FLAGS	equ	17	;double step & disk type flags
DT_PHYS_HEADS	equ	18	;number of physical heads



.list
