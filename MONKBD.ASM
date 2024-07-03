.286P

;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;;
;;              PAGE            ,132
;;              TITLE           Real/Protected Mode Monitor
;;              SUBTTL          8042 Keyboard Controller Routines
;;              Author          Tony Hanratty
;;              Created         12/06/92
;;              Changed         12/06/92
;;
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-

                        include moncomn.inc             ;general equates etc..



; ----- External code definitions

        extrn   getcommand:near, pstring:near, menuexit:near, showhelp:near
        extrn   gethexbyte:near, pcrlf:near, NewMenu:near

; ----- Local code definitions

        public  A20_Enable, KbdSys



; Local menu commands

_sendbyte_cmd           equ     'S','B'
_kbdDF_cmd              equ     'D','F'
_kbdDD_cmd              equ     'D','D'
_showhelp_cmd           equ     'H','E'
_menuexit_cmd           equ     'Q','U'





;; =====================================================================
;;                      LOCAL DATA SEGMENT
;; =====================================================================

MonData         SEGMENT para public 'DATA'

;; ----- Read Write Stuff First...

;; ----- Now Read Only Locaations...

KbdMenu         LABEL   byte
                CmdTabEntry             <_sendbyte_cmd, SendByte>
                CmdTabEntry             <_kbdDF_cmd,  kbdDF>
                CmdTabEntry             <_kbdDD_cmd,  kbdDD>
                CmdTabEntry             <_showhelp_cmd, showhelp>
                CmdTabEntry             <_menuexit_cmd, menuexit>
                db      0               ;end of menu


KbdHelp         LABEL   byte
        db      lf,lf,cr,'KEYBOARD CONTROLLER COMMANDS...'
        db      cr,lf,' '
        db      _sendbyte_cmd,  ' Send Byte To Keyboard         '
        db      _kbdDD_cmd,     ' Send DD To Keyboard (A20 off)'
        db      cr,lf,' '
        db      _kbdDF_cmd,     ' Send DF To Keyboard (A20 on)  '
        db      _showhelp_cmd,  ' Command Help'
        db      cr,lf,' '
        db      _menuexit_cmd,  ' Quit'
        db      cr,lf,lf,null


SendFailMes             db      cr,lf,'Keyboard controller write error',cr,lf,null
ByteMes                 db      cr,lf,'Byte value to send : ',null

A20on_mess		db	'A20 enabled',cr,lf,null
A20off_mess		db	'A20 disabled',cr,lf,null

MonData         ENDS
;
;
;------------------------------------------------------------------------
;--------------------------- END OF KEYBOARD DATA -----------------------
;------------------------------------------------------------------------







; =========================================================================
;
;                       START OF CODE SEGMENT
;
; =========================================================================
;
MonCode         SEGMENT para public 'CODE'
                ASSUME  cs:MonCode, ds:MonData



; =====================================================================
;                       Main menu handler
; =====================================================================
;
KbdSys          PROC    near
                mov     di,offset KbdHelp               ;point to help text
                mov     si,offset KbdMenu               ;point to command table
                call    NewMenu                         ;print menu if enabled
                call    getcommand                      ;'do' the menu
                ret                                     ;back to caller
KbdSys          ENDP





; =====================================================================
;
; Send byte in AH To 8042 keyboard controller (used for A20 gate cotrol)
;
; Call with AH = DF unmask A20
;           AH = DD mask A20
; Returns    C = 0  sucessful
;            C = 1  function failed
; =====================================================================
;
ksend           PROC    near
                pushf
                cli                             ;all ints off
                call    Kwait                   ;wait for I/P buffer empty
                jnz     ks_error                ;exit if timed out
                mov     al,0d1h                 ;D1 = write O/P port command
                out     64h,al                  ;send the command
                call    Kwait                   ;wait for it to go
                jnz     ks_error                ;timed out - exit
                mov     al,ah                   ;get byte to send
                out     60h,al                  ;send it
                call    Kwait                   ;wait for it to go
                jnz     ks_error                ;exit if timed out
                mov     al,0ffh                 ;send FF
                out     64h,al
                call    Kwait                   ;wait for it to go
                jnz     ks_error
                popf                            ;restore IF
                clc                             ;flag no errorr
                ret                             ;return

ks_error:       popf                            ;restore IF
                stc                             ;flag error
                ret                             ;return
ksend           ENDP


; Wait for 8042 I/P buffer to empty

Kwait           PROC    near
                xor     cx,cx                   ;int timeout counter
kw1:            in      al,64h                  ;read status port
                and     al,2                    ;test I/P buffer status
                loopnz  kw1                     ;1 = full, loop
                ret                             ;return
Kwait           ENDP



; =====================================================================
;       Send DD or DF to 8042 output port for A20 gate control
; =====================================================================
;
kbdDD		PROC	near
		push	si
		mov     ah,0ddh                 ;mask off A20
		call    ksend                   ;send it, C=0 = success
		mov	si,offset A20off_mess
		jnc	kbdDD_done
		mov	si,offset SendFailMes
kbdDD_done:	call	pstring
		pop	si
                ret                             ;return CF
kbdDD		ENDP


kbdDF		PROC	near
		push	si
		mov     ah,0dfh                 ;propogate A20
		call    ksend                   ;send it, C=0 = success
		mov	si,offset A20on_mess
		jnc	kbdDF_done
		mov	si,offset SendFailMes
kbdDF_done:	call	pstring
		pop	si
                ret                             ;return CF
kbdDF		ENDP


A20_Enable	PROC	near			;public for MONCODE startup
		mov     ah,0dfh                 ;propogate A20
		call    ksend                   ;send it, C=0 = success
		ret
A20_Enable	ENDP


;; =====================================================================
;; Send a byte to the 8042 keyboard controller
;; =====================================================================

SendByte        PROC    near

                mov     si,offset ByteMes       ;ask for byte to send
                call    pstring
                call    gethexbyte              ;get it
                and     bl,7                    ;clear top bit
                call    pcrlf

                pushf
                cli                             ;all ints off
                call    Kwait                   ;wait for I/P buffer empty
                jnz     l_error                 ;exit if timed out
                mov     al,0edh                 ;D1 = write O/P port command
                out     64h,al                  ;send it
                call    Kwait                   ;wait for it to go
                jnz     l_error                 ;timed out - exit
                mov     al,bl                   ;get byte to send
                out     60h,al                  ;send it
                call    Kwait                   ;wait for it to go
                jnz     l_error                 ;exit if timed out
                mov     al,0ffh                 ;send FF
                out     64h,al
                call    Kwait                   ;wait for it to go
                jnz     l_error
                popf                            ;restore IF
                ret                             ;return

l_error:        popf
                mov     si,offset SendFailMes
                call    pstring
                ret
SendByte        ENDP



                PUBLIC  KbdCodeEnd
KbdCodeEnd      LABEL   byte

MonCode         ENDS

		END
