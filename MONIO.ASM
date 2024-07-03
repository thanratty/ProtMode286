.286P

;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;;
;;              PAGE            ,132
;;              TITLE           Real/Protected Mode Monitor
;;              SUBTTL          General I/O Routines
;;              Author          Tony Hanratty
;;              Created         11/06/92
;;              Changed         02/12/92
;;
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-


                include moncomn.inc             ;load common equates


; ----- Temporary Code Declarations

		public	EN_pcharPRN


; ----- External Code Declarations

                extrn   DSload:near, beep:near

; ----- External Data Declarations

                extrn   kbuffon:word, kbuffoff:word, kbuff:byte
                extrn   FDCmode:byte
		extrn	GlobalDblEnable:byte, dScreen:abs

; ----- Local Code Declarations

                public  Ucase, gkey, gkeye, pstring, cls, HomeCursor
                public  keystat, keypeek
                public  gethexword, gethexbyte, gethexchar
                public  phexword, phexbyte, phexchar
                public  ishexchar, pchar, IsAsciiDigit
                public  pcrlf, pspace, pspace2, pspace3
                public  phexwordPRN, pspacePRN, pspace2PRN, pspace3PRN
                public  phexbytePRN, pcrlfPRN, pcharPRN
		public	pdecimal

                public  enable_printer, disable_printer
                public  _PRNon, _PRNoff
                public  UpdateL25

                public  PageModeOn, PageModeOff

; ----- Local Data Publics

                public  screenseg




; ----- Escape handler table entry

eht		STRUC
eht_cmd		db	?
eht_func	dw	?
eht		ENDS



;; ----- Local 'constants'

_INIT_ROW		equ	5

_PRN_stat_ON            equ     0
_PRN_stat_OFF           equ     1
_PRN_stat_ERROR         equ     2

_L25_pagemode_flag      equ     8
_L25_pagemode_status    equ     9
_L25_diskmode_status    equ     12
_L25_dblstep_status	equ	16
_L25_PRN_status		equ	78



;------------------------------------------------------------------------
;----------------------- START OF LOCAL DATA ----------------------------
;------------------------------------------------------------------------
;
MonData         SEGMENT para public 'DATA'

;; ----- Read/Write Data First.....

CurColour       db      7                       ;including background
UnderCursor     db      7                       ;orig colour under cursor

repeat_char	db	space			;escape sequence repeat char

EscapePend      db      0                       ;1=esc sequence being processed
escape_command	db	0			;current esc sequence command

currow		dw	_INIT_ROW		;cursor row & column
curcol          dw      0			;see scroff too

movecur_X	dw	0			;both addressed as bytes too
movecur_Y	dw	0

PageCounter     db      0                       ;# scrolls since page break
PageMode        db      0                       ;<>0 = Page mode ON

                EVEN
ScreenAddress	LABEL	dword
scroff		dw	_INIT_ROW*160		;keep offset:segment(selector)
screenseg       dw      dScreen                 ;for LES instruction


pcharPRN_vec    dw      EN_pcharPRN             ;printer defaults to on
PRNstatus       db      _PRN_stat_ON


;; ----- Read Only Stuff Now

pen_mess        db      cr,lf,'Printer Enabled',cr,lf,null
pdis_mess       db      cr,lf,'Printer Disabled',cr,lf,null


;; ----- Escape handler commands and functions

eh_table	LABEL	byte
		eht	<_EC_FGCOL_CMD, eh_fgcolour>
		eht	<_EC_BOLD_CMD, eh_bold>
		eht	<_EC_MOVE_ABS, eh_moveabs>
		eht	<_EC_MOVE_REL, eh_moverel>
		eht	<_EC_CLR_EOL, eh_clreol>
		eht	<_EC_RPT_CHAR, eh_reptchar>
eh_table_end	LABEL	byte




MonData         ENDS
;
;------------------------------------------------------------------------
;------------------------- END OF LOCAL DATA ----------------------------
;------------------------------------------------------------------------





; =========================================================================
;
;                       START OF CODE SEGMENT
;
; =========================================================================
;
MonCode         SEGMENT para public 'CODE'
                ASSUME  cs:MonCode, ds:MonData




;===========================================================================
;
; Wait for and return ASCII key in AL from keyboard buffer (no echo).
; Some special keys are trapped in keyboard interrupt handler.
;
;===========================================================================

gkey            proc    near
                push    si

gk_1:           mov     si,kbuffoff
                cmp     si,kbuffon
                je      gk_1

                lodsb
                cmp     si,offset kbuff + kbufflen
                jne     gknotend
                mov     si,offset kbuff
gknotend:       mov     kbuffoff,si

                pop     si
                ret
gkey            endp





;===========================================================================
;               Return ASCII KEY in AL  (with screen echo)
;===========================================================================
;
gkeye           PROC    near
                push    bx
                call    gkey
                mov     bl,al
                call    pchar
                pop     bx
                ret
gkeye           ENDP




;===========================================================================
;               Returns ZF=1 If Keyboard Buffer Empty
;===========================================================================
;
keystat         PROC    near
                push    ds
                push    ax
                call    DSload                          ;load our DS
                mov     ax,kbuffoff                     ;get offload pointer
                cmp     ax,kbuffon                      ;cmp sets Z flag
                pop     ax
                pop     ds                              ;restore callers DS
                ret                                     ;and return Z flag
keystat         ENDP



;
; Return next key in AL without removing it from the keyboard buffer
;
keypeek         PROC    near
                call    keystat                         ;wait for a key
                jz      keypeek

                push    ds
		push	bx
                call    DSload
                mov     bx,kbuffoff                     ;get offload pointer
                mov     al,[bx]                         ;and get the gey
		pop	bx
                pop     ds
                ret
keypeek         ENDP




;===========================================================================
;               Print null terminated string at DS:SI
;===========================================================================
;
pstring         PROC    near
                push    si
                push    bx
                push    ax
pstr0:          lodsb
                or      al,al
                jz      pstrend
                mov     bl,al
                call    pchar                   ;character in BL, saves SI
                jmp     short pstr0
pstrend:        pop     ax
                pop     bx
                pop     si
                ret
pstring         ENDP





;===========================================================================
;                       Clear Screen
;===========================================================================
;
cls             PROC    near
                push    ax
                push    cx
                push    es
                push    di
                push    ds
                call    DSload

                mov     es,screenseg                    ;get selector
                xor     di,di
                mov     ah,CurColour
                mov     UnderCursor,ah                  ;reset last color
                mov     al,space
                mov     cx,80*24                        ;do >>24<< lines
                rep     stosw

                xor     ax,ax
                mov     currow,ax                       ;set (x,y) to (0,0)
                mov     curcol,ax
                mov     scroff,ax                       ;reset offset to 0000
                mov     PageCounter,al                  ;clear page mode count

                mov     bptr es:[1],70h                 ;cursor (blk on white)

                pop     ds
                pop     di
                pop     es
                pop     cx
                pop     ax
                ret
cls             ENDP




;===========================================================================
;               Home Cursor To Top Left (coords = 0,0 )
;===========================================================================
;
HomeCursor      PROC    near
                push    ax
                push    es
                les     di,ScreenAddress                ;segment or selector
                mov     al,UnderCursor
                mov     es:[di+1],al                    ;restore prev colour

                mov     currow,0
                mov     curcol,0
                mov     scroff,0

                mov     al,70h                          ;black on white cursor
                xchg    bptr es:[1],al                  ;cursor on
                mov     UnderCursor,al                  ;save col under cursor

                pop     es
                pop     ax
                ret
HomeCursor      ENDP




;===========================================================================
; Move cursor to coordinates in (movecur_X, movecur_Y)
;
; N.B.	If either new coord is 0xFF then there is no change in that coord.
;	Failing that, if either is > max possible for that axis, it is set
;	to the maximum, ie, X to 79 and Y to 24.
;===========================================================================

SetCursorPosXY	PROC	near
                push    ax
		push	bx
                push    es


;; 1st validate the Y coordinate

		mov	ax,movecur_Y
		cmp	ax,00ffh			;no change in Y?
		je	SCP_chk_X			;Y: go to checl X now
		cmp	ax,24				;permissible coord?
		jbe	SCP_set_Y			;Y: go to save it
		mov	ax,24				;else set to max value
SCP_set_Y:	mov	currow, ax			;and save it


;; Now check the X coordinate in the same way (ie no comments for this bit!)

SCP_chk_X:	mov	ax,movecur_X
		cmp	ax,00ffh
		je	SCP_XY_ok
		cmp	ax,79
		jbe	SCP_set_X
		mov	ax,79
SCP_set_X:	mov	curcol,ax

;; That's the coords checked - now move the cursor

SCP_XY_ok:	les     bx,ScreenAddress                ;segment or selector
                mov     al,UnderCursor
                mov	es:[bx+1],al			;restore prev colour

		call	calcscraddr			;based on new coords
		mov	scroff,bx
                les     bx,ScreenAddress                ;segment or selector
                mov     al,70h                          ;black on white cursor
                xchg	es:[bx+1],al			;restore prev colour
                mov     UnderCursor,al

scp_exit:	pop     es
		pop	bx
                pop     ax
                ret
SetCursorPosXY	ENDP




;===========================================================================
;                       Input Hex Word To BX
;===========================================================================
;
gethexword      PROC    near
                push    ax
                call    gethexbyte              ; returned in bl
                mov     ah,bl
                call    gethexbyte
                mov     bh,ah
                pop     ax
                ret
gethexword      ENDP



;===========================================================================
;                       Input Hex Byte To BL
;===========================================================================
;
gethexbyte      proc    near
                push    ax
                call    gethexchar              ; return 0 - F in BL
                mov     al,bl                   ; shift into top nibble of AL
                shl     al,4
                call    gethexchar
                or      bl,al                   ; or on top
                pop     ax
                ret
gethexbyte      endp




;===========================================================================
;               Get Hex Char, Binary 0-F Returned In BL
;===========================================================================
;
gethexchar      PROC    near
                push    ax

ghc0:           call    gkey
                call    ishexchar               ;ASCII in AH, 0-F in AL
                jc      ghc0                    ;not 0-F, loop
                mov     bl,ah
                call    pchar                   ;else print it
                mov     bl,al                   ;load 0-F return value

                pop     ax
                ret
gethexchar      ENDP


;===========================================================================
;                       Print Space(s) Routines
;===========================================================================
;
pspace          PROC    near
                push    bx
                mov     bl,space
                call    pchar
                pop     bx
                ret
pspace          ENDP
;
pspace2         PROC    near
                call    pspace
                call    pspace
                ret
pspace2         ENDP
;
pspace3         PROC    near
                call    pspace2
                call    pspace
                ret
pspace3         ENDP




;===========================================================================
;                       Print Hex Word In BX
;===========================================================================
;
phexword        PROC    near            ;print hex word in bx
                push    bx
                mov     bl,bh
                call    phexbyte
                pop     bx
                call    phexbyte
                ret
phexword        ENDP


;===========================================================================
;                       Print Hex Byte In BL
;===========================================================================
;
phexbyte        PROC    near            ;print hex byte in bl
                push    bx
                shr     bl,4
                call    phexchar
                pop     bx
                and     bl,0fh
                call    phexchar
                ret
phexbyte        ENDP




;===========================================================================
;                       Print Hex Char In BL
;===========================================================================
;
phexchar        PROC    near            ;print hex char in bl
                or      bl,30h
                cmp     bl,'9'
                jle     phc_2
                add     bl,7
phc_2:          call    pchar
                ret
phexchar        ENDP




;===========================================================================
;                       Print Carriage Return/Line Feed
;===========================================================================
;
pcrlf           PROC    near
                push    bx
                mov     bl,lf
                call    pchar
                mov     bl,cr
                call    pchar
                pop     bx
                ret
pcrlf           ENDP





;===========================================================================
;
;       Scroll Screen Up 1 Line ... **NB** ONLY CALL FROM 'pchar'
;
;===========================================================================
;
scrollup        PROC    near

                push    cx
                push    si
                push    ds

                cmp     PageMode,1              ;DS already = MonData
                jne     s_nopage
                cmp     PageCounter,23
                jne     s_nopage

; Dont page the screen if INTs are off 'cos GKEY wont work as
; the keyboard interrupt is masked

                pushf
                pop     ax
                test    ah,2                    ;test IF flag
                jz      page_noints             ;skip if INTs off

                mov     bptr es:[24*160+_L25_pagemode_status*2],'#'
page_wait:      call    gkey
                cmp     al,space
                jne     page_wait
                mov     bptr es:[24*160+_L25_pagemode_status*2],space
page_noints:    mov     PageCounter,0           ;reset page counter

s_nopage:       mov     ax,es                   ;screen segment OR selector
                mov     ds,ax
                mov     cx,80*23                ;ie not lines 0 or 24
                xor     di,di
                mov     si,80*2
                rep     movsw

                pop     ds
                mov     ah,CurColour
                mov     al,space
                mov     di,23*80*2
                mov     cx,80
                rep     stosw

                inc     PageCounter

                pop     si
                pop     cx
                ret
scrollup        ENDP





;===========================================================================
;		 Return Screen Offset In BX From Current Row/Column
;===========================================================================
;
calcscraddr     PROC    near                    ;return screen offset in DI
                mov     ax,currow
                mov     bx,ax
                shl     ax,2
                add     ax,bx                   ; = 5*row
                shl     ax,5                    ; = 160*row

                mov     bx,curcol               ;get column
                shl     bx,1                    ;*2
                add     bx,ax                   ;add on
                ret
calcscraddr	ENDP





;===========================================================================
; FUNC		Print character in BL to screen
;
; DESC		Special chars like CR, LF and BELL are handled. Escape
;		are flagged and passed to the escape sequence handler below.
;===========================================================================

pchar           PROC    near
                push    ds
                call    DSload

                cmp     EscapePend,0            ;already in escape sequence ?
                je	pc_notesc		;N: skip it
		call	EscapeHandler		;Y: carry on handling it
		pop	ds
		ret

pc_notesc:	cmp     bl,escape               ;is this an esc char?
                jne     pc_normal		;N: just print normally
                mov     EscapePend,1            ;Y: flag escape sequence start
                pop     ds
                ret                             ;and return

; ----- Not an escape sequence.

pc_normal:	cmp     bl,bell
                jne     pnotbell
                call    beep
                pop     ds
                ret

pnotbell:	call	WriteToScreen

                pop     ds
		ret
pchar           ENDP





;===========================================================================
; Called from 'pchar' after the beeps and escape sequences have been
; filtered out and we know it's a char to write to the screen.
;===========================================================================

WriteToScreen	PROC	near
		push    ax
                push    bx				;BL = char to write
                push    di
                push    es

                les     di,dptr scroff                  ;segment or selector
                mov     al,UnderCursor
                mov     es:[di+1],al           		;cursor off

;; Handle carriage return

                cmp     bl,cr
                jne     WTS_chk_lf
                mov     curcol,0
                jmp     short pacdoneCRLF

;; Handle linefeeds

WTS_chk_lf:	cmp     bl,lf
                jne     pac3
                inc     currow
                cmp     currow,24
                jb      pacdoneCRLF
                call    scrollup                ;with ES = screen seg
                dec     currow
                jmp     short pacdoneCRLF

; Handle backspace character

pac3:           cmp     bl,bs                   ;backspace ?
                jne     pac4
                or      di,di                   ;has scroff in it
                jz      pacdone2                ;skip if at top left
                sub     di,2
                sub     curcol,1
                jnc     pacdone
                mov     curcol,0
                dec     currow
                jmp     short pacdone

;; It must be a printing character, so stick it on the screen.

pac4:           mov     bh,CurColour            ;put attribute in BH
                mov     ax,bx                   ;get all in AX
                stosw                           ;then write to screen
                inc     curcol

chkXY:          cmp     curcol,80
                jb      chkXY2
                mov     curcol,0
                inc     currow
chkXY2:         cmp     currow,24
                jb      pacdone
                call    scrollup                ;with ES = screen seg
                dec     currow

pacdoneCRLF:    call    calcscraddr		;returned in BX
		mov	di,bx
pacdone:        mov     scroff,di

pacdone2:       mov     al,70h                  ;load cursor colour
                xchg    es:[di+1],al		;swap with colour there
                mov     UnderCursor,al          ;write it

                pop     es
                pop     di
                pop     bx
                pop     ax
		ret
WriteToScreen	ENDP





;===========================================================================
; EscapeHandler	: I/O Escape Sequences Handler
;
; Called from 'pchar' for each character of an escape sequence.
;===========================================================================

EscapeHandler	PROC	near

;; If this is the command character, save it 1st before calling the handler

                cmp     EscapePend,1            ;is this the command char?
		ja	eh_dispatch		;N: must be a parameter
		mov	escape_command,bl	;Y: save the command char

;; Jump to correct handler for escape command parameters

eh_dispatch:	inc	EscapePend		;bump up char counter

		push	ax
		push	si

		mov	al,escape_command
		mov	si,offset eh_table

eh_p_loop:	cmp	[si].eht_cmd,al
		je	eh_p_found
		add	si,size eht
		cmp	si,offset eh_table_end
		jb	eh_p_loop

		mov	EscapePend,0			;unknown cmd, clear it
		jmp	eh_exit				;off you pop!

eh_p_found:	jmp	[si].eht_func			;AX & SI on stack


;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;;	  Move cursor to (X,Y) escape sequence handler (BL=char)
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-

eh_moveabs:	dec	bl				;all params based on 0
		cmp	EscapePend,2			;this char = cmd char?
		je	eh_ma_exit

		cmp	EscapePend,3			;1st param? (X)
		je	eh_ma_getX
		mov	byte ptr movecur_Y,bl
		call	SetCursorPosXY
		jmp	eh_done

eh_ma_getX:	mov	byte ptr movecur_X,bl
		inc	EscapePend
eh_ma_exit:	jmp	eh_exit


;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;;     Move cursor relative to current pos ( +/- delta X, +/- delta Y)
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-

eh_moverel:	cmp	EscapePend,2			;command char?
		je	eh_mr_exit			;Y: exit

		cmp	EscapePend,4			;is this is 4th char?
		je	eh_mr_getY			;Y: get Y coord
		mov	byte ptr movecur_X,bl
		inc	EscapePend
eh_mr_exit:	jmp	eh_exit

eh_mr_getY:	mov	byte ptr movecur_Y,bl

		mov	bl,byte ptr movecur_Y
		cmp	bl,0ffh				;no move?
		je	eh_mr_doX
		add	bl,byte ptr currow
		cmp	bl,24
		jbe	eh_mr_Yok
		mov	bl,24
eh_mr_Yok:	mov	byte ptr currow,bl

eh_mr_doX:	mov	bl,byte ptr movecur_X
		cmp	bl,0ffh
		je	eh_mr_doit
		add	bl,byte ptr curcol
		cmp	bl,79
		jbe	eh_mr_Xok
		mov	bl,79
eh_mr_Xok:	mov	byte ptr curcol,bl

eh_mr_doit:	call	SetCursorPosXY
		jmp	eh_done


;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;;			Clear to end of line routine
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-

eh_clreol:	push	cx				;AX already saved
		push	di
		push	es

		mov	cx,80
		sub	cx,curcol			;79 - 0
		jcxz	eh_clreol_exit

		mov     ah,CurColour			;put attribute in AH
		mov	al,space
		les	di,ScreenAddress
		rep	stosw

eh_clreol_exit:	pop	es
		pop	di
		pop	cx
		jmp	short eh_done


;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;;			Control text bold attribute
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-

eh_bold:	cmp	EscapePend, 2			;cmd char ?
		je	eh_exit				;Y: next char is param

		and     CurColour,0f7h			;mask bold off
		cmp	bl,_OFF				;bold off cmd?
		je	eh_bold2			;Y: done
		or      CurColour,8			;N: set bold flag
eh_bold2:	jmp	short eh_done


;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;;			Control text foreground colour
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-

eh_fgcolour:	cmp	EscapePend, 2			;is this the cmd char ?
		je	eh_exit				;Y: exit

		cmp     bl,_fg_MIN_COL
                jb      eh_done
                cmp     bl,_fg_MAX_COL
                ja      eh_done

                push    es
                and     CurColour,0f8h          ;strip old foreground colour
                or      CurColour,bl            ;OR on new colour
                les     si,dptr scroff
                mov     bptr es:[si+1],70h      ;cursor on
                pop     es
		jmp	short eh_done


;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;;			Print repeated character
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-

eh_reptchar:	cmp	EscapePend,2			;just command char?
		je	eh_exit				;Y: exit
		cmp	EscapePend,3			;char to repeat?
		jne	eh_count			;nope, must be count
		mov	repeat_char,bl			;must be repeat count
		jmp	short eh_exit

eh_count:	push	ax
		push	cx

		xor	cx,cx
		mov	cl,bl				;now CX = count
		mov	bl,repeat_char

eh_loop:	push	bx
		call	WriteToScreen
		pop	bx
		loop	eh_loop

		pop	cx
		pop	ax


;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;;			Exit points for escape handler
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-

eh_done:	mov	EscapePend,0			;handling completed

eh_exit:	pop	si
		pop	ax
                ret

EscapeHandler	ENDP








;===========================================================================
; Q. Is ASCII Char In AL A Valid Hex Character ?
;
; A.  Input     AL = ASCII char
;     Output    C  = 0 No Error
;                       AL=Binary 0-F
;                       AH=ASCII '0'-'F', uppercased
;               C  = 1 Error, not a hex char
;===========================================================================
;
ishexchar       PROC    near
                call    Ucase                   ;uppercase 'a'-'z'
                mov     ah,al
                sub     al,'0'
                cmp     al,9
                jbe     ihc_ok                  ;is a number 0-9
                sub     al,7
                cmp     al,0fh
                ja      ihc_nok
                cmp     al,0ah
                jb      ihc_nok

ihc_ok:         clc                             ;clear carry flag
                ret                             ;and return 0-F in AL

ihc_nok:        stc
                ret
ishexchar       ENDP





;===========================================================================
; Q. Is ASCII Char In AL A Valid Numeric Character ?
;
; A.  Input     AL = ASCII char
;     Output    C  = 0 No Error
;                       AL=Binary 0-9
;                       AH=ASCII '0'-'9'
;               C  = 1 Error, not a hex char
;===========================================================================

IsAsciiDigit	PROC	near
                mov     ah,al
                cmp     al,'9'
                ja	iac_nok                  ;is a number 0-9
                cmp     al,'0'
                jb      iac_nok
		sub	al,'0'
                ret                             ; 0-F in AL and CF=0

iac_nok:        stc
                ret
IsAsciiDigit	ENDP




;===========================================================================
;       Convert char in AL to uppercase if it's lowercase
;===========================================================================
;
Ucase           PROC    near
                cmp     al,'a'
                jb      UCexit
                cmp     al,'z'
                ja      UCexit
                and     al,uppermask
UCexit:         ret
Ucase           ENDP






pspacePRN       PROC    near
                push    bx
                mov     bl,20h
                call    pcharPRN
                pop     bx
                ret
pspacePRN       ENDP


pspace2PRN      PROC    near
                call    pspacePRN
                call    pspacePRN
                ret
pspace2PRN      ENDP


pspace3PRN      PROC    near
                call    pspace2PRN
                call    pspacePRN
                ret
pspace3PRN      ENDP


phexwordPRN     PROC    near            ;print hex word in bx
                push    bx
                mov     bl,bh
                call    phexbytePRN
                pop     bx
                call    phexbytePRN
                ret
phexwordPRN     ENDP


phexbytePRN     PROC    near            ;print hex byte in bl
                push    cx
                push    bx
                mov     cl,4
                shr     bl,cl
                call    phexcharPRN
                pop     bx
                and     bl,0fh
                call    phexcharPRN
                pop     cx
                ret
phexbytePRN     ENDP




phexcharPRN     PROC    near            ;print hex char in bl
                push    ax
                or      bl,30h
                cmp     bl,'9'
                jle     phcP_2
                add     bl,7
phcP_2:         call    pcharPRN
                pop     ax
                ret
phexcharPRN     ENDP



pcharPRN        PROC    near
                push    ds
                call    DSload
                call    [pcharPRN_vec]
                pop     ds
                ret
pcharPRN        ENDP




pcrlfPRN        PROC    near
                push    bx
                mov     bl,lf
                call    pcharPRN
                mov     bl,cr
                call    pcharPRN
                pop     bx
                ret
pcrlfPRN        ENDP





StrobePRN       PROC    near
                mov     dx,37ah
                in      al,dx
                mov     ah,al                   ;save orig in AH
                or      al,1
                out     dx,al                   ;set strobe line

                dec     dx                      ;status reg
sPRN_1:         in      al,dx
                test    al,40h
                jnz     sPRN_1                  ;wait for acknowledge

                inc     dx                      ;control reg
                mov     al,ah
                out     dx,al                   ;reset strobe line
                ret
StrobePRN       ENDP

;
; Returns C=1 if printer error (DS setup by pcharPRN)
;
WaitPRN         PROC    near                    ;wait for printer not busy
                push    cx
                mov     cx,-1

                mov     dx,0379h
_wp:            in      al,dx
                and     al,11111000b
                cmp     al,11011000b
                je      _wp_exit
                loop    _wp

                mov     PRNstatus, _PRN_stat_ERROR
                mov     pcharPRN_vec, offset DIS_pcharPRN
                stc

_wp_exit:       pop     cx
                ret
WaitPRN         ENDP




;
; This procedure is vectored through pcharPRN_vec so printer output can
; be enabled and disabled from the menu using the routines below
;
EN_pcharPRN     PROC    near                    ;send char in BL to printer
                push    dx
                push    ax
                call    WaitPRN
                jc      EN_exit                 ;exit if printer error
                mov     dx,378h
                mov     al,bl
                out     dx,al
                call    StrobePRN
EN_exit:        pop     ax
                pop     dx
DIS_pcharPRN:   ret
EN_pcharPRN     ENDP



enable_printer  PROC    near
                push    ds
                call    DSload
                call    _PRNon
                mov     si,offset pen_mess
                call    pstring
                pop     ds
                ret
enable_printer  ENDP


disable_printer PROC    near
                push    ds
                call    DSload
                call    _PRNoff
                mov     si,offset pdis_mess
                call    pstring
                pop     ds
                ret
disable_printer ENDP



;
; N.B. For _PRNon/off DS must be set to MonData
;
_PRNon          PROC    near
                mov     pcharPRN_vec,offset EN_pcharPRN
                mov     PRNstatus,_PRN_stat_ON
                call    UpdateL25
                ret
_PRNon          ENDP


_PRNoff         PROC    near
                mov     pcharPRN_vec,offset DIS_pcharPRN
                mov     PRNstatus,_PRN_stat_OFF
                call    UpdateL25
                ret
_PRNoff         ENDP







;
; Routines to control display of status line at bottom of screen
;
UpdateL25       PROC    near
                push    ax
                push    cx
                push    si
                push    di
                push    ds
                push    es
                call    DSload

; 1st blank the line

                mov     es,screenseg
                mov     di,24*160               ;mem start of L25
                mov     ax,7020h
                mov     cx,80
                rep     stosw

; now display printer status

                mov     di,24*160+_L25_PRN_status*2
                mov     ax,7000h+'P'
                cmp     PRNstatus,_PRN_stat_ON
                je      pl25_prn
                mov     al,'p'
                cmp     PRNstatus,_PRN_stat_OFF
                je      pl25_prn
                or      ah,80h
                cmp     PRNstatus,_PRN_stat_ERROR
                jne     pl25_pmode
pl25_prn:       stosw


; display page mode on or off

pl25_pmode:     cmp     PageMode,1
                jne     pl25_disk
                mov     bptr es:[24*160+_L25_pagemode_flag*2],'P'


; ----- display disk recording mode MFM or FM

pl25_disk:      mov     al,'M'				;load 'M' for 'MFM'
                cmp     FDCmode,1                       ;MFM mode ?
                je      pl25_disk2                      ;yes - jump
                mov     al,'F'                          ;else load 'F' for 'FM'
pl25_disk2:     mov     bptr es:[24*160+_L25_diskmode_status*2],al


; ----- display globale double step enabled state

pl25_dblstate:	mov	al,'D'
		cmp	GlobalDblEnable, 1		;doubl step on?
		je	pl25_dbl2
		mov	al,'d'
pl25_dbl2:	mov	bptr es:[(24*160)+(_L25_dblstep_status*2)],al

		pop     es
                pop     ds
                pop     di
                pop     si
                pop     cx
                pop     ax
                ret
UpdateL25       ENDP




PageModeOn      PROC    near
                mov     PageMode,1
                mov     PageCounter,0
                mov     es,screenseg
                ret
PageModeOn      ENDP


PageModeOff     PROC    near
                mov     PageMode,0
                mov     es,screenseg
                mov     bptr es:[24*160+_L25_pagemode_flag*2],space
                mov     bptr es:[24*160+_L25_pagemode_status*2],space
                ret
PageModeOff     ENDP


;
; Print Value in BX as decimal (right justified in a 5 char field)
;
pdecimal	PROC	near
		push	dx
		push	cx
		push	ax

		cmp	bx,9
		ja	pd99
		call	pspace2
		call	pspace2
		jmp	short decout9

pd99:		cmp	bx,99
		ja	pd999
		call	pspace2
		call	pspace
		jmp	short decout99

pd999:		cmp	bx,999
		ja	pd9999
		call	pspace2
		jmp	short decout999

pd9999:		cmp	bx,9999
		ja	decout99999	;fall through now to decout99999
		call	pspace
		jmp	short decout9999


decout99999:	mov	cx,10000	; output decimal in BX <=99999
		call	dodiv
decout9999:	mov	cx,1000		; output decimal in BX <=9999
		call	dodiv
decout999:	mov	cx,100		; output decimal in BX <=999
		call	dodiv
decout99:	mov	cx,10		; output decimal in BX <=99
		call	dodiv
decout9:	call	phexchar	; output decimal in BX <=9

		pop	ax
		pop	cx		; restore regs
		pop	dx
		ret			; return to caller

dodiv:		xor	dx,dx
		mov	ax,bx
		div	cx		; al = int, dx = rem
		push	dx		; save remainder
		mov	bl,al
		call	phexchar
		pop	bx		; remainder = new quotient
		ret
pdecimal	ENDP



MonCode         ENDS

		END
