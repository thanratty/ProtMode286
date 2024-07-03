.286P

;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;;
;;              PAGE            ,132
;;              TITLE           Protected Mode Monitor
;;              SUBTTL          Single Step Debug Routines
;;              Author          Tony Hanratty
;;              Created         12/04/91
;;              Changed         01/03/93
;;
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-

                include         moncomn.inc


; ----- Local Code Publics

                public  SetTrapVecs

; ----- External Code Declarations

                extrn   phexwordPRN:near, pcrlfPRN:near
                extrn   pspacePRN:near, pspace2PRN:near, pspace3PRN:near
                extrn   pcharPRN:near, DSload:near

; ----- External Data Declarations

                extrn   IDTbase:byte


;
; Define stack frame for single step interrupt
;
TrapStak        STRUC
reg_sp		dw	?
reg_ss		dw	?
reg_bp          dw      ?
reg_di          dw      ?
reg_si          dw      ?
reg_es          dw      ?
reg_ds          dw      ?
reg_dx          dw      ?
reg_cx          dw      ?
reg_bx          dw      ?
reg_ax          dw      ?
arg_retoff      dw      ?
arg_retseg      dw      ?
arg_flags       dw      ?
TrapStak        ENDS



pushall         MACRO
                IRP     x,<ax,bx,cx,dx,ds,es,si,di,bp,ss,sp>
                push    x
                ENDM
                ENDM


popall          MACRO
                IRP     x,<sp,ss,bp,di,si,es,ds,dx,cx,bx,ax>
                pop     x
                ENDM
                ENDM


MonData         SEGMENT para public 'DATA'
MonData         ENDS






MonCode         SEGMENT para public 'CODE'
                ASSUME  cs:MonCode, ds:MonData

SetTrapVecs     PROC    near
                push    ds
                call    DSload

		mov     wptr IDTbase+8, offset _traproutine
                mov     wptr IDTbase+8*TrapsOnInt, offset _trapson
                mov     wptr IDTbase+8*TrapsOffInt, offset _trapsoff
                pop     ds
                ret
SetTrapVecs     ENDP




;
; Interrupt handler to turn traps on. Trapping starts the line after
; the INT command to this handler
;
_trapson        PROC    near
                pushall
                mov     bp,sp
                call    SetTrapVecs
                or      word ptr [bp].arg_flags,0100h   ; set trap flag
                popall
                iret                                    ; traps on *** NOW ***
_trapson        ENDP



;
; Disable single step traps
;
_trapsoff       PROC    near
                pushall
                mov     bp,sp
                and     word ptr [bp].arg_flags,0feffh  ; clear trap flag
                popall
                iret
_trapsoff       ENDP



;
; Single Step Trap Handler. Just prints all reg on the printer
;
_traproutine    PROC    near
                pushall
                mov     bp,sp

                mov     bl,bell
                call    pcharPRN

                mov     bx,[bp].arg_flags
                call    phexwordPRN
                call    pspacePRN
                mov     bx,[bp].arg_retseg
                call    phexwordPRN
                call    pspacePRN
                mov     bx,[bp].arg_retoff
                call    phexwordPRN
		call	pspace2PRN

                mov     bx,[bp].reg_ax
                call    phexwordPRN
                call    pspacePRN
                mov     bx,[bp].reg_bx
                call    phexwordPRN
                call    pspacePRN
                mov     bx,[bp].reg_cx
                call    phexwordPRN
                call    pspacePRN
                mov     bx,[bp].reg_dx
                call    phexwordPRN
                call    pspace2PRN

                mov     bx,[bp].reg_ds
                call    phexwordPRN
                call    pspacePRN
                mov     bx,[bp].reg_si
                call    phexwordPRN
                call    pspace2PRN

                mov     bx,[bp].reg_es
                call    phexwordPRN
                call    pspacePRN
                mov     bx,[bp].reg_di
                call    phexwordPRN
                call    pspace2PRN

                mov     bx,[bp].reg_ss
                call    phexwordPRN
                call    pspacePRN
                mov     bx,[bp].reg_sp
                call    phexwordPRN
                call    pspace2PRN

                mov     bx,[bp].reg_bp
                call    phexwordPRN

                call    pcrlfPRN

_tr_exit:       or      word ptr [bp].arg_flags,0100h   ;set trap flag again
                popall
                iret
_traproutine    ENDP



MonCode         ENDS

		END

