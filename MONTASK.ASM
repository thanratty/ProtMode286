.286P

;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;;
;;              PAGE            ,132
;;              TITLE           Real/Protected Mode Monitor
;;              SUBTTL          Example Task
;;              Author          Tony Hanratty
;;              Created         23/09/92
;;              Last Changed    23/09/92
;;
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;;
;; To run this particular task we must:
;;
;;      (1)  Allocate memory for its TSS, code and stack segments.
;;      (2)  Fill the TSS with the start context for the task.
;;      (3)  Put the task code into its new code segment
;;      (4)  Do a far call to the TSS to start it.
;;
;; The task is a very simple one which just puts a block of yellow on the
;; screen - it uses no data or stack segments, and the inital value loaded
;; into the flags ensures interrupts are masked off. As there are only
;; three bytes in the code segment these are just patched in, as opposed to
;; being loaded from the disk which is far more complicated. It makes no
;; calls to other privilage levels so their stacks in the TSS dont need
;; to be initialised.
;;
;; =========================================================================


                include         mondesc.inc
                include         moncomn.inc


; ----- External Code Declarations

                extrn   AllocMem:near, pstring:near
                extrn   SetdType:near, SetdSystem:near, SetdDPL:near
                extrn   SetdLimit:near, SetdCode:near

; ----- External Data Declarations

                extrn   screenseg:word

; ----- Local Code Publics

                public  StartTask



; ----- Macro to do a FAR call

CallTask        MACRO
                mov     wptr CallAddress+2, ax
                call    CallAddress
                ENDM




;
; ----- Task creation parameters
;
newSSlen                equ     16              ;task stack length in paras
init_flags              equ     3000h           ;IOPL=3, ints off




MonData         SEGMENT para public 'DATA'

;; ----- Read/Write Locations First...

newTSS          dw      ?                       ;selectors to allocated mem
newCS           dw      ?
newSS           dw      ?

CallAddress     dd      ?                       ;patched by CallTask macro

;; ----- Now Read Only Locations...

TaskErr_mes     db      cr,lf,'Cant create task, '
                db      'GDT full or insufficient memory',cr,lf,null

MonData         ENDS







MonCode         SEGMENT para public 'CODE'
                ASSUME  cs:MonCode, ds:MonData

                public  MonTaskStart
MonTaskStart    LABEL   near                    ;handy for MON.MAP



;;
;; This is the code we'll run as a task (after moving it there!)
;;
TaskCode        PROC    near
                mov     di,si                   ;set destination
                mov     cx,dx                   ;restore count
                rep     stosw
                mov     cx,-1
                loop    $
                loop    $
                loop    $
                loop    $
                loop    $
                loop    $
                xor     ah,2                    ;change colour
                dec     bx
                jne     TaskCode
                iret

TaskCodeLen     equ     $-TaskCode

TaskCode        ENDP




;; =========================================================================
;;
;;                      CREATE AND RUN A SIMPLE TASK
;;
;; =========================================================================
;
StartTask       PROC    near

; ----- 1st allocate a TSS for the task

		mov     dx,(TSSlen+15)/16               ;# paras for TSS
                call    AllocMem                        ;request memory
                jc      st_error                        ;exit if error
                mov     newTSS,ax                       ;new selector in AX
                mov     bx,ax
                mov     al,0                            ;set DPL to 0
                call    SetdDPL
                mov     ax,TSSlen-1                     ;and true limit
                call    SetdLimit

; now allocate a stack for it

                mov     dx,newSSlen
                call    AllocMem
                jc      st_error
                mov     newSS,ax
                mov     bx,ax
                mov     al,3                            ;set DPL to 3
                call    SetdDPL

; now allocate its code segment

                mov     dx,(TaskCodeLen+15)/16          ;in paras
                call    AllocMem
                jc      st_error
                mov     newCS,ax
                mov     bx,ax
                mov     al,3                            ;set DPL to 3
                call    SetdDPL
                jmp     short st_setup

st_error:       mov     si,offset TaskErr_mes
                call    pstring
                stc
                ret


;
; Fill in the TSS with its initial context while its entry in the GDT
; still identifies it as a data segment. The entries we dont initialise
; were zero'd when the memory was allocated.
;

st_setup:       mov     es,newTSS                       ;point ES to TSS

; Set the tasks start CS:IP and flags

                mov     ax,newCS
                or      al,3
                mov     es:[0].tdesc_CS, ax             ;initial CS, CPL=3
                mov     es:[0].tdesc_IP, 0              ;initial IP
                mov     es:[0].tdesc_flags, init_flags  ;and flags

; For the block fill, ES:DI=destination, CX=word count, AX=fill word
; Even though screensegs RPL is 0, its descriptors DPL is 3, so as the task
; runs at CPL 3 it can be loaded without change. (read the bloody book!)

                mov     ax,screenseg
                mov     es:[0].tdesc_ES, ax             ;point ES to screen
                mov     es:[0].tdesc_SI, 160*3          ;keep copy in SI
                mov     es:[0].tdesc_AX, 0edbh          ;yellow square
                mov     es:[0].tdesc_DX, 80*8           ;keep in DX also
                mov     es:[0].tdesc_BX, 8              ;8 flashes

; Load up its newly allocated stack. The SS RPL must be set to the same as
; that for CS, 'cos SS RPL normally holds a copy of the CS CPL/RPL

                mov     ax,newSS
                or      al,3                            ;RPL=3
                mov     es:[0].tdesc_SS, ax
                mov     es:[0].tdesc_SP, (newSSlen*16)-2

        mov     ax,sp                           ;tstst
        sub     ax,10h
        mov     es:[0].tdesc_SS0, ss
        mov     es:[0].tdesc_SS1, sp


; Now set proper segment type etc for the TSS

                mov     bx,newTSS                       ;set to 286 TSS
                call    SetdSystem
                mov     al,dtype_free286TSS
                call    SetdType

; Now fill in the code segment and set its correct type etc

                mov     bx,newCS                        ;point to new codeseg
                mov     es,bx
                mov     cx,TaskCodeLen
                mov     si,offset TaskCode
                xor     di,di
CopyCode:       SegCS                                   ;read from CS:
                lodsb
                stosb
                loop    CopyCode

                call    SetdCode                        ;change type to CODE

; Now call the task

                mov     ax,newTSS               ;get tasks TSS selector
                CallTask                        ;<<<<<<< TASK SWITCH <<<<<<<<

; tstst                mov     wptr CallAddress+2, ax
;                call    CallAddress

                clc
                ret


StartTask       ENDP




MonCode         ENDS

		END
