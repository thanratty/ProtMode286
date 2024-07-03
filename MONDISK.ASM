.286P

;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;;
		PAGE		,132
		TITLE		Real/Protected Mode Monitor
		SUBTTL		82072 Floppy Disk Controller Routines
;;		Author		Tony Hanratty
;;		Created		12/04/91
;;		Last Changed	04/12/92
;;
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-


		include		moncomn.inc	;common equates etc..
		include		mondisk.inc
		include		mondesc.inc	;for SEGdesc structure



; ----- Monitor Code Externals

		extrn	phexword:near, phexbyte:near, phexchar:near
		extrn	gethexbyte:near, cls:near, HomeCursor:near
		extrn	pcrlf:near, pspace:near, pspace2:near, pspace3:near
		extrn	pstring:near, pchar:near, gkey:near, ishexchar:near
		extrn	beep:near, gethexword:near, Ucase:near, keystat:near
		extrn	phexbytePRN:near, pspacePRN:near, pcrlfPRN:near
		extrn	keypeek:near, gkeye:near, pdecimal:near
		extrn	_dump_block:near

		extrn	DSload:near, load_ESdumpseg:near, paddr:near
		extrn	Address24:near, NewMenu:near
		extrn	menuexit:near, showhelp:near, getcommand:near
		extrn	GetdBase:near

		extrn	BeebCopy:near

; ----- Monitor Data Externals

		extrn	dumpseg:word
		extrn	dES:abs

; ----- Local Code Publics

		public	fdisk_io, FlopSys, motor_off, FDCmode
		public	SetDisks, InitDiskSys

; ----- Local Data Publics

		public	MotorCount, MotorStatus, SeekStatus
		public	GlobalDblEnable

; ----- Temporary Publics

		public	format_table





; Handy debugging macro

xpd		MACRO	arg1
		pushf
		push	bx
		mov	bl,arg1
		call	pchar
		pop	bx
		popf
		ENDM




; ========================================================================
;
;			Floppy Disk Data Segment Start
;
; ========================================================================
;
MonData		SEGMENT para public 'DATA'



;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
;;		   R E A D   O N L Y   D A T A   F I R S T
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

;
; Floppy Disk Menu Commands
;
_readsector_cmd		equ	'R','S'
_writesector_cmd	equ	'W','S'
_formattrack_cmd	equ	'F','T'
_flopparmshow_cmd	equ	'D','V'
_fdcstatshow_cmd	equ	'D','S'
_flopparmset_cmd	equ	'S','V'
_seektrack_cmd		equ	'S','E'
_resetfdc_cmd		equ	'R','E'
_clearstatus_cmd	equ	'C','S'
_readtrack_cmd		equ	'R','T'
_patchtable_cmd		equ	'P','T'
_resettable_cmd		equ	'R','P'
_pdisktable_cmd		equ	'D','T'
_dumpbuffer_cmd		equ	'D','B'
_clearbuffer_cmd	equ	'C','B'
_togglemode_cmd		equ	'T','M'
_readID_cmd		equ	'I','D'
_beebcopy_cmd		equ	'B','B'
_toggledouble_cmd	equ	'T','D'
_toggleparams_cmd	equ	'T','P'
_surfacetest_cmd	equ	'S','T'
_identifyformat_cmd	equ	'I','F'



;
; Floppy disk menu functions
;
FloppyMenu	LABEL		byte
		CmdTabEntry		<_readsector_cmd, ReadSector>
		CmdTabEntry		<_writesector_cmd, WriteSector>
		CmdTabEntry		<_formattrack_cmd, FormatTrack>
		CmdTabEntry		<_menuexit_cmd, menuexit>
		CmdTabEntry		<_flopparmshow_cmd, FlopParmShow>
		CmdTabEntry		<_fdcstatshow_cmd, FdcStatShow>
		CmdTabEntry		<_flopparmset_cmd, FlopParmSet>
		CmdTabEntry		<_showhelp_cmd, showhelp>
		CmdTabEntry		<_seektrack_cmd, SeekTrack>
		CmdTabEntry		<_resetfdc_cmd, ResetFdc>
		CmdTabEntry		<_clearstatus_cmd, ClearStatus>
		CmdTabEntry		<_readtrack_cmd, ReadTrack>
		CmdTabEntry		<_patchtable_cmd, PatchTable>
		CmdTabEntry		<_resettable_cmd, ResetTable>
		CmdTabEntry		<_pdisktable_cmd, pDiskTable>
		CmdTabEntry		<_dumpbuffer_cmd, DumpBuffer>
		CmdTabEntry		<_clearbuffer_cmd, ClearBuffer>
		CmdTabEntry		<_togglemode_cmd, ToggleMode>
		CmdTabEntry		<_readID_cmd, ReadID>
		CmdTabEntry		<_beebcopy_cmd, BeebCopy>
		CmdTabEntry		<_toggledouble_cmd, ToggleDouble>
		CmdTabEntry		<_toggleparams_cmd, ToggleParams>
		CmdTabEntry		<_surfacetest_cmd, SurfaceTest>
		CmdTabEntry		<_identifyformat_cmd, FindDiskType>
		db		0	; end of menu



FloppyHelp	LABEL	byte

	db	lf,lf,cr,'FLOPPY DISK COMMANDS...'
	db	cr,lf,' '
	db	_readsector_cmd,	' Read A Sector                 '
	db	_pdisktable_cmd,	' Display Parameter Table'
	db	cr,lf,' '
	db	_writesector_cmd,	' Write A Sector                '
	db	_patchtable_cmd,	' Patch Parameter Table'
	db	cr,lf,' '
	db	_seektrack_cmd,		' Seek Current Track            '
	db	_resettable_cmd,	' Reset Parameter Table'
	db	cr,lf,' '
	db	_readtrack_cmd,		' Read Current Track            '
	db	_flopparmshow_cmd,	' Display Cyl,Hd,Sec'
	db	cr,lf,' '
	db	_formattrack_cmd,	' Format Track                  '
	db	_flopparmset_cmd,	' Set Cyl,Hd,Sec'
	db	cr,lf,' '
	db	_readID_cmd,		' Read ID Under Head            '
	db	_fdcstatshow_cmd,	' Display Last FDC Status'
	db	cr,lf,' '
	db	_clearbuffer_cmd,	' Clear Sector Buffer           '
	db	_clearstatus_cmd,	' Reset All Status Bytes'
	db	cr,lf,' '
	db	_dumpbuffer_cmd,	' Dump Sector Buffer            '
	db	_resetfdc_cmd,		' Software Reset FDC'
	db	cr,lf,' '
	db	_showhelp_cmd,		' Command Help                  '
	db	_togglemode_cmd,	' Toggle FM and MFM'
	db	cr,lf,' '
	db	_beebcopy_cmd,		' BBC Disk Copy                 '
	db	_toggledouble_cmd,	' Toggle Double Step Enable'
	db	cr,lf,' '
	db	_toggleparams_cmd,	' Toggle Auto Params Load       '
	db	_menuexit_cmd,		' Quit'
	db	cr,lf,' '
	db	_surfacetest_cmd,	' Surface Test                  '
	db	_identifyformat_cmd,	' Identify Disk Format'
	db	cr,lf,lf,null





dt0_mess	db	'b7-b4 = SRT  b3-b0 = HUT                    : ',null
dt1_mess	db	'b7 - b1 = HLT   b0 = ND                     : ',null
dt2_mess	db	'motor off count in clock ticks              : ',null
dt3_mess	db	'bytes/sector (0=128, 1=256, 2=512 etc)      : ',null
dt4_mess	db	'physical sectors/track                      : ',null
dt5_mess	db	'read/write gap length (GPL 1Bh typical)     : ',null
dt6_mess	db	'data transfer length (FFh typical)          : ',null
dt7_mess	db	'intersector gap on format (54h typical)     : ',null
dt8_mess	db	'fill byte for format command (F6h typical)  : ',null
dt9_mess	db	'head settle time in ms (25 typical)         : ',null
dt10_mess	db	'motor spin up time in 1/8 secs (8 typical)  : ',null
dt11_mess	db	'number of logical heads                     : ',null
dt12_mess	db	'1st physical sector number (0 or 1)         : ',null
dt13_mess	db	'last sector # on track (EOT)                : ',null
dt14_mess	db	'number of tracks - 1                        : ',null
dt15_mess	db	'sector interleave                           : ',null
dt16_mess	db	'data rate  0=500  1=300  2=250              : ',null
dt17_mess	db	'double step & disk type flags               : ',null
dt18_mess	db	'number of physical heads                    : ',null

param_table_len	equ	19	;byte length of table

dtab_mess_addr	dw	dt0_mess, dt1_mess, dt2_mess, dt3_mess
		dw	dt4_mess, dt5_mess, dt6_mess, dt7_mess
		dw	dt8_mess, dt9_mess, dt10_mess, dt11_mess
		dw	dt12_mess, dt13_mess, dt14_mess, dt15_mess
		dw	dt16_mess, dt17_mess, dt18_mess




;-------- Parameter tables for differant supported disk & drive types --------;

params_DOS_QD_QD_5	LABEL	byte
	db	0dfh, 010h, 37, 2,15, 01Bh, 0FFh
	db	054h, 0F6h, 15, 6, 2, 1, 15,79,1
	db	DOS_QD_QD_5_RATE, DOS_QD_QD_5_FLAGS, 2
params_DOS_QD_DD_5	LABEL	byte
	db	0efh, 010h, 37, 2, 9, 01Bh, 0FFh
	db	050h, 0F6h, 15, 6, 2, 1, 9,39,1
	db	DOS_QD_DD_5_RATE, DOS_QD_DD_5_FLAGS, 2
params_DOS_DD_DD_5	LABEL	byte
	db	0dfh, 010h, 37, 2, 9, 02Ah, 0FFh
	db	050h, 0F6h, 25, 6, 2, 1, 9,39,1
	db	DOS_DD_DD_5_RATE, DOS_DD_DD_5_FLAGS, 2
params_BBC_QD_80	LABEL	byte
	db	0efh, 010h, 48, 1, 10, 054h, 0FFh
	db	050h, 0E5h, 15, 6, 1, 0,9,79,1
	db	BBC_QD_80_RATE, BBC_QD_80_FLAGS, 2
params_BBC_QD_40	LABEL	byte
	db	0efh, 010h, 48, 1, 10, 054h, 0FFh
	db	050h, 0E5h, 15, 6, 1, 0,9,39,1
	db	BBC_QD_40_RATE, BBC_QD_40_FLAGS, 2
params_BBC_DD_40	LABEL	byte
	db	0dfh, 010h, 48, 1, 10, 054h, 0FFh
	db	050h, 0E5h, 15, 6, 1, 0,9,39,1
	db	BBC_DD_40_RATE, BBC_DD_40_FLAGS, 2
params_DOS_QD_QD_3	LABEL	byte
	db	0DFh, 004h, 37, 2, 18, 01Bh, 0FFh
	db	06Ch, 0F6H, 15, 5, 2, 1,18,79,1
	db	DOS_QD_QD_3_RATE, DOS_QD_QD_3_FLAGS, 2
params_DOS_QD_DD_3	LABEL	byte
    	db	0efh, 002h, 37, 2, 9, 01BH, 0FFH
	db	050H, 0F6h, 15, 5, 2, 1,9,79,1
	db	DOS_QD_DD_3_RATE, DOS_QD_DD_3_FLAGS, 2
params_DOS_DD_DD_3	LABEL	byte
	db	0EFh, 002h, 37, 2, 9, 01BH, 0FFH
	db	050H, 0F6h, 15, 5, 2, 1,9,79,1
	db	DOS_DD_DD_3_RATE, DOS_DD_DD_3_FLAGS, 2
params_ARC_QD_1600	LABEL	byte
	db	0DFh, 004h, 37, 3, 10, 01Bh, 0FFh
	db	06Ch, 0A5H, 15, 5, 2, 0,9,79,1
	db	ARC_QD_1600_RATE, ARC_QD_1600_FLAGS, 2



param_table_types	LABEL	word
	dw	params_DOS_QD_QD_5, params_DOS_QD_DD_5, params_DOS_DD_DD_5
	dw	params_BBC_QD_80,   params_BBC_QD_40,   params_BBC_DD_40
	dw	params_DOS_QD_QD_3, params_DOS_QD_DD_3, params_DOS_DD_DD_3
	dw	params_ARC_QD_1600


dtype_0		db	'Type (0)    5¬" DOS QD drive QD disk',null
dtype_1		db	'Type (1)    5¬" DOS QD drive DD disk',null
dtype_2		db	'Type (2)    5¬" DOS DD drive DD disk',null
dtype_3		db	'Type (3)    5¬" BBC QD drive 80 track disk',null
dtype_4		db	'Type (4)    5¬" BBC QD drive 40 track disk',null
dtype_5		db	'Type (5)    5¬" BBC DD drive 40 track disk',null
dtype_6		db	'Type (6)    3«" DOS QD drive QD disk',null
dtype_7		db	'Type (7)    3«" DOS QD drive DD disk',null
dtype_8		db	'Type (8)    3«" DOS DD drive DD disk',null
dtype_9		db	'Type (9)    3«" ARC QD drive 1600K disk',null


TypeMsgTable	dw	dtype_0, dtype_1, dtype_2
		dw	dtype_3, dtype_4, dtype_5
		dw	dtype_6, dtype_7, dtype_8
		dw	dtype_9


CurDrive_mess	db	cr,lf
		db	'Current Drive : ',null
CurHead_mess	db	'         Head : ',null
CurTrack_mess	db	'        Track : ',null
CurSector_mess	db	'       Sector : ',null
CurCount_mess	db	' Sector Count : ',null



MotorStatus_mess	db	cr,lf,'Motor Status : ',null
MotorCount_mess		db	cr,lf,'Motor Count  : ',null
SeekStatus_mess		db	cr,lf,'Seek Status  : ',null
DiskStatus_mess		db	cr,lf,'Disk Status  : ',null

ResetFdc_mess		db	cr,lf,'Reset returns C,AX = ',null
readreturn_mess		db	cr,lf,'Read returns C,AX = ',null
writereturn_mess	db	cr,lf,'Write returns C,AX = ',null
formatreturn_mess	db	cr,lf,'Format returns C,AX = ',null
dmasetuperror_mess	db	cr,lf,'DMA setup error',cr,lf,null
seekfail_mess		db	cr,lf,'Seek failed',cr,lf,null
readtrackerror_mess	db	cr,lf,'Error !',cr,lf,null
patch_mess		db	cr,lf,lf,'Change which number (Q=QUIT) : '
			db	21 dup (space), 21 dup (bs), null
newval_mess		db	'     New Value : ',null
tablereset_mess		db	cr,lf,'Parameter Table Reset',cr,lf,null
buffercleared_mess	db	cr,lf,'Disk buffer cleared',cr,lf,null
notyet_mess		db	cr,lf,'Not implemented',cr,lf,null
modeFM_mess		db	cr,lf,'Switched to FM (single density) mode'
			db	cr,lf,null
modeMFM_mess		db	cr,lf,'Switched to MFM (double density) mode'
			db	cr,lf,null
rid_err_mess		db	cr,lf,'Read ID: Error!',cr,lf,null
driveAtype_mess		db	cr,lf,_fg_BOLD_ON,'Drive A: ',_fg_BOLD_OFF,null
driveBtype_mess		db	cr,lf,_fg_BOLD_ON,'Drive B: ',_fg_BOLD_OFF,null
changetypeQ_mess	db	cr,lf,lf,'Change drive types (Y/N) ? ',null
newAtype_mess		db	cr,lf,'New Drive A: type: ',null
newBtype_mess		db	cr,lf,'New Drive B: type: ',null
DblStep_mess		db	cr,lf,'Double Stepping Now ',null
AutoParam_mess		db	cr,lf,'Auto Parameter Table Loads ',null
enabled_mess		db	'Enabled',cr,lf,null
disabled_mess		db	'Disabled',cr,lf,null
proceedYN_mess		db	cr,lf,'Proceed (Y/N) : ',null

surftest_mess		db	cr,lf,'Surface test disk in drive ',null
tracks_mess		db	' Tracks',cr,lf,null
physheads_mess		db	' Physical Heads',cr,lf,null
sectrack_mess		db	' Sectors per Track',cr,lf,null

SurfTrack_mess		db	cr,'Track:', null
SurfHead_mess		db	'   Head:', null

FAIL_mess		db	'   **FAIL**',cr,lf,null
finished_mess		db	cr,lf,lf,'Finished.',cr,lf,null

TypeFound_mess		db	cr,lf,'Type Found!',cr,lf,bell,null



;;-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-;;
;;		R E A D / W R I T E  D A T A  A F T E R  H E R E       ;;
;;-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-;;


FdcCommand	db	0
DmaCommand	db	0

DiskStatus	db	0
MotorCount	db	0		;decremented by INT 8
SeekStatus	db	0		;bit definitions in MONCOMN.INC
MotorStatus	db	0		;bit definitions in MONCOMN.INC


FdcStatusLen	equ	7
FdcStatus	db	FdcStatusLen dup (0)
		db	0			;one byte buffer !!
;+0,1,2 = ST0, ST1, ST2
;+3 = end_track
;+4 = end_head
;+5 = end_sector
;+6 = sector size code

param_table	db	param_table_len dup (0)		;active param table


;; FDC i82072 commands (default to MFM mode)
;
FDC_Read		db	_MFM_FDC_Read
FDC_Write		db	_MFM_FDC_Write
FDC_Format		db	_MFM_FDC_Format
FDC_ReadID		db	_MFM_FDC_ReadID
FDC_ReadTrack		db	_MFM_FDC_ReadTrack
FDC_SenseIntStat	db	_MFM_FDC_SenseIntStat

FDCmode			db	1		;1=MFM  0=FM



; ----- Drive/disk types for data transfer speed, double step control,
;	and BBC disks flag. (see MONDISK.INC)
;	Keep in this order!!

DriveTypes	LABEL	byte
driveAtype	db	DRIVEA_DEFAULT_TYPE		;default drive types
driveBtype	db	DRIVEB_DEFAULT_TYPE		;= FDC data rate


format_table	db	12h dup (4 dup (0))		;12h sectors max


CurDrive		db	0	;params for fdisk_io call
CurSector		db	1
CurHead			db	0
CurTrack		db	0
CurCount		db	1

SurfaceTrack		db	0	;used in surface test
SurfaceHead		db	0

t_drive			db	?	;private to fdisk_io
t_track			db	?
t_head			db	?
t_sec			db	?
t_numsecs		db	?
t_secsthistime		db	?

GlobalDblEnable		db	_GLOBAL_DBL_DEFAULT	;double step enable
AutoParamsEnable	db	_AUTO_PARAMS_DEFAULT	;auto parameters load

SaveSeekHead		db	0
SaveSeekTrack		db	0			;used in seek routine
SaveSeekDrive		db	0
SaveSeekTrackSingle	db	0			;uncorrected track #


		PUBLIC	DiskDataEnd
DiskDataEnd	LABEL	byte

MonData		ENDS


;------------------------------------------------------------------------
;----------------------- END OF LOCAL FLOPPY DATA -----------------------
;------------------------------------------------------------------------





; ===========================================================================
;
; 		    START OF DISK HANDLER CODE SEGMENT
;
; ===========================================================================

MonCode		SEGMENT	para public 'CODE'
		ASSUME	cs:MonCode, ds:MonData



;
; Configure Disk & Drive types
;
SetDisks	PROC	near
		mov	si,offset driveAtype_mess
		call	pstring
		mov	bl,driveAtype			;get drive A type
		add	bl,bl				;*2 for word table
		mov	bh,0
		mov	si,TypeMsgTable[bx]		;get message address
		call	pstring				;print it

		mov	si,offset driveBtype_mess
		call	pstring
		mov	bl,driveBtype			;get drive B type
		add	bl,bl
		mov	bh,0				;*2 for word table
		mov	si,TypeMsgTable[bx]		;get message address
		call	pstring				;print it

		mov	si,offset changetypeQ_mess	;change types question
		call	pstring				;print it
sd_gkey:	call	gkey				;get a keypress
		call	Ucase				;to uppercase
		mov	bl,al				;in BL for printing
		cmp	al,'N'				;N for no ?
		je	sd_exit				;yep - exit
		cmp	al,'Y'				;Y for yes ?
		jne	sd_gkey				;no - loop till Y or N

		call	pchar				;print the key

		call	pcrlf				;2 blank lines
		call	pcrlf
		mov	cx,NUM_DRIVE_TYPES		;# types to print
		mov	di,offset TypeMsgTable
SD_type:	mov	si,[di]
		call	pstring
		call	pcrlf
		add	di,2
		loop	SD_type

		mov	si,offset newAtype_mess		;ask for new A type
		call	pstring
sd_goptA:	call	gkey				;get a key
		sub	al,'0'				;base on 0
		cmp	al,NUM_DRIVE_TYPES-1		;cmp to max type
		ja	sd_goptA			;loop if higher
		mov	driveAtype,al			;save option #
		mov	bl,al				;new type in BL
		call	phexchar			;and print it

; Now do exactly the same for drive B: (ie no comments!)

		mov	si,offset newBtype_mess		;ask for new A type
		call	pstring
sd_goptB:	call	gkey				;get a key
		sub	al,'0'				;base on 0
		cmp	al,NUM_DRIVE_TYPES-1		;max type ?
		ja	sd_goptB			;loop if higher
		mov	driveBtype,al			;save option #
		mov	bl,al				;new type in BL
		call	phexchar			;and print it
		call	pcrlf

		call	ResetTable			;reset params for A:
		ret

sd_exit:	call	pchar				;the 'N' for 'no'!
		call	pcrlf
		ret
SetDisks	ENDP




;
; N.B. This table is in the code segment, so needs a CS: override.
;
i13_JumpTable	LABEL	word
		dw	FDCreset
		dw	i13_RWV		;read
		dw	i13_RWV		;write
		dw	i13_RWV		;verify
		dw	i13_Format



; ----- handle the floppy disk function service call
;	N.B. stack frame defined in MONDISK.INC
;
fdisk_io	PROC	near

		push	ax
		push	es
		push	bx
		push	cx
		push	dx
		push	ds
		push	si
		push	di
		push	bp
		mov	bp,sp

		call	DSload

		mov	ax,ds
		mov	es,ax
		mov	cx,FdcStatusLen
		mov	di,offset FdcStatus
		mov	al,0
		rep	stosb

		jmp	short i13_ChkParams


; ----- handy place to have the error trap for short jumps

i13_param_err:	mov	ah,BAD_CMD
		mov	DiskStatus,ah
		jmp	short i13_done

; ----- validate calling parameters here to save checks in main handler

i13_ChkParams:	cmp	[bp].i13_Func, MAX_FDC_FUNCTION
		ja	i13_param_err
		cmp	[bp].i13_Drive,1	;only A: or B:
		ja	i13_param_err
		cmp	[bp].i13_Func, 0	;is this a reset request ?
		je	i13_ParamsOK		;yes - dont check head #
		cmp	[bp].i13_Head, 1	;only heads 0 & 1 on a floppy
		ja	i13_param_err


; ----- calling params all check out, on with the show

i13_ParamsOK:	call	EmptyFDC		;handy place to empty FDC

; ----- setup correct parameter table

		mov	al,[bp].i13_Drive
		call	PrepareDrive

; ----- now set the data rate depending on the disk & drive type

		mov	al,param_table [DT_DATA_RATE]
		mov	dx,DRR_PORT		;send to FDC
		out	dx,al

; ----- now call selected function

		mov	ah,DiskStatus		;save old status before we
		mov	DiskStatus,0		;zero it

		mov	bl,[bp].i13_Func
		mov	bh,0
		shl	bx,1
		call	cs:i13_JumpTable [bx]

; ----- If RW function was sucessful, AL=# sectors transferred

i13_done:	and	[bp].i13_retflags, 0fffeh	;clear return C flag
		mov	ah,DiskStatus
		cmp	ah,0
		je	i13_exit
		or	[bp].i13_retflags, 1		;set return C flag

i13_exit:	pop	bp
		pop	di
		pop	si
		pop	ds
		pop	dx
		pop	cx
		pop	bx
		pop	es
		add	sp,2			;remove callers AX
		iret

fdisk_io	ENDP






;;
;; Main Read/Write/Verify Control Loop
;;
i13_RWV		PROC	near

		mov	DiskStatus,0

; Init local param copies

		mov	al,[bp].i13_Drive
		mov	t_drive,al
		mov	al,[bp].i13_Track
		mov	t_track,al
		mov	al,[bp].i13_Head
		mov	t_head, al
		mov	al,[bp].i13_Sector
		mov	t_sec, al
		mov	al,[bp].i13_NumSectors
		mov	t_numsecs, al

		call	getFDC_DMAcmds
		mov	FdcCommand, al		;save disk & DMA funcs
		mov	DmaCommand, ah

		call	send_specify		;SRT, HUT, HLT and ND
		jnc	RWV_spec_ok
		jmp	RWV_exit

RWV_spec_ok:	mov	ah,t_drive		;drive 0 or 1
		call	motor_on		;turn its motor on

		cmp	t_numsecs,0		;trap trivial case
		jnz	xtrack_loop
		jmp	RWV_exit		;cmp clears CF

; ----- Now We've doen the once only stuff, check for cross track R/W

xtrack_loop:	mov	DiskStatus,0			;reset for each loop

		mov	al,t_sec			;start sec #
		add	al,t_numsecs			;+ # required
		dec	al				;- fencepost=end sec #

		mov	ah,param_table [DT_EOT_SEC]	;get EOT sector number
		cmp	al,ah				;go past EOTrack ?
		ja	xtrack_yes			;yes, jmp to adjust it
		mov	al,t_numsecs			;else restore count
		jmp	short i13_RWV_xtrack_ok

; ----- RW world cross a track. Change to read to end of track

xtrack_yes:	mov	al,ah				;get EOT sector #
		sub	al,t_sec			; - start
		inc	al				;= # secs to EOTrack

; ----- Thats the cross track checked, read ammended sectors

i13_RWV_xtrack_ok:
		mov	t_secsthistime,al
		call	i13_loadDMA			;config DMA channel
		jc	RWV_exit			;give up if error
   
		mov	al,t_track			;load track num
		mov	ah,t_drive			;and drive
		mov	bl,t_head			;and head
		call	seek				;seek cyl:head:drive
		jc	RWV_exit			;exit if error

		call	FDCcmd_bytes1and2
		jc	RWV_exit
		call	FDCcmd_2ndHalf
		jc	RWV_exit

		call	get_fdc_status
		jc	RWV_exit

		mov	al,param_table [DT_OFF_TIM]
		mov	MotorCount,al			;reset motor timeout

		call	calc_sectors			;returned in AL

		push	ax				;save # sectors
		mov	ah,0				;AX=# sectors
		mov	bx,128
		mov	cl,param_table [DT_BYT_SEC]	;load shift count
		shl	bx,cl				;BX = bytes/sector
		mul	bx				;AX = # bytes xfered
		add	wptr [bp].i13_Buffer, ax	;adjust buffer address
		pop	ax				;restore # sectors

		sub	t_numsecs,al			;sub from # requested
		jz	RWV_exit			;jmp if done (CF=0)

; ----- Still haven't read enough, bump CHS. We will always be at the start
;	of a track by here. The 1st RW reads any initial part tracks so
;	the next R/W always starts with the 1st sector on a track

		mov	al,param_table [DT_SEC1_NUM]	;0 on BBC, 1 on IBM
		mov	t_sec,al
		inc	t_head
		mov	al,t_head
		cmp	al,param_table [DT_LOG_HEADS]
		jb	bump_ok
		mov	t_head,0
		inc	t_track
bump_ok:	jmp	xtrack_loop


RWV_done:	clc
RWV_exit:	ret

i13_RWV		ENDP







;
; Format a track on the disk.
;
i13_Format	PROC	near
		call	getFDC_DMAcmds
		mov	FdcCommand, al			;save disk & DMA funcs
		mov	DmaCommand, ah

		call	send_specify			;SRT, HUT, HLT and ND
		jc	i13_F_err

		mov	ah,t_drive			;drive 0 or 1
		call	motor_on			;turn its motor on

		mov	al,t_track
		mov	ah,t_drive			;and drive # 0 or 1
		mov	bl,t_head
		call	seek				;seek to track in AL
		jc	i13_F_err			;exit if error

		mov	t_secsthistime,1		;huge # bytes to xfer
		call	i13_loadDMA			;config DMA channel
		jc	i13_F_err			;else give up
   
		call	FDCcmd_bytes1and2
		jc	i13_F_err

		call	FormatCmd_2ndHalf
		jc	i13_F_err

		call	get_fdc_status			;read back status
i13_F_err:	
		ret
i13_Format	ENDP









;
; Reset FDC Controller. Called From Floppy Interrupt Handler
; Return CF=0 if no error.
;
FDCreset	PROC	near
		cli
		mov	al,MotorStatus		;keep motor on or off
		and	al,3			;just keep drive bits
		shl	al,4			;to top nibble for motor
		and	al,0f3h
		or	al,8
		mov	dx,DOR_PORT		;point DX to port
		out	dx,al			;reset disk controller
		mov	SeekStatus,0		;force recal, clear INT flag

		push	ax
		mov	al,2			;1/4 second
		WAIT8THS			;let FDC take a breath!!
		pop	ax

		or	al,4			;reset the reset bit
		out	dx,al			;and send it
		sti

		call	wait_int		;wait for interrupt
		jc	resend			;jump if timed out

		call	sense_int		;sense interrupt status cmd
		jc	resend

		call	results
		jc	resend

		test	FdcStatus, 11000000b	;00=command OK
		jz	res5
		or	DiskStatus, BAD_FDC
		stc
		jmp	short resend

res5:		call	send_specify			;send specify command
		jnc	resend
		or	DiskStatus, BAD_FDC

resend:		ret

FDCreset	ENDP






;;
;; Calculate & programme DMA transfer length.
;; # sectors to xfer = t_secsthistime
;; buffer address on stack. (updated after each separate cross track R/W)
;;
i13_loadDMA	PROC	near
		mov	cl,param_table [DT_BYT_SEC]	;get bytes/sec param
		mov	ax,128
		shl	ax,cl
		mov	bl,t_secsthistime		;num sectors to xfer
		mov	bh,0
		mul	bx
		dec	ax				;AX=tx length - 1
		les	bx,[bp].i13_Buffer		;point ES:BX to buffer
		call	dma_setup			;and setup DMA channel
		ret					;return CF
i13_loadDMA	ENDP






;
; Send 1st 2 command bytes to FDC for Read/Write/Format/Verify Commands
; Return CF=1 if error.
;
FDCcmd_bytes1and2	PROC	near
		mov	al,FdcCommand			;get FDC command
		call	send_fdc			;send it
		jc	FDC_b1a2_exit			;exit if error

		mov	al,t_head			;0 or 1
		shl	al,2				;move to bit 2
		add	al,t_drive			;set DS0/DS1 bits
		call	send_fdc			;send to FDC
FDC_b1a2_exit:
		ret					;return CF
FDCcmd_bytes1and2	ENDP





;
; 2nd half of FDC command for READ, WRITE and VERIFY only. Format command
; uses 'FormatCmd_2ndHalf'.
;
FDCcmd_2ndHalf	PROC	near
		mov	al,t_track
		call	send_fdc
		jc	FDC_2h_exit

		mov	al,t_head
		call	CheckBBCHead		;AL always 0 for BBC disks
		call	send_fdc
		jc	FDC_2h_exit

		mov	al,t_sec
		call	send_fdc
		jc	FDC_2h_exit

		mov	al,param_table [DT_BYT_SEC]
		call	send_fdc
		jc	FDC_2h_exit

		mov	al,param_table [DT_SEC_TRK]
		call	send_fdc
		jc	FDC_2h_exit

		mov	al,param_table [DT_GAP]
		call	send_fdc
		jc	FDC_2h_exit

		mov	al,param_table [DT_DTL]
		call	send_fdc
FDC_2h_exit:
		ret					;return CF

FDCcmd_2ndHalf	ENDP






FormatCmd_2ndHalf	PROC	near
		mov	al,param_table [DT_BYT_SEC]	;send bytes/sector
		call	send_fdc
		jc	Fcmd2_exit

		mov	al,param_table [DT_SEC_TRK]	;send sectors/track
		call	send_fdc
		jc	Fcmd2_exit

		mov	al,param_table [DT_GAP3]	;send format gap size
		call	send_fdc
		jc	Fcmd2_exit

		mov	al,param_table [DT_FIL_BYT]	;send sector fill byte
		call	send_fdc
Fcmd2_exit:
		ret					;return CF
FormatCmd_2ndHalf	ENDP







;
; Save Correct FDC & DMA commands into RAM. Reset request must NEVER
; call this routine as it isnt trapped here.
;
; Returns: AL=FDC command, AH=DMA command
;
getFDC_DMAcmds	PROC	near

		mov	al,[bp].i13_Func
		cmp	al,READ_SECTORS
		jne	gFD_write
		and	MotorStatus, NOT WRITE_OR_FORMAT ;0 write/format bit
		mov	al, FDC_Read
		mov	ah, DMA_RX_MODE
		jmp	short gFD_exit

gFD_write:	cmp	al,WRITE_SECTORS
		jne	gFD_verify
		or	MotorStatus, WRITE_OR_FORMAT
		mov	al, FDC_Write
		mov	ah, DMA_TX_MODE
		jmp	short gFD_exit

gFD_verify:	cmp	al,VERIFY_SECTORS
		jne	gFD_format
		and	MotorStatus, NOT WRITE_OR_FORMAT
		mov	al, FDC_Read
		mov	ah, DMA_VRFY_MODE
		jmp	short gFD_exit

gFD_format:	or	MotorStatus, WRITE_OR_FORMAT
		mov	al, FDC_Format
		mov	ah, DMA_TX_MODE
gFD_exit:
		ret
getFDC_DMAcmds	ENDP









;
; Send byte in AL to 82072 FDC
;
send_fdc	PROC	near

		mov	cx,-1			;init timeout counter to FFFF
		mov	dx,MSR_PORT		;point to FDC status port
		mov	ah,al			;keep byte to send in AH

sf_wait:	in	al,dx			;read status
		and	al,(RQM+DIO)		;just keep RQM & DIO bits
		cmp	al,RQM			;must be 1 & 0 to send
		je	sf_ready		;ready to send if OK
		loop	sf_wait			;else loop
		or	DiskStatus, TIME_OUT	;get here if timed out
		stc				;set carry for error
		ret				;return to caller

sf_ready:	inc	dx			;point to data port
		mov	al,ah			;get byte to send
		out	dx,al			;wave bye bye to it

		FDC_wait			;wait a bit

		clc				;flag no error
		ret				;and return to caller
send_fdc	ENDP




;
; ----- Get disk parameter, table offset in AL
;
get_parm	PROC	near
		mov	bx,offset param_table	;point to table base
		xlat				;get param
		ret				;finito
get_parm	ENDP




;
; Turn drive motor on and wait for motor start up time if this is a 
; write operation. Proceed immediately if a read operation.
;
; Call with AH=drive 0 or 1
;
motor_on	PROC	near
		mov	al,param_table [DT_OFF_TIM]	;get motor off count
		cli				;no ints between next 2 lines
		mov	MotorCount, al		;set on-count
		mov	al,MotorStatus		;get current motor status
		sti

		add	ah,1			;now 1 or 2
		test	al,ah			;correct motor bit already on ?
		jnz	m_on_exit		;yes - skip
		and	MotorStatus, 0fch	;clear both motor bits
		or	MotorStatus,ah		;& flag correct drive motor on

		mov	al,ah			;copy 1 or 2 to AL
		shl	al,4			;shift to drive nibble
		or	al,0ch			;DMA/INTs on, reset disabled
		dec	ah			;AH back to 0 or 1
		or	al,ah			;set b0 accordingly
		mov	dx,DOR_PORT
		out	dx,al			;motor on now

		test	MotorStatus,WRITE_OR_FORMAT	;write or format cmd?
		jz	m_on_exit			;its not so exit
		mov	al,param_table [DT_STR_TIM]	;else get motor start
		WAIT8THS				;delay in 1/8 secs

m_on_exit:	and	SeekStatus, NOT DISK_INT_FLAG	;clear reset interrupt
		ret
motor_on	ENDP



; motor_off is also called by the timer interrupt, so save regs

motor_off	PROC	near
		push	ax
		push	dx
		mov	dx,DOR_PORT		;point to port
		mov	al,0ch			;DMA off, no reset, motors off
		out	dx,al			;send it
		mov	MotorCount,0		;zero count & flag motors off
		and	MotorStatus,NOT (DRIVE0_MOTOR_ON + DRIVE1_MOTOR_ON)
		pop	dx
		pop	ax
		ret
motor_off	ENDP



;
; Send specify command to FDC - return C=1 on error, C=0 if no error
;
send_specify	PROC	near
		mov	al,3				;specify command
		call	send_fdc
		jc	ss_exit

		mov	al,param_table [DT_SPEC1]	;SRT & HUT
		call	send_fdc
		jc	ss_exit

		mov	al,param_table [DT_SPEC2]	;HLT & ND
		call	send_fdc

ss_exit:	ret					;return CF
send_specify	ENDP







;
; Wait for the hardware interrupt to occur. Time-out if none
;
wait_int	PROC	near
		sti					;ints on for this baby
		mov	al,MotorCount			;get current motor cnt
		sub	al,40				;about 2 secs

wi_loop:	test	SeekStatus, DISK_INT_FLAG	;interrupt yet ?
		jnz	haveint				;yes - go to it
		cmp	MotorCount,al			;else is time up ?
		jne	wi_loop				;no - then loop
		or	DiskStatus, TIME_OUT		;yes - flag timeout
		stc					;CF=1=error
		ret					;return to caller

haveint:	and	SeekStatus, NOT DISK_INT_FLAG	;clear the int flag
		clc					;say no error
		ret					;and back to caller
wait_int	ENDP





;
; Send 'Sense Interrupt Status' Command to FDC after an interrupt
;
sense_int	PROC	near
		mov	al,FDC_SenseIntStat		;sense interrupt status
		call	send_fdc
		ret					;return CF
sense_int	ENDP





;
; Initialize DMA controller for read, write, verify operations.
; ES:BX --> data buffer
; AX = transfer length - 1   (i.e. correct for 8237)
;
dma_setup	PROC	near
		push	ax			;save byte count

		cli				;ints off
		mov	dx,DMA_FLFF		;point to flippyfloppy reg
		out	dx,al			;any write resets flip flop

		mov	dx,DMA_MODE		;point to command reg
		mov	al,DmaCommand		;load our command
		out	dx,al			;set read/write etc...

		xor	ax,ax			;init address to 0000:0000
		xor	dx,dx
		cmp	DmaCommand, DMA_VRFY_MODE	;are we verifying ?
		je	send_dma			;yes - dont do next bit

; ----- build 20 bit DMA address from GDT entry for ES

		push	bx			;save buffer offset
		mov	bx,es
		call	GetdBase		;24 bit address in DL:AX
		pop	bx
ds_gotseg:	add	ax,bx			;add on offset
		adc	dx,0


send_dma:	mov	bl,dl			;24 bit address in BL:AH:AL
		mov	cx,ax			;save in CX for boundary check

		mov	dx,DMA_ADR		;8273 start address reg
		out	dx,al			;set low byte
		mov	al,ah
		out	dx,al			;then high byte
		mov	dx,DMA_PAGE		;DMA page reg for A16-A23
		mov	al,bl
		out	dx,al			;set page register

		pop	bx			;get byte count back in BX
		mov	ax,bx			;copy into AX
		mov	dx,DMA_BASE		;count register
		out	dx,al			;output low byte
		mov	al,ah
		out	dx,al			;and high byte
		sti				;enable ints

		mov	dx,DMA_MASK
		mov	al,DMA_ON
		out	dx,al			;turn channel on

		add	bx,cx			;check if DMA overflow
		jnc	dma_setup_exit		;jmp if OK
		mov	DiskStatus, DMA_BOUNDARY	;flag the error, CF set

dma_setup_exit:	ret				;return carry flag
dma_setup	ENDP





;
; Call with track # in AL
; Returns corrected track in AL if double step flaged in param table
; Mustn't hurt any regs.
;
CheckDblStep	PROC	near
		cmp	GlobalDblEnable,0		;no double step if
		je	CDS_exit			; globally disabled
		test	param_table [DT_DISK_FLAGS], _DBL_STEP_FLAG
		jz	CDS_exit			;no dbl step, jump
		add	al,al				;else dbl track #
CDS_exit:
		ret					;return
CheckDblStep	ENDP





;
; Call with Head in AL
; Returns corrected head # in AL if BBC flagged in param table
; Must preserve all regs
;
CheckBBCHead	PROC	near
		test	param_table [DT_DISK_FLAGS], _BBC_DISK_FLAG
		jz	CBH_exit			;no, jump out
		mov	al,0				;else zero head #
CBH_exit:	ret					;return
CheckBBCHead	ENDP





;
; Move the head to the selected track: AL=track, AH=drive (0/1)
; Motor already turned on.
;
; Double step head if drive or disk type needs it
;
seek		PROC	near

		mov	SaveSeekHead,bl			;save seek head
		mov	SaveSeekDrive,ah		;& drive
		mov	SaveSeekTrackSingle,al		;& unchecked track #
		call	CheckDblStep			;for track # in AL
		mov	SaveSeekTrack,al		;save checked track

		inc	ah				;drive now 1 or 2
		test	SeekStatus, ah			;drive need recal ?
		jnz	seek_recal_ok			;no - jump

		or	SeekStatus, ah
		dec	ah				;drive back to 0 or 1
		call	recal				;and recal it
		jnc	seek_recal_ok			;jmp out if recal OK

		mov	DiskStatus,0			;else clear status
		mov	ah,SaveSeekDrive		;load drive
		call	recal				;and try recal again
		jc	seek_error			;still error? exit

seek_recal_ok:	and	SeekStatus, NOT DISK_INT_FLAG
		mov	al,0fh				;send seek command
		call	send_fdc
		jc	seek_error

		mov	al,SaveSeekHead
		shl	al,2
		add	al,SaveSeekDrive		;0 or 1
		call	send_fdc
		jc	seek_error

		mov	al,SaveSeekTrack		;get saved track back
		call	send_fdc
		jc	seek_error

		call	wait_int			;wait for an interrupt
		jc	seek_error			;no interrupt - exit

		call	sense_int			;sense interrupt status
		jc	seek_error

		call	results
		jc	seek_error

		test	FdcStatus,11000000b		;check ST0 bits 6&7
		jnz	seek_error

		mov	al,param_table [DT_HD_TIM]	;load parameter
		waitmilli				;wait for head settle

		mov	al,FDC_ReadID			;send read ID command
		call	send_fdc
		jc	seek_exit

		mov	al,SaveSeekHead			;get head number
		shl	al,2				;up to bit 2
		add	al,SaveSeekDrive		;set drive #
		call	send_fdc			;send to FDC
		jc	seek_exit

		call	wait_int
		jc	seek_exit

		call	results				;& read results
		jc	seek_exit

		mov	al,SaveSeekTrackSingle		;get logical track #
		cmp	al,FdcStatus+3			;same as cylinder ID ?
		jne	seek_error			;whoops !

		mov	al,SaveSeekHead
		call	CheckBBCHead			;adjust logical head #
		cmp	al,FdcStatus+4
		je	seek_exit

seek_error:	or	DiskStatus, BAD_SEEK
		stc

seek_exit:	ret					;return CF state

seek		ENDP






;
; ----- Recalibrate drive AH
;
recal		PROC	near

		and	SeekStatus, NOT DISK_INT_FLAG

		push	ax				;save drive # in AH

		mov	al,7				;recallibrate command
		call	send_fdc
		pop	ax				;get drive # back
		jc	recal_exit			;exit if send error

		mov	al,ah				;drive 0 or 1 in AL
		call	send_fdc			;send it
		jc	recal_exit

		call	wait_int			;wait for the interrupt
		jc	recal_exit			;no interrupt - exit

		call	sense_int			;sense interrupt status
		jc	recal_exit

		call	results

recal_exit:	ret					;return carry flag
recal		ENDP




;
; Read the FDC data port till no bytes are left
;
EmptyFDC	PROC	near
		mov	cx,1000				;max # loops
EFloop:	
		mov	dx,MSR_PORT			;point to status port
		in	al,dx				;read it
		and	al,(DIO+RQM)			;just keep DIO & RQM
		cmp	al,RQM				;want DIO=0, RQM=1
		je	EF_done				;done, FDC empty

		inc	dx				;+1 = data port
		in	al,dx				;read it away
		FDC_wait				;wait a bit
		dec	cx
		jnz	short EFloop			;and repeat
EF_done:
		ret
EmptyFDC	ENDP





;
; Read results from the controller following an interrupt
;
results		PROC	near

		mov	ax,ds			;OK in protected mode
		mov	es,ax
		mov	di,offset FdcStatus	;ES:DI --> result store

ByteLoop:	mov	cx,0ffffh		;reset timeout counter

ChkData:	mov	dx,MSR_PORT		;read main status register
		in	al,dx
		and	al,(RQM+DIO)		;both are set if bytes to read
		cmp	al,(RQM+DIO)		;anything to read ?
		jne	ChkBusy			;no - jmp to check busy flag
		inc	dx			;+1 = DATA_PORT
		insb				;I/O from DX --> ES:DI ++
		FDC_wait
		cmp	di,offset FdcStatus+FdcStatusLen
		ja	TooManyBytes		;check if too many bytes
		jmp	short ByteLoop		;start again

ChkBusy:	in	al,dx			;DX still = status reg
		test	al,BUSY			;is FDC still busy ?
		jnz	ChkTimeout		;yes -  so check for timeout
		clc				;else all read, clear carry
		ret				;and exit

ChkTimeout:	loop	ChkData			;loop till CX timeout used
		or	DiskStatus, TIME_OUT	;flag timed out
		stc				;set carry for error
		ret

TooManyBytes:	or	DiskStatus, BAD_FDC	;say something wierd going on
		stc				;flag the error
		ret
results		ENDP






;
; Wait until an operation is complete, then get the FDC status
;
get_fdc_status	PROC	near

		call	wait_int		;returns C flag if timed out
		pushf				;save any timeout CF

; dont call sense int - read result bytes from command

		call	results
		pop	ax			;get CF from wait_int in AX
		jc	gfs_Cexit

		test	al,1
		jz	gfs_no_tout
		cmp	DiskStatus,0
		jz	gfs_noCexit
		jmp	short gfs_Cexit

gfs_no_tout:	test	FdcStatus, 11000000b	;00=normal cmd termination?
		jnz	gfs_not_norm		;no - jump
		cmp	DiskStatus,0
		jz	gfs_noCexit
		jmp	short gfs_Cexit


gfs_not_norm:	mov	al,FdcStatus
		and	al,0c0h
		cmp	al,40h			;cmd started but not finished ?
		je	gfs_not_bad_cmd		;yes, must have been a good cmd
		or	DiskStatus, BAD_FDC
		stc
		ret


gfs_not_bad_cmd:
		mov	al,0			;init status to 0
		mov	ah,FdcStatus+1		;get ST1 error byte

		test	ah,BIT7			;check end of cylinder flag
		jz	gfs_cb5
		or	al, RECORD_NOT_FND
		jmp	short gfs_save_status

gfs_cb5:	test	ah,BIT5			;check CRC data error flag
		jz	gfs_cb4
		or	al, BAD_CRC
		jmp	short gfs_save_status

gfs_cb4:	test	ah,BIT4			;check overrun/underrun flag
		jz	gfs_cb2
		or	al, BAD_DMA
		jmp	short gfs_save_status

gfs_cb2:	test	ah,BIT2			;check no data flag
		jz	gfs_cb1
		or	al, RECORD_NOT_FND
		jmp	short gfs_save_status

gfs_cb1:	test	ah,BIT1			;check write protect flag
		jz	gfs_cb0
		or	al, WRITE_PROTECT
		jmp	short gfs_save_status

gfs_cb0:	test	ah,BIT0			;check missing address mark
		jz	gfs_cbdefault
		or	al,BAD_ADDR_MARK
		jmp	short gfs_save_status

gfs_cbdefault:	or	al, BAD_FDC		;none of above, say FDC error

gfs_save_status:
		or	DiskStatus,al		;save the return status
		cmp	DiskStatus,0		;was it all OK ?
		jne	gfs_Cexit		;no, jump to error exit
gfs_noCexit:	ret				;CF cleared by cmp above

gfs_Cexit:	stc
gfs_exit:	ret
		
get_fdc_status	ENDP





;
; Return number of sectors actually transferred in AX
;
calc_sectors	PROC	near
		cmp	DiskStatus,0			;was there an error ?
		je	cs_2				;no, carry on
		xor	ax,ax				;else say no sectors
		ret					;and return

cs_2:		mov	al,t_head
		call	CheckBBCHead		;correct head # for BBCs

		mov	ch,t_track		;get start params
		mov	cl,al
		mov	bh,t_sec
		call	CHS_to_sectors
		push	ax			;save abs sector num

		mov	ch,FdcStatus+3		;end track
		mov	cl,FdcStatus+4		;end head
		mov	bh,FdcStatus+5		;end sector
		call	CHS_to_sectors

		pop	bx			;get back start sector #
		sub	ax,bx

		ret				;return dirrerance in AX
calc_sectors	ENDP




;
; Passed CHS in CH,CL,BH. Return # sectors from start of disk in AX
; Based on CHS 0:0:1 returns 1.
; Head number already corrected for BBC disks side 2
;
CHS_to_sectors	PROC	near
		mov	al,ch				;get cyls
		mul	param_table [DT_LOG_HEADS]	;= # head tracks in AX
		add	al,cl				;+ head
		mul	param_table [DT_SEC_TRK]	;= # sectors
		add	al,bh
		adc	ah,0
		ret
CHS_to_sectors	ENDP





; ========================================================================
;
;		Floppy Disk Menu System
;
; ========================================================================
;
FlopSys		PROC	near
		mov	si,offset FloppyMenu		;and command ptr
		mov	di,offset FloppyHelp		;print help
		call	NewMenu				;show help if menus on
		call	getcommand			;execute menu
		ret					;back to calling menu
FlopSys		ENDP





;
; Display Currently Selected Head, Track & Sector for fdisk_io calls
;
FlopParmShow	PROC	near
		mov	si,offset CurDrive_mess
		mov	bl,CurDrive
		call	FPS_sub

		mov	si,offset CurTrack_mess
		mov	bl,CurTrack
		call	FPS_sub

		mov	si,offset CurHead_mess
		mov	bl,CurHead
		call	FPS_sub

		mov	si,offset CurSector_mess
		mov	bl,CurSector
		call	FPS_sub

		mov	si,offset CurCount_mess
		mov	bl,CurCount
		call	FPS_sub

		call	pcrlf
		ret


FPS_sub:	call	pstring
		call	phexbyte
		call	pcrlf
		ret

FlopParmShow	ENDP





;
; Show last 82072 status : ST0 ST1 ST2 C H R N
;
FdcStatShow	PROC	near
		call	pcrlf
		mov	cx,FdcStatusLen			;# bytes to print
		mov	si,offset FdcStatus		;point to buffer

fss_1:		lodsb					;get a byte
		mov	bl,al				;move to BL
		call	phexbyte			;and print it
		call	pspace
		loop	fss_1				;do all bytes
		call	pcrlf

; ----- Now show the four ram status bytes

		mov	si,offset MotorStatus_mess
		call	pstring
		mov	bl,MotorStatus
		call	phexbyte

		mov	si,offset SeekStatus_mess
		call	pstring
		mov	bl,SeekStatus
		call	phexbyte

		mov	si,offset DiskStatus_mess
		call	pstring
		mov	bl,DiskStatus
		call	phexbyte

		mov	si,offset MotorCount_mess
		call	pstring
		mov	bl,MotorCount
		call	phexbyte

		call	pcrlf
		ret
FdcStatShow	ENDP




;
; Read disk into diskbuffer using values set into CurDrive, CurHead etc...
; and the parameters from the disk parameter table. If change the values
; in the parameter table from the floppy disk menu you can even read BBC
; computer disks with this routine.
;
ReadSector	PROC	near
		mov	ah,READ_SECTORS
		mov	al,CurCount
		mov	dumpseg,DiskBufferSeg		;disk buffer segment
		call	load_ESdumpseg			;real/prot mode load
		xor	bx,bx				;to buffer offset 0
		mov	ch,CurTrack			;load up variables
		mov	cl,CurSector
		mov	dh,CurHead
		mov	dl,CurDrive
		int	FloppyInt			;read the disk

		push	ax				;save return status
		pushf					;and carry flag
		mov	si,offset readreturn_mess	;print return val msg
		call	pstring
		popf					;get back carry flag
		call	pCarry				;print it
		mov	bl,','				;then a comma
		call	pchar
		pop	ax				;get back return status
		mov	bx,ax
		call	phexword			;and print it
		call	pcrlf

		ret
ReadSector	ENDP


WriteSector	PROC	near
		mov	ah,WRITE_SECTORS
		mov	al,CurCount
		mov	dumpseg,DiskBufferSeg	;disk buffer segment
		call	load_ESdumpseg		;read & protected mode load
		xor	bx,bx			;offset 0
		mov	ch,CurTrack
		mov	cl,CurSector
		mov	dh,CurHead
		mov	dl,CurDrive
		int	FloppyInt		;request disk service

		push	ax
		pushf
		mov	si,offset writereturn_mess
		call	pstring
		popf
		call	pCarry
		mov	bl,','
		call	pchar
		pop	ax
		mov	bx,ax
		call	phexword

		call	pcrlf
		ret
WriteSector	ENDP



;
; Reset/Clear FDC status bytes
;
ClearStatus	PROC	near
		mov	DiskStatus,0			;clear RAM status bytes
		mov	MotorStatus,0
		mov	SeekStatus,0

		mov	ax,ds				;OK in protected mode
		mov	es,ax
		mov	cx,FdcStatusLen
		mov	di,offset FdcStatus
		mov	al,0
		rep	stosb				;zero FDC status bytes

		call	FdcStatShow			;show we cleared them

		call	pcrlf
		ret
ClearStatus	ENDP



;
; Reset using function 0 call to fdisk_io (ie software reset)
;
ResetFdc	PROC	near
		mov	si,offset ResetFdc_mess
		call	pstring

		mov	ah,0				;reset function
		mov	dl,0				;load a valid drive num
		int	FloppyInt			;request disk service

		call	pCarry				;show return carry
		mov	bl,','				;then a comma
		call	pchar
		mov	bx,ax				;AH = return status
		call	phexword			;print it
		call	pcrlf
		ret
ResetFdc	ENDP




;
; Seek to track CurTrack, head CurHead on drive CurDrive
;
SeekTrack	PROC	near
		call	EmptyFDC			;make sure its empty
		mov	ah,CurDrive			;turn on the motor
		call	motor_on
		mov	al,CurTrack			;seek track number
		mov	ah,CurDrive			;on which drive
		mov	bl,CurHead
		call	seek				;do it
		call	pcrlf
		call	FdcStatShow			;show return status
		call	pcrlf
		ret
SeekTrack	ENDP



;
; Read Current ID Under Disk Head
;
ReadID		PROC	near
		and	SeekStatus, NOT DISK_INT_FLAG	;clear int flag

		call	EmptyFDC			;empty out FDC

		mov	ah,CurDrive			;which drive
		call	motor_on			;turn its motor on

		mov	al,FDC_ReadID			;send read ID command
		call	send_fdc
		jc	rid_error

		mov	al,CurHead			;get head number
		shl	al,2				;up to bit 2
		add	al,CurDrive			;set drive #
		call	send_fdc			;send to FDC
		jc	rid_error

		call	wait_int
		jc	rid_error

		call	results				;& read results
		jc	rid_error

		call	FdcStatShow			;else show return vals
		ret

rid_error:	mov	si,offset rid_err_mess		;say we had an error
		call	pstring
		call	pcrlf
		ret

ReadID		ENDP




;
; Print carry flag state 0 or 1 (and preserve its setting)
;
pCarry		PROC	near
		pushf				;save regs we use
		push	bx

		mov	bl,'0'
		adc	bl,0			;add on carry
		call	phexchar		;print it
		
		pop	bx
		popf
		ret
pCarry		ENDP





;
; Prompt for Drive, Cyl, Head, Sector etc. for next disk access
;
FlopParmSet	PROC	near
		mov	si,offset CurDrive_mess
		mov	bl,CurDrive
		call	fps_get
		mov	CurDrive,bl

		mov	si,offset CurTrack_mess
		mov	bl,CurTrack
		call	fps_get
		mov	CurTrack,bl

		mov	si,offset CurHead_mess
		mov	bl,CurHead
		call	fps_get
		mov	CurHead,bl

		mov	si,offset CurSector_mess
		mov	bl,CurSector
		call	fps_get
		mov	CurSector,bl

		mov	si,offset CurCount_mess
		mov	bl,CurCount
		call	fps_get
		mov	CurCount,bl

		call	pcrlf
		ret


fps_get:	call	pstring
		push	bx
		call	phexbyte
		mov	si,offset newval_mess
		call	pstring
		call	keypeek
		cmp	al,cr
		jne	fps_new
		call	gkey			;read away CR
		pop	bx
		push	bx
		call	phexbyte		;print default
		pop	bx
		jmp	short fps_g2

fps_new:	pop	bx
		call	gethexbyte
fps_g2:		call	pcrlf
		ret

FlopParmSet	ENDP





;
; Reads a whole track, ignores ID & CRC errors
;
ReadTrack	PROC	near
		mov	al,CurDrive
		call	PrepareDrive

		call	EmptyFDC
		mov	ah,CurDrive
		call	motor_on
		mov	al,CurTrack		;seek track number
		mov	ah,CurDrive
		mov	bl,CurHead
		call	seek
		jnc	rt0
		mov	si,offset seekfail_mess
		call	pstring
		ret

; 1st work out # bytes in 1 track of data

rt0:		mov	cl,param_table [DT_BYT_SEC]
		mov	bx,128
		shl	bx,cl
		mov	al,param_table [DT_SEC_TRK]
		cbw
		mul	bx				;AX=byte count

		mov	dumpseg, DiskBufferSeg
		call	load_ESdumpseg
		xor	bx,bx				;ES:BX --> buffer

		mov	DmaCommand, DMA_RX_MODE
		call	dma_setup

		jnc	rt2
		mov	si,offset dmasetuperror_mess
		call	pstring
		ret

rt2:		mov	al,FDC_ReadTrack
		call	send_fdc
		jc	rt_err

		mov	al,CurHead
		shl	al,2
		add	al,CurDrive
		call	send_fdc
		jc	rt_err

		mov	al,CurTrack
		call	send_fdc
		jc	rt_err

		mov	al,CurHead
		call	CheckBBCHead
		call	send_fdc
		jc	rt_err

		mov	al,CurSector
		call	send_fdc
		jc	rt_err

		mov	al,param_table [DT_BYT_SEC]
		call	send_fdc
		jc	rt_err

		mov	al,param_table [DT_SEC_TRK]
		call	send_fdc
		jc	rt_err

		mov	al,param_table [DT_GAP]
		call	send_fdc
		jc	rt_err

		mov	al,param_table [DT_DTL]
		call	send_fdc
		jc	rt_err

		call	wait_int
		jc	rt_err

		call	results
		jc	rt_err
		ret

rt_err:		mov	si,offset readtrackerror_mess
		call	pstring
		ret

ReadTrack	ENDP






;
; Patch values in disk parameter table
;
PatchTable	PROC	near

		call	cls

PT_loop:	call	HomeCursor
		call	pDiskTable
		mov	si,offset patch_mess
		call	pstring

PT_getkey:	call	keypeek
		cmp	al,'q'
		jne	PT_patch
		call	gkeye
		call	pcrlf
		ret

PT_patch:	call	gethexbyte
		cmp	bl,param_table_len - 1
		ja	PT_loop

		mov	bh,0				;# as word in BX
		mov	di,bx				;now in DI
		mov	si,offset newval_mess
		call	pstring
		call	gethexbyte
		mov	param_table [di], bl		;save new value
		jmp	short PT_loop

PT_exit:	call	pcrlf
		ret
PatchTable	ENDP





;
; Print disk parameter table contents
;
pDiskTable	PROC	near
		call	pcrlf
		mov	si,offset dtab_mess_addr
		mov	dl,0			;keep count in DL

pDT_loop:	mov	bl,dl			;get count in BL
		call	phexbyte		;print it
		call	pspace3
		lodsw				;get text address in AX
		xchg	ax,si			;swap with text pointer
		call	pstring			;keeps ptr in AX
		mov	si,ax			;restore message table ptr
		mov	al,dl			;get count in AL
		call	get_parm		;get that param
		mov	bl,al			;print it
		call	phexbyte
		call	pcrlf			;new line
		inc	dl
		cmp	dl,param_table_len
		jne	pDT_loop
		call	pcrlf
		ret
pDiskTable	ENDP





;
; Reset disk parameter table to drive A default type
;
ResetTable	PROC	near

		call	_resettable
		mov	si,offset tablereset_mess
		call	pstring
		ret

_resettable:	mov	di,offset param_table
		mov	ax,ds				;OK in protected mode
		mov	es,ax
		mov	cx,param_table_len

		mov	bl,driveAtype			;get drive A type
		mov	bh,0				;as word
		shl	bx,1				;x2 for word table
		mov	si,param_table_types[bx]	;get correct table ptr

		rep	movsb
		ret

ResetTable	ENDP



;
; Clear/Wipe the diskbuffer to 33 hex
;
ClearBuffer	PROC	near
		mov	dumpseg, DiskBufferSeg
		call	load_ESdumpseg
		xor	di,di
		mov	cx,DiskBufferLen/2
		mov	ax,3333h			;good visible value!
		rep	stosw

		mov	si,offset buffercleared_mess
		call	pstring
		ret
ClearBuffer	ENDP




;
; Dump the diskbuffer to the screen
;
DumpBuffer	PROC	near
		call	pcrlf
		mov	dumpseg, DiskBufferSeg
		call	load_ESdumpseg
		xor	di,di				;ES:DI --> buffer
		mov	cx,DiskBufferLen/16		;# paras to display
		call	_dump_block
		call	pcrlf
		ret
DumpBuffer	ENDP





FormatTrack	PROC	near
		mov	al,CurDrive
		call	PrepareDrive

		mov	ax,ds
		mov	es,ax

		mov	al,CurTrack
		mov	ah,CurHead
		mov	dl,param_table [DT_SEC1_NUM]
		mov	dh,param_table [DT_BYT_SEC]

		mov	di,offset format_table
		mov	cl,param_table [DT_SEC_TRK]
		mov	ch,0

init_Ftable:	stosw
		xchg	ax,dx
		stosw
		xchg	ax,dx
		inc	dl
		loop	init_Ftable

		mov	ah,FORMAT_TRACK
		mov	bx,offset format_table
		mov	ch,CurTrack
		mov	dh,CurHead
		mov	dl,CurDrive
		int	FloppyInt

		push	ax				;save return status
		pushf					;and carry flag
		mov	si,offset formatreturn_mess	;print return val msg
		call	pstring
		popf					;get back carry flag
		call	pCarry				;print it
		mov	bl,','				;then a comma
		call	pchar
		pop	bx				;get back return status
		call	phexword			;and print it
		call	pcrlf

		ret
FormatTrack	ENDP



;
; Set FDC command variables to MFM mode
;
SetMFM		PROC	near
		mov	FDC_Read, _MFM_FDC_Read
		mov	FDC_Write, _MFM_FDC_Write
		mov	FDC_Format, _MFM_FDC_Format
		mov	FDC_ReadID, _MFM_FDC_ReadID
		mov	FDC_ReadTrack, _MFM_FDC_ReadTrack
		mov	FDC_SenseIntStat, _MFM_FDC_SenseIntStat
		mov	FDCmode,1
		ret
SetMFM		ENDP



;
; Set FDC command variables to FM mode
;
SetFM		PROC	near
		mov	FDC_Read, _FM_FDC_Read
		mov	FDC_Write, _FM_FDC_Write
		mov	FDC_Format, _FM_FDC_Format
		mov	FDC_ReadID, _FM_FDC_ReadID
		mov	FDC_ReadTrack, _FM_FDC_ReadTrack
		mov	FDC_SenseIntStat, _FM_FDC_SenseIntStat
		mov	FDCmode,0
		ret
SetFM		ENDP




;
; Toggle Between FM (single density) and MFM (double density)
;
ToggleMode	PROC	near
		mov	bx,offset SetMFM		;preload MFM stuff
		mov	si,offset modeMFM_mess

		cmp	FDCmode,0
		jz	tm_set				;jump if FM (0)
		mov	bx,offset SetFM
		mov	si,offset modeFM_mess

tm_set:		call	bx				;set command variables
		call	pstring				;display new mode
		ret
ToggleMode	ENDP





InitDiskSys	PROC	near
		mov	driveAtype, DRIVEA_DEFAULT_TYPE
		mov	driveBtype, DRIVEB_DEFAULT_TYPE

		call	_resettable		;reset parameter table

		mov	ah,0			;reset FDC
		mov	dl,0
		int	FloppyInt
				
		mov	CurDrive,0
		mov	CurTrack,0
		mov	CurHead,0
		mov	CurSector,1
		mov	CurCount,1

		call	motor_off

		mov	SeekStatus,0

		ret
InitDiskSys	ENDP





;
; Call with 0 or 1 in AL for drive A: or B:
; Copies that drives parameter table into the active param_table
; and set encoding to FM or MFM depending on disk flags.
;
; If automatic parameter loading is not enabled just return.
;
PrepareDrive	PROC	near
		test	AutoParamsEnable,1		;auto load enabled ?
		jnz	PD_enabled			;yes - jmp to load
		ret					;else just return

PD_enabled:	mov	bx,offset DriveTypes
		xlat
		cbw
		shl	ax,1
		mov	bx,ax
		mov	si,param_table_types[bx]
		mov	di,offset param_table
		mov	cx,param_table_len
		mov	ax,ds
		mov	es,ax
		rep	movsb

		mov	bx,offset SetFM
		test	param_table [DT_DISK_FLAGS], _FM_DISK_FLAG
		jnz	PD_setmode
		mov	bx,offset SetMFM
PD_setmode:	call	bx
		ret
PrepareDrive	ENDP





ToggleDouble	PROC	near
		mov	si,offset DblStep_mess
		call	pstring
		mov	si,offset enabled_mess
		xor	GlobalDblEnable, 1		;flip flag
		jnz	TD_pstate			;enabled if <> 0
		mov	si,offset disabled_mess		;else disabled
TD_pstate:	call	pstring
		ret
ToggleDouble	ENDP





ToggleParams	PROC	near
		mov	si,offset AutoParam_mess
		call	pstring
		mov	si,offset enabled_mess
		xor	AutoParamsEnable, 1
		jnz	TP_pstate
		mov	si,offset disabled_mess
TP_pstate:	call	pstring
		ret
ToggleParams	ENDP




SurfaceTest	PROC	near
		mov	si,offset surftest_mess
		call	pstring
		mov	bl,CurDrive
		add	bl,'A'
		call	pchar
		mov	bl,':'
		call	pchar
		call	pcrlf

		mov	al,CurDrive
		call	PrepareDrive			;setup param table

		mov	bl,param_table [DT_NUM_TRACKS]
		mov	si,offset tracks_mess
		call	ST_pinfo

		mov	bl,param_table [DT_PHYS_HEADS]
		mov	si,offset physheads_mess
		call	ST_pinfo

		mov	bl,param_table [DT_SEC_TRK]
		mov	si,offset sectrack_mess
		call	ST_pinfo

		mov	si,offset proceedYN_mess
		call	pstring
		call	getYN				;return CF=1 if NO
		jnc	ST_test
		call	pcrlf
		ret

ST_test:	mov	SurfaceTrack,0
		mov	SurfaceHead,0

ST_loop:	call	keystat
		jz	ST_loop2
		call	gkey
		ret

ST_loop2:	mov	si,offset SurfTrack_mess
		call	pstring
		mov	bl,SurfaceTrack
		mov	bh,0
		call	pdecimal
		mov	si,offset SurfHead_mess
		call	pstring
		mov	bl,SurfaceHead
		mov	bh,0
		call	pdecimal

		mov	ah,READ_SECTORS
		mov	al,param_table [DT_SEC_TRK]
		mov	dumpseg,DiskBufferSeg		;disk buffer segment
		call	load_ESdumpseg			;real/prot mode load
		xor	bx,bx				;to buffer offset 0
		mov	ch,SurfaceTrack			;load up variables
		mov	cl,param_table [DT_SEC1_NUM]
		mov	dh,SurfaceHead
		mov	dl,CurDrive
		int	FloppyInt			;read the disk
		jnc	ST_ok
		mov	si,offset FAIL_mess
		call	pstring

		mov	ah,0
		mov	dl,0
		int	FloppyInt			;reset disk sys

ST_ok:		inc	SurfaceHead
		mov	al,SurfaceHead
		cmp	al,param_table [DT_PHYS_HEADS]
		jb	ST_loop
		mov	SurfaceHead,0

		inc	SurfaceTrack
		mov	al,SurfaceTrack
		cmp	al,param_table [DT_NUM_TRACKS]
		jbe	ST_loop

		mov	si,offset finished_mess
		call	pstring
		ret
SurfaceTest	ENDP




ST_pinfo:	mov	bh,0
		call	pdecimal
		call	pstring
		ret


getYN:		call	gkey
		call	Ucase
		cmp	al,'Y'
		je	gyn_Y
		cmp	al,'N'
		jne	getYN
		mov	bl,al
		call	pchar
		stc
		ret

gyn_Y:		mov	bl,al
		call	pchar
		clc
		ret



COMMENT #

p_t_vars:	call	pcrlf
		mov	bl,t_track
		call	phexbyte
		call	pspace
		mov	bl,t_head
		call	phexbyte
		call	pspace
		mov	bl,t_sec
		call	phexbyte
		call	pspace
		mov	bl,t_numsecs
		call	phexbyte
		call	pspace
		mov	bl,t_secsthistime
		call	phexbyte
		call	pcrlf
		ret

#




FindDiskType	PROC	near
		call	SetMFM
		mov	AutoParamsEnable,0		;disable auto load


ModeLoop:
		mov	param_table [DT_BYT_SEC],3	;1K bytes/sec max
SecSizeLoop:
		mov	param_table [DT_DATA_RATE],2	;500 b.p.s.
RateLoop:

		call	pIFinfo

		call	FDCreset

		mov	dx,03f4h
		in	al,dx
		cmp	al,80h
		je	resetok

retry_error:	mov	bl,bell
		call	pchar
		jmp	short RateLoop


resetok:	and	SeekStatus, NOT DISK_INT_FLAG	;clear int flag
		call	EmptyFDC			;empty out FDC
		and	SeekStatus, NOT DISK_INT_FLAG	;and again!
		call	sense_int
		call	results				;& read results

		mov	ah,CurDrive			;which drive
		call	motor_on			;turn its motor on

		mov	al,FDC_ReadID			;send read ID command
		call	send_fdc
		jc	retry_error

		mov	al,CurDrive			;ID on drive (head 0)
		call	send_fdc			;send to FDC
		jc	retry_error

		call	wait_int
		jc	retry_error

		call	sense_int
		jc	retry_error

		call	results				;& read results
		jc	retry_error

		test	FdcStatus, 11000000b
		jz	type_found


type_error:	dec	param_table [DT_DATA_RATE]
		jns	RateLoop			;loop till FF

		dec	param_table [DT_BYT_SEC]
		jns	SecSizeLoop			;till FF

		cmp	FDCmode,0
		je	type_exit
		call	SetFM
		jmp	ModeLoop

type_exit:
		ret

type_found:	mov	si,offset TypeFound_mess
		call	pstring
		ret



pIFinfo:	mov	bl,FDCmode
		call	phexbyte
		call	pspace
		mov	bl,param_table [DT_BYT_SEC]
		call	phexbyte
		call	pspace
		mov	bl,param_table [DT_DATA_RATE]
		call	phexbyte
		call	pcrlf
		ret



FindDiskType	ENDP






; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-

		PUBLIC	DiskCodeEnd
DiskCodeEnd	LABEL	byte			;handy for MON.MAP

MonCode		ENDS

		END

