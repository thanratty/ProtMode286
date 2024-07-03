.286C

;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;;
;;              PAGE            ,132
;;              TITLE           Real/Protected Mode Monitor
;;              SUBTTL          C <-> ASM Interface for BBC Disks
;;              Author          Tony Hanratty
;;              Created         27/10/92
;;              Last Changed    03/12/92
;;
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-


;
; These routines interface from assembler to C.
; They call main monitor routines for disk access, I/O, memory allocation etc
;
; All read/writes of BBC disks should be localised in this module.
;

                include         moncomn.inc
                include         mondisk.inc


; ----- temporaries

                extrn   phexword:near, _dump_block:near
		extrn	phexchar:near
		extrn	beep:near, pchar:near

; ----- External C Functions

		extrn	C_BeebCopyTop:near

; ----- Monitor Code Externals

                extrn   phexbyte:near, pstring:near, pcrlf:near
		extrn	pdecimal:near
                extrn   pspace:near, gkey:near, Ucase:near
                extrn   load_ESdumpseg:near

; ----- Monitor Data Externals

                extrn   dumpseg:word

; ----- Local Code Publics

                public  BeebCopy
                public  read_DOS_CHS, write_DOS_CHS
                public  read_BBC_CHS

; ----- External C Data

		extrn	BBCside:byte, show_DCHS:byte


; ----- Handy debugging macro

xpd		MACRO	arg1
		pushf
		push	bx
		mov	bl,arg1
		call	pchar
		pop	bx
		popf
		ENDM





DOS_DRIVE               equ     1               ;must match #defines in 'C'
BBC_DRIVE               equ     0
MAX_RETRIES		equ	4		;R/W number of retries




MonData         SEGMENT para public 'DATA'

;; ---- Read only Data First

DOSread_mess    db      'Reading DOS Disk DCHSN = ',null
DOSwrite_mess   db      'Writing DOS Disk DCHSN = ',null
BBCread_mess    db      'Reading BBC Disk DCHSN = ',null

OK_mess_lo      db      '  : OK',null
FAIL_mess_lo    db      '  : **FAIL**   ',bell,null

;; ---- Read/Write Data Next

retry_count	db	?

MonData         ENDS






MonCode         SEGMENT para public 'CODE'
                ASSUME  cs:MonCode, ds:MonData



;
; Copy files from a BBC disk to a DOS disk.  (All done in C)
;
BeebCopy        PROC    near

		call	C_BeebCopyTop
		ret

BeebCopy        ENDP







;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;;
;;		Assembler Functions Called By C Routines
;;
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-



;
;
; Read BBC Disk At Cyl:Head:Sector Using Monitor Disk Interrupt
; N.B. Head is ignored and taken from BBCside instead!
;
rb              STRUC
rb_savebp       dw      ?
rb_retaddr      dw      ?
rb_drive        dw      ?
rb_cyl          dw      ?
rb_head         dw      ?
rb_sec          dw      ?
rb_num          dw      ?
rb_buffer       dd      ?
rb              ENDS
;
;
; Called by 'C' with params on stack. Returns code in AX
; No validation on parameters.
;
read_BBC_CHS    PROC    near
                push    bp
                mov     bp,sp                   ;point to stack frame

		cmp	show_DCHS,1
		jne	rb_dchs

                mov     si,offset BBCread_mess
                call    pstring

                mov     bl, bptr [bp].rb_drive
                call    phexbyte_sp
                mov     bl, bptr [bp].rb_cyl
                call    phexbyte_sp
                mov     bl, BBCside
                call    phexbyte_sp
                mov     bl, bptr [bp].rb_sec
                call    phexbyte_sp
                mov     bl, bptr [bp].rb_num
                call    phexbyte_sp
		mov	bx, wptr [bp].rb_buffer+2
		call	phexword
		mov	bl,':'
		call	pchar
		mov	bx, wptr [bp].rb_buffer
		call	phexword_sp


rb_dchs:	mov	retry_count, MAX_RETRIES

rb_try_loop:	mov     ah,READ_SECTORS
                les     bx, [bp].rb_buffer              ;buffer address
                mov     al, bptr [bp].rb_num
                mov     ch, bptr [bp].rb_cyl            ;load up variables
                mov     cl, bptr [bp].rb_sec
                mov     dh, BBCside
                mov     dl, bptr [bp].rb_drive
                int     FloppyInt                       ;read the disk

		jnc	rb_results
		dec	retry_count
		stc
		jz	rb_results
		call	beep				;saves AX
		call	reset_flopsys
		jmp	short rb_try_loop

rb_results:	call    presult_lo
		jc	rb_exit
		xor	ax,ax
rb_exit:	pop     bp
                ret

read_BBC_CHS    ENDP









;
; Read DOS disk at specified cylinder, head, sector.
;
rd              STRUC
rd_savebp       dw      ?
rd_retaddr      dw      ?
rd_drive        dw      ?
rd_cyl          dw      ?
rd_head         dw      ?
rd_sec          dw      ?
rd_num          dw      ?
rd_buffer       dd      ?
rd              ENDS
;
;
; Called by 'C' with params on stack. Return code in AX
; No validation on parameters.
;
read_DOS_CHS    PROC    near
                push    bp
                mov     bp,sp                   ;point to stack frame

		cmp	show_DCHS,1
		jne	rd_dchs

                mov     si,offset DOSread_mess
                call    pstring

                mov     bl, bptr [bp].rd_drive
                call    phexbyte_sp
                mov     bl, bptr [bp].rd_cyl
                call    phexbyte_sp
                mov     bl, bptr [bp].rd_head
                call    phexbyte_sp
                mov     bl, bptr [bp].rd_sec
                call    phexbyte_sp
                mov     bl, bptr [bp].rd_num
                call    phexbyte_sp
		mov	bx, wptr [bp].rd_buffer+2
		call	phexword
		mov	bl,':'
		call	pchar
		mov	bx, wptr [bp].rd_buffer
		call	phexword_sp

rd_dchs:	mov	retry_count, MAX_RETRIES

rd_try_loop:    mov     ah,READ_SECTORS
                les     bx, [bp].rd_buffer              ;to buffer offset 0
                mov     al, bptr [bp].rd_num
                mov     ch, bptr [bp].rd_cyl            ;load up variables
                mov     cl, bptr [bp].rd_sec
                mov     dh, bptr [bp].rd_head
                mov     dl, bptr [bp].rd_drive
                int     FloppyInt                       ;read the disk

		jnc	rd_results
		dec	retry_count
		stc
		jz	rd_results
		call	beep
		jmp	short rd_try_loop

rd_results:     call    presult_lo
                jc      wd_exit                         ;jmp if error
                xor     ax,ax                           ;else return 0
rd_exit:        pop     bp
                ret

read_DOS_CHS    ENDP








;
; Write to DOS disk at specified cylinder, head, sector.
;
wd              STRUC
wd_savebp       dw      ?
wd_retaddr      dw      ?
wd_drive        dw      ?
wd_cyl          dw      ?
wd_head         dw      ?
wd_sec          dw      ?
wd_num          dw      ?
wd_buffer       dd      ?
wd              ENDS
;
;
; Called by 'C' with params on stack. Return code in AX
; No validation on parameters here, done by monitor.
;
write_DOS_CHS   PROC    near
                push    bp
                mov     bp,sp                   ;point to stack frame

		cmp	show_DCHS,1
		jne	wd_dchs

                mov     si,offset DOSwrite_mess
                call    pstring

                mov     bl, bptr [bp].wd_drive
                call    phexbyte_sp
                mov     bl, bptr [bp].wd_cyl
                call    phexbyte_sp
                mov     bl, bptr [bp].wd_head
                call    phexbyte_sp
                mov     bl, bptr [bp].wd_sec
                call    phexbyte_sp
                mov     bl, bptr [bp].wd_num
                call    phexbyte_sp
		mov	bx, wptr [bp].wd_buffer+2
		call	phexword
		mov	bl,':'
		call	pchar
		mov	bx, wptr [bp].wd_buffer
		call	phexword_sp

wd_dchs:	mov	retry_count, MAX_RETRIES

wd_try_loop:    mov     ah,WRITE_SECTORS
                les     bx, [bp].wd_buffer		;buffer address
                mov     al, bptr [bp].wd_num
                mov     ch, bptr [bp].wd_cyl            ;load up variables
                mov     cl, bptr [bp].wd_sec
                mov     dh, bptr [bp].wd_head
                mov     dl, bptr [bp].wd_drive
                int     FloppyInt                       ;read the disk

		jnc	wd_results
		dec	retry_count
		stc
		jz	wd_results
		call	beep
		jmp	short wd_try_loop

wd_results:     call    presult_lo
                jc      wd_exit                         ;jmp if error
                xor     ax,ax                           ;else return 0
wd_exit:        pop     bp
                ret

write_DOS_CHS   ENDP





phexword_sp	PROC	near
		call	phexword
		call	pspace
		ret
phexword_sp	ENDP


phexbyte_sp     PROC    near
                call    phexbyte
                call    pspace
                ret
phexbyte_sp     ENDP




;
; The _lo suffix here means 'low level', ie not done in the 'C' routines!
;
presult_lo      PROC    near
                pushf
		push	ax
		lahf
		cmp	show_DCHS,1
		jne	prl_exit

                mov     si,offset OK_mess_lo
		test	ah,1
                jz	prl_1
                mov     si,offset FAIL_mess_lo
prl_1:		call    pstring
		call    pcrlf

prl_exit:	pop     ax
		popf
		ret
presult_lo	ENDP




;
; To keep C happy.
;
        	PUBLIC  $begin
$begin  	PROC    near
        	ret
$begin  	ENDP





; ==========================================================================
;			Called From C To Print A String
; ==========================================================================
;
asm_p		STRUC
asm_p_savebp	dw	?
asm_p_retaddr	dw	?
asm_p_ptr	dw	?
asm_p		ENDS
;
;
		PUBLIC	asm_pstring
asm_pstring	PROC	near
		push	bp
		mov	bp,sp
		mov	si,[bp].asm_p_ptr
		call	pstring
		pop	bp
		ret
asm_pstring	ENDP




reset_flopsys	PROC	near
		mov	ah,0
		mov	dl,0
		int	FloppyInt
		mov	ah,0
		mov	dl,1
		int	FloppyInt
		ret
reset_flopsys	ENDP





; ==========================================================================
;			Called From C To Print A Hex Word
; ==========================================================================
;
aphw		STRUC
aphw_savebp	dw	?
aphw_retaddr	dw	?
aphw_arg	dw	?
aphw		ENDS
;
;
		PUBLIC	asm_phexword
asm_phexword	PROC	near
		push	bp
		mov	bp,sp
		mov	bx,[bp].aphw_arg
		call	phexword
		pop	bp
		ret
asm_phexword	ENDP







aphb		STRUC
aphb_savebp	dw	?
aphb_retaddr	dw	?
aphb_arg	dw	?
aphb		ENDS
;
;
		PUBLIC	asm_phexbyte
asm_phexbyte	PROC	near
		push	bp
		mov	bp,sp
		mov	bl,bptr [bp].aphb_arg
		call	phexbyte
		pop	bp
		ret
asm_phexbyte	ENDP






_asm_pfname	STRUC
apfn_savebp	dw	?
apfn_retaddr	dw	?
apfn_arg	dw	?
_asm_pfname	ENDS
;
;
		PUBLIC	asm_pfilename
asm_pfilename	PROC	near
		push	bp
		mov	bp,sp

		mov	si,[bp].apfn_arg
		mov	cx,7
apfn_lp:	lodsb
		mov	bl,al
		call	pchar
		loop	apfn_lp

		pop	bp
		ret
asm_pfilename	ENDP






aphdw		STRUC
aphdw_savebp	dw	?
aphdw_retaddr	dw	?
aphdw_arg_lo	dw	?
aphdw_arg_hi	dw	?
aphdw		ENDS
;
;
		PUBLIC	asm_phexdword
asm_phexdword	PROC	near
		push	bp
		mov	bp,sp
		mov	bx,[bp].aphdw_arg_hi
		call	phexword
		mov	bx,[bp].aphdw_arg_lo
		call	phexword
		pop	bp
		ret
asm_phexdword	ENDP





apch		STRUC
apch_savebp	dw	?
apch_retaddr	dw	?
apch_arg	dw	?
apch		ENDS
;
;
		PUBLIC	asm_pchar
asm_pchar	PROC	near
		push	bp
		mov	bp,sp
		mov	bx,[bp].apch_arg
		call	pchar				;in BL
		pop	bp
		ret
asm_pchar	ENDP






_asm_pdec	STRUC
apd_savebp	dw	?
apd_retaddr	dw	?
apd_arg		dw	?
_asm_pdec	ENDS
;
		PUBLIC	asm_pdecimal
asm_pdecimal	PROC	near
		push	bp
		mov	bp,sp
		mov	bx,[bp].apd_arg
		call	pdecimal
		pop	bp
		ret
asm_pdecimal	ENDP




		PUBLIC	asm_gkey
asm_gkey	PROC	near
		push	bp
		call	gkey			;in AL
		pop	bp
		ret				;return char in AL
asm_gkey	ENDP


		extrn	AllocMem:near, DeAllocMem:near


_asm_alloc	STRUC
aal_savebp	dw	?
aal_retaddr	dw	?
aal_length	dw	?
_asm_alloc	ENDS
;
		PUBLIC	asm_alloc_mem
asm_alloc_mem	PROC	near
		push	bp
		mov	bp,sp
		mov	dx,[bp].aal_length
		shr	dx,4
		inc	dx
		call	AllocMem
		jnc	aal_exit
		xor	ax,ax
aal_exit:	pop	bp
		ret
asm_alloc_mem	ENDP





_asm_dealloc	STRUC
ada_savebp	dw	?
ada_retaddr	dw	?
ada_selector	dw	?
_asm_dealloc	ENDS
;
		PUBLIC	asm_dealloc_mem
asm_dealloc_mem	PROC	near
		push	bp
		mov	bp,sp
		mov	bx,[bp].ada_selector
		call	DeAllocMem
		mov	ax,[bp].ada_selector
		jnc	ada_exit
		xor	ax,ax
ada_exit:	pop	bp
		ret				;AX=0=fail, AX=selector=pass
asm_dealloc_mem	ENDP




MonCode         ENDS

		END
