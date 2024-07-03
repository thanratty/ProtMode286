.286P

;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;;
;;              PAGE            ,132
;;              TITLE           Real/Protected Mode Monitor
;;              SUBTTL          Interrupt, Exception & Trap Handlers
;;              Author          Tony Hanratty
;;              Created         18/09/92
;;              Changed         22/10/92
;;
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-


                include         moncomn.inc
                include         mondesc.inc
                include         moncode.inc     ;just for stacktop!



; Specially trapped keyboard scan codes in H/W interrupt handler

coldboot_scan   equ     1		;coldboot = escape key
regtrap_scan    equ     29h		;` = print CS:IP trap key
pause_scan      equ     46h		;scroll lock = pause key



; ----- External Code Declarations

                extrn   DSload:near, motor_off:near
                extrn   phexword:near, phexbyte:near, pstring:near
                extrn   pspace:near, pcrlf:near, pchar:near
                extrn   phexwordPRN:near, phexbytePRN:near, pcrlfPRN:near
                extrn   pspacePRN:near, pspace2PRN:near
                extrn   beep:near, coldboot:near, fdisk_io:near

; ----- External Data Declarations

                extrn   dDS:abs, dSS:abs, dCS:abs
                extrn   SeekStatus:byte, MotorCount:byte

; ----- Local Data Publics

                public  kbuffon, kbuffoff, kbuff
                public  IDTlen, IDTbase

; ----- Local Code Publics

                public  IHR_0, IHR_6
                public  IHR_FloppyInt, IHR_TimerInt, IHR_KybdInt





;; ----- Interrupt Macro
;;
;; N.B. Processor interrupts 8, 10-14, and 17 generate an error code and
;; push it on the stack after flags,seg,offset; other interrupts dont!
;;
DefIntHandler   MACRO   inum
                LOCAL   IH_DSload, ErCodeYes
                push    ax                              ;have to use stack
                push    ds
                mov     ax,dDS
	        mov     ds,ax                           ;load up DS
                pop     int_DS                          ;save AX,DS
                pop     int_AX

		ErCodeYes = 0
                IRP     x,<8,10,11,12,13,14,17>
                ifidn   <x>,<inum>
                        ErCodeYes = 1
                endif
                ENDM
                if      ErCodeYes eq 1
                        pop     errorcode
                endif

                mov     failnum,&inum
                jmp     IH_common

                ENDM





MonData         SEGMENT para public 'DATA'

;; ----- Read/Write Stuff First...

int_flags       dw      ?
int_segment     dw      ?
int_offset      dw      ?

int_AX          dw      ?
int_BX          dw      ?
int_CX          dw      ?
int_DX          dw      ?
int_DS          dw      ?
int_SI          dw      ?
int_ES          dw      ?
int_DI          dw      ?
int_SS          dw      ?
int_SP          dw      ?
int_BP          dw      ?

failnum         db      ?                       ;current int #
errorcode       dw      ?                       ;only with some interrupts

kbuffon         dw      kbuff                   ;keyboard buffer onload ptr
kbuffoff        dw      kbuff                   ;and offload ptr
kbuff           db      kbufflen dup (0)        ;keyboard buffer itself
kbufflast       equ     $-1                     ;last byte in buffer

ignext9         db      0                       ;ignore next INT 9 flag
IgnoredKey      db      0ffh


;; ----- Now Read Only Locations...


;
; Scan Code Translation Table For Keyboard HARDWARE Interrupt (N.B. NOT INT 9!)
;
KeyTable        LABEL   byte
                db      0,escape,'123456'               ;scan 00-07 (0x00-0x07)
                db      '7890-=',8,tab                  ;scan 08-15 (0x08-0x0F)
                db      'qwertyui'                      ;scan 16-23 (0x10-0x17)
                db      'op[]',cr,0,'as'                ;scan 24-31 (0x18-0x1F)
                db      'dfghjkl;'                      ;scan 32-39 (0x20-0x27)
                db      39,39,0,'\zxcv'                 ;scan 40-47 (0x28-0x2F)
                db      'bnm,./',0,'*'                  ;scan 48-55 (0x30-0x37)
                db      0,32,0,0,0,0,0,0                ;scan 56-63 (0x38-0x3F)
                db      0,0,0,0,0,0,0,'7'               ;scan 64-71 (0x40-0x47)
                db      '89-456+1'			;scan 72-79 (0x48-0x4F)
                db      '230.',0,0,0,0                  ;scan 80-87 (0x50-0x57)
                db      0                               ;scan 88

DivZeroMess     db      cr,lf,'Divide by zero trap CS:IP = ',null


;
; -------------- Start of INTERRUPT DESCRIPTOR TABLE ---------------
;
                EVEN
IDTbase         LABEL           byte

; Ints 0-31 decimal (0-1F hex) are INTEL reserved

        IDTdesc         <IHR_0,  dCS, 0, 10000110b, 0>  ;div by zero
        IDTdesc         <IHR_1,  dCS, 0, 10000110b, 0>  ;single step
        IDTdesc         <IHR_2,  dCS, 0, 10000110b, 0>  ;NMI
        IDTdesc         <IHR_3,  dCS, 0, 10000110b, 0>  ;breakpoint
        IDTdesc         <IHR_4,  dCS, 0, 10000110b, 0>  ;overflow
        IDTdesc         <IHR_5,  dCS, 0, 10000110b, 0>  ;bound check
        IDTdesc         <IHR_6,  dCS, 0, 10000110b, 0>  ;undefined opcode
        IDTdesc         <IHR_7,  dCS, 0, 10000110b, 0>  ;287 not available
        IDTdesc         <IHR_8,  dCS, 0, 10000110b, 0>  ;double fault
        IDTdesc         <IHR_9,  dCS, 0, 10000110b, 0>  ;287 seg overrun
        IDTdesc         <IHR_10, dCS, 0, 10000110b, 0>  ;invalid TSS
        IDTdesc         <IHR_11, dCS, 0, 10000110b, 0>  ;seg not present
        IDTdesc         <IHR_12, dCS, 0, 10000110b, 0>  ;stack exception
        IDTdesc         <IHR_13, dCS, 0, 10000110b, 0>  ;general prot fail
        IDTdesc         <IHR_14, dCS, 0, 10000110b, 0>  ;page fault
        IDTdesc         <IHR_15, dCS, 0, 10000110b, 0>
        IDTdesc         <IHR_16, dCS, 0, 10000110b, 0>  ;287 error
        IDTdesc         <IHR_17, dCS, 0, 10000110b, 0>  ;Alignment Check (486)
        IDTdesc         <IHR_18, dCS, 0, 10000110b, 0>
        IDTdesc         <IHR_19, dCS, 0, 10000110b, 0>
        IDTdesc         <IHR_20, dCS, 0, 10000110b, 0>
        IDTdesc         <IHR_21, dCS, 0, 10000110b, 0>
        IDTdesc         <IHR_22, dCS, 0, 10000110b, 0>
        IDTdesc         <IHR_23, dCS, 0, 10000110b, 0>
        IDTdesc         <IHR_24, dCS, 0, 10000110b, 0>
        IDTdesc         <IHR_25, dCS, 0, 10000110b, 0>
        IDTdesc         <IHR_26, dCS, 0, 10000110b, 0>
        IDTdesc         <IHR_27, dCS, 0, 10000110b, 0>
        IDTdesc         <IHR_28, dCS, 0, 10000110b, 0>
        IDTdesc         <IHR_29, dCS, 0, 10000110b, 0>
        IDTdesc         <IHR_30, dCS, 0, 10000110b, 0>
        IDTdesc         <IHR_31, dCS, 0, 10000110b, 0>

; ----- We'll use INTs 20h to 27h for IRQ 0-7

        IDTdesc         <IHR_TimerInt,  dCS, 0, 10000110b, 0>
        IDTdesc         <IHR_KybdInt,   dCS, 0, 10000110b, 0>
        IDTdesc         <IHR_hw_dummy,  dCS, 0, 10000110b, 0>
        IDTdesc         <IHR_hw_dummy,  dCS, 0, 10000110b, 0>
        IDTdesc         <IHR_hw_dummy,  dCS, 0, 10000110b, 0>
        IDTdesc         <IHR_hw_dummy,  dCS, 0, 10000110b, 0>
        IDTdesc         <IHR_FloppyInt, dCS, 0, 10000110b, 0>
        IDTdesc         <IHR_hw_dummy,  dCS, 0, 10000110b, 0>

; ----- From 28h upward are software usable, so for now setup four

        IDTdesc         <fdisk_io,	dCS, 0, 10000110b, 0>
        IDTdesc         <IHR_hw_dummy,  dCS, 0, 10000110b, 0>
        IDTdesc         <IHR_hw_dummy,  dCS, 0, 10000110b, 0>
        IDTdesc         <IHR_hw_dummy,  dCS, 0, 10000110b, 0>

IDTlen          equ     $ - IDTbase

;
; --------------- End of INTERRUPT DESCRIPTOR TABLE ----------------
;


MonData         ENDS







MonCode         SEGMENT para public 'CODE'
                ASSUME  cs:MonCode, ds:MonData


; ====================================================================
;
;               INTERRUPT HANDLERS (Real & Protected Mode)
;
; ================================================================



; Exception #8=Double Fault, #12=Stack Fault. Because the exception handlers
; arent separate tasks and we cant do a full context switch, just try a
; cold boot - you may be lucky.

IHR_8:
IHR_12:         jmp     coldboot



; If we accidentally unmask any hardware interrupts, this just acknowledges
; them to the 8259 interrupt controller and exits.

IHR_hw_dummy:   push    ax
                mov     al,20h
                out     20h,al
                pop     ax
                iret




; Common routine to all exception handlers except 8 and 12.
; DS is set to MonData now. AX, DS & errorcode save by DefIntHandler macro

IH_common:      mov     int_BX,bx                       ;save all users regs
                mov     int_CX,cx
                mov     int_DX,dx
                mov     int_SI,si
                mov     int_ES,es
                mov     int_DI,di
                mov     int_SS,ss
                mov     int_SP,sp
                mov     int_BP,bp

                pop     int_offset                      ;interrupt IP
                pop     int_segment                     ;and CS
                pop     int_flags                       ;and flags

                mov     sp,STACK_TOP                    ;reset the stack

;; Now send the whole lot to the printer, in this order...
;; Flags, CS,IP,   AX,BX,CX,DX,   DS,SI   ES,DI   SS,SP,   intnum, errorcode

                mov     bx,int_flags                    ;Flags
                call    phexwordPRN
                call    pspacePRN
                mov     bx,int_segment                  ;S
                call    phexwordPRN
                call    pspacePRN
                mov     bx,int_offset                   ;O
                call    phexwordPRN
                call    pspace2PRN

                mov     bx,int_AX                       ;AX
                call    phexwordPRN
                call    pspacePRN
                mov     bx,int_BX                       ;BX
                call    phexwordPRN
                call    pspacePRN
                mov     bx,int_CX                       ;CX
                call    phexwordPRN
                call    pspacePRN
                mov     bx,int_DX                       ;DX
                call    phexwordPRN
                call    pspace2PRN

                mov     bx,int_DS                       ;DS
                call    phexwordPRN
                call    pspacePRN
                mov     bx,int_SI                       ;SI
                call    phexwordPRN
                call    pspace2PRN

                mov     bx,int_ES                       ;ES
                call    phexwordPRN
                call    pspacePRN
                mov     bx,int_DI                       ;DI
                call    phexwordPRN
                call    pspace2PRN

                mov     bx,int_SS                       ;SS
                call    phexwordPRN
                call    pspacePRN
                mov     bx,int_SP                       ;SP
                call    phexwordPRN
                call    pspace2PRN

                mov     bx,int_BP                       ;BP
                call    phexwordPRN

                call    pspace2PRN
                call    pspace2PRN

                mov     bl,failnum                      ;exception number
                call    phexbytePRN
                call    pspace2PRN

; see if theres an errorcode (ints 8,10-14,17)

                cmp     failnum,8
                je      IH_pEcode
                cmp     failnum,17
                je      IH_pEcode
                cmp     failnum,10
                jb      IH_common_exit
                cmp     failnum,14
                ja      IH_common_exit

IH_pEcode:      mov     bx,errorcode
                call    phexwordPRN

IH_common_exit:
                call    pcrlfPRN
                jmp     coldboot                        ;try a coldboot



; ============== NOW THE HANDLERS WHICH ARE USED ===============




;
; ----- Timer tick interrupt
;
IHR_TimerInt    PROC    near
                push    ax
                push    ds
                call    DSload
                dec     MotorCount
                jnz     pi8_exit
                call    motor_off               ;turn floppy motor off

pi8_exit:       mov     al,20h
                out     20h,al
                pop     ds
                pop     ax
                iret
IHR_TimerInt    ENDP





;
; Keyboard H/W Interrupt Handler, not INT 9 anymore (REAL & PROTECTED MODE)
; NB - doesnt check for buffer full cos I couldnt be bothered with that bit!
;
IHR_KybdInt     PROC    near
                cli
                push    ax
                push    bx
                push    ds
                push    bp
                mov     bp,sp                   ;point to stack frame

                call    DSload

                cmp     ignext9,0               ;must we ignore this key ?
                je      i9_getscan              ;no - read it
                dec     ignext9                 ;else dec ignore counter
                in      al,60h
                jmp     short i9_end

i9_getscan:     in      al,60h                  ;read keyboard port
                cmp     al,0e0h                 ;extended key code?
                je      i9_ext                  ;yes, must ignore next int
                cmp     al,0e1h                 ;extended code ?
                je      i9_ext                  ;yes, must ignore next int

; ----- check for special keys here, coldboot trap first

                cmp     al,coldboot_scan        ;coldboot monitor ?
                jne     i9ChkCsIp               ;no - check for next key
                mov     [bp+10], cs             ;else frig stack for the IRET
                mov     wptr [bp+8], offset coldboot
		clts
                jmp     short i9_end            ;and restart monitor

; ----- check if display all regs to printer

i9ChkCsIp:      cmp     al,regtrap_scan         ;print CS:IP trap key ?
                jne     i9ChkPause              ;no - jump
                call    pSnapRegs               ;print interrupted CS:IP
                jmp     short i9_end            ;then exit int 9 handler

; ----- check if screen hold/pause key

i9ChkPause:     cmp     al,pause_scan           ;pause key
                jne     i9ChkRel                ;no - jmp
i9cp_loop:      in      al,60h                  ;read keyboard port
                mov     ah,al                   ;keey copy in AH
                test    al,80h                  ;key released if top bit set
                jz      i9cp_loop               ;wait till pause key released
                jmp     short i9_end            ;then exit handler

; ----- end of special key traps

i9ChkRel:       test    al,80h                  ;key release ?
                jnz     i9_end                  ;yes - exit

                mov     bx,offset KeyTable      ;pnt to scancode->ASCII table
                xlat                            ;get ascii
                or      al,al                   ;ignore this key ?
                jnz     i9_goodkey              ;no - jmp to put in buffer
                mov     IgnoredKey,ah           ;else save port contents
                call    beep                    ;beep the speaker
                jmp     short i9_end            ;and jump to exit

i9_goodkey:     mov     bx,kbuffon              ;get onload pointer
                mov     [bx],al                 ;store the key
                inc     bx                      ;bump the pointer
                cmp     bx,offset kbufflast     ;past end of buffer ?
                jbe     r_saveon                ;no, jmp over pointer reset
                mov     bx,offset kbuff         ;reset ptr to start of buffer
r_saveon:       mov     kbuffon,bx              ;save new onload pointer

i9_end:         in      al,61h                  ;reset the keyboard
                or      al,80h
                jmp     $+2
                out     61h,al
                and     al,7fh
                jmp     $+2
                out     61h,al

                pop     bp                      ;resetore regs
                pop     ds
                pop     bx

                mov     al,20h                  ;send EOI to 8259
                out     20h,al

                pop     ax
                iret

; If we get an extended key, ignore the next byte sent

i9_ext:         sub     al,0dfh                 ;e0->1  e1->2
                mov     ignext9,al
                jmp     short i9_end

IHR_KybdInt     ENDP






; snapshot of registers (called only from keyboard HW interrupt handler)

pSnapRegs       PROC    near
                mov     bx,[bp+12]              ;F
                call    phexwordPRN
                call    pspacePRN
                mov     bx,[bp+10]              ;S
                call    phexwordPRN
                call    pspacePRN
                mov     bx,[bp+8]               ;O
                call    phexwordPRN
                call    pspace2PRN

                mov     bx,[bp+6]               ;AX
                call    phexwordPRN
                call    pspacePRN
                mov     bx,[bp+4]               ;BX
                call    phexwordPRN
                call    pspacePRN
                mov     bx,cx                   ;CX
                call    phexwordPRN
                call    pspacePRN
                mov     bx,dx                   ;DX
                call    phexwordPRN
                call    pspace2PRN

                mov     bx,ds			;DS
                call    phexwordPRN
                call    pspacePRN
                mov     bx,si			;SI
                call    phexwordPRN
                call    pspace2PRN

                mov     bx,es			;ES
                call    phexwordPRN
                call    pspacePRN
                mov     bx,di			;DI
                call    phexwordPRN
                call    pspace2PRN

                mov     bx,ss			;SS
                call    phexwordPRN
                call    pspacePRN
                mov     bx,sp			;SP
                call    phexwordPRN
                call    pcrlfPRN

                ret
pSnapRegs       ENDP







;
; ----- Floppy Disk Hardware Interrupt Handler
;
; When the hardware interrupt occurs from the floppy disk, this routine
; sets bit 7 in the seek_status flag and sends an EOI to the 8259.
;
IHR_FloppyInt   PROC    near
                push    ax
                push    ds
                call    DSload
                or      SeekStatus, DISK_INT_FLAG       ;set interrupt flag
                mov     al,20h                          ;reset 8259 PIC
                out     20h,al
                pop     ds
                pop     ax
                iret
IHR_FloppyInt   ENDP



;
; Divide by zero interrupt/exception handler (REAL & PROTECTED MODE)
;
IHR_0           PROC    near

                push    bp
                mov     bp,sp                   ;[BP+2] --> offset:seg
                push    ds
                pusha                           ;ax cx dx bx (sp) bp si di
                call    DSload

                mov     si,offset DivZeroMess
                call    pstring
                mov     bx,[bp+4]
                call    phexword
                mov     bl,':'
                call    pchar
                mov     bx,[bp+2]
                call    phexword
                call    pcrlf

	jmp	coldboot

; ------  bump IP past failed opcode (could be 2,3 or 4 bytes !)

                les     di,dword ptr [bp+2]     ;ES:DI--> failed opcode
                mov     al,es:[di+1]            ;get 2nd byte of opcode
                mov     ah,al                   ;keep copy in dx
                and     al,11000000b            ;get mod field in AL
                and     ah,00000111b            ;and r/m in AH
                mov     bx,2                    ;default IP bump = 2

                cmp     al,11000000b            ;mod=11 r/m=reg field
                je      do_i0_bump              ;bump 2 if equal

                cmp     al,01000000b            ;mod=01 sex disp-lo to 16 bit
                jne     chk_i0_mod10            ;no - jump
                inc     bx                      ;else inc bump to 3
                jmp     short do_i0_bump        ;and exit

chk_i0_mod10:   cmp     al,10000000b            ;mod=10 disp = disp-lo:disp-hi
                jne     i0_mod00                ;no, mod must = 00
                mov     bx,4
                jmp     short do_i0_bump

i0_mod00:       cmp     dl,00000110b            ;if mod=00 & r/m <>110, 2 bytes
                jne     do_i0_bump              ;else 4 bytes
                mov     bx,4


do_i0_bump:     add     wptr [bp+2],bx          ;add bump factor to saved IP

                popa
                pop     ds
                pop     bp

                mov     ax,1                    ;load constant quotient

                iret
IHR_0           ENDP





; ====================================================================
;
;               Now All The Default Handler Headers
;
;  (They're down here to advoid warning messages for short/long JMPs)
; ====================================================================
;

IHR_1:          DefIntHandler   1
IHR_2:          DefIntHandler   2
IHR_3:          DefIntHandler   3
IHR_4:          DefIntHandler   4
IHR_5:          DefIntHandler   5
IHR_6:          DefIntHandler   6
IHR_7:          DefIntHandler   7

;Number 8 handled earlier

IHR_9:          DefIntHandler   9
IHR_10:         DefIntHandler   10
IHR_11:         DefIntHandler   11

;Number 12 handled earlier

IHR_13:         DefIntHandler   13
IHR_14:         DefIntHandler   14
IHR_15:         DefIntHandler   15
IHR_16:         DefIntHandler   16
IHR_17:         DefIntHandler   17
IHR_18:         DefIntHandler   18
IHR_19:         DefIntHandler   19
IHR_20:         DefIntHandler   20
IHR_21:         DefIntHandler   21
IHR_22:         DefIntHandler   22
IHR_23:         DefIntHandler   23
IHR_24:         DefIntHandler   24
IHR_25:         DefIntHandler   25
IHR_26:         DefIntHandler   26
IHR_27:         DefIntHandler   27
IHR_28:         DefIntHandler   28
IHR_29:         DefIntHandler   29
IHR_30:         DefIntHandler   30
IHR_31:         DefIntHandler   31

MonCode         ENDS

		END
