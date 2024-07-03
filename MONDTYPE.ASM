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


	public		FindDiskType

	extrn		SeekStatus:byte, CurDrive:byte, param_table:byte
	extrn		FDCmode:byte, FDC_ReadID:byte
	extrn		AutoParamsEnable:byte


	extrn		send_fdc:near, motor_on:near, wait_int:near
	extrn		SetFM:near, SetMFM:near, results:near
	extrn		pstring:near, EmptyFDC:near





MonData		SEGMENT	para public 'DATA'
TypeFound_mess	db	cr,lf,'Type Found!',cr,lf,bell,eot
MonData		ENDS



MonCode		SEGMENT	para public 'CODE'
		ASSUME	cs:MonCode, ds:MonData


FindDiskType	PROC	near
		call	SetMFM
		mov	AutoParamsEnable,0		;disable auto load


ModeLoop:
		mov	param_table [DT_BYT_SEC],3	;1K bytes/sec max
SecSizeLoop:
		mov	param_table [DT_DATA_RATE],2	;500 b.p.s.
RateLoop:
		mov	ah,0
		mov	dl,0
		int	FloppyInt

		and	SeekStatus, NOT DISK_INT_FLAG	;clear int flag
		call	EmptyFDC			;empty out FDC
		and	SeekStatus, NOT DISK_INT_FLAG	;and again!

		mov	ah,CurDrive			;which drive
		call	motor_on			;turn its motor on

		mov	al,FDC_ReadID			;send read ID command
		call	send_fdc
		jc	rid_error

		mov	al,CurDrive			;ID on drive (head 0)
		call	send_fdc			;send to FDC
		jc	rid_error

		call	wait_int
		jc	rid_error

		call	results				;& read results
		jnc	type_found


rid_error:	dec	param_table [DT_DATA_RATE]
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


FindDiskType	ENDP



MonCode		ENDS

		END
