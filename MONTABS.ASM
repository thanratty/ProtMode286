.286P

;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;;
;;              PAGE            ,132
;;              TITLE           Real/Protected Mode Monitor
;;              SUBTTL          Descriptor Tables & Control Routines
;;              Author          Tony Hanratty
;;              Created         03/10/92
;;              Last Changed    05/10/92
;;
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-


                include         mondesc.inc
                include         moncomn.inc
                include         moncode.inc



; ----- Local data definitions

                public  dES, dDS, dCS, dSS, dScreen, _dDump, _dScan, dScan
                public  dNP, dVdisk, dDump, dLoadSeg
                public  _dES, _dDS, _dCS, _dSS, _dScreen, _dLoadSeg
                public  _dGDT, GDTlen

; ----- External Code Definitions

                extrn   zzzCodeLen:byte, zzzDataLen:byte
		extrn	LoadSegLen:byte


; ----- Local Code Publics

                public  SetdFree, FinddFree, SetdDPL, SetdLimit
                public  SetdBase, SetdData, SetdCode, SetdType
                public  GetdARB,  GetdBase, GetdLimit, SetdSystem
                public  SetdPresent





MonGDT          SEGMENT para public 'DATA'

_dnull          SEGdesc         <0,0,0,0,0>             ;null 1st entry
_dGDT           SEGdesc         <GDTlen-1, 0,0, Data_ARB, 0>
_dCS            SEGdesc         <zzzCodeLen-1, RunSeg_lo,RunSeg_hi, Code_ARB,0>
_dES            SEGdesc         <-1, 0,0, Data_ARB,  0>
_dDS            SEGdesc         <zzzDataLen-1, 0,0, Data_ARB,   0>
_dSS            SEGdesc         <STACK_LEN-1,  0,0, Data_ARB,   0>
_dScreen        SEGdesc         <SCREEN_LEN-1 ,0,0, Screen_ARB, 0>
_dLoadSeg	SEGdesc		<LoadSegLen-1 ,0,0, Code_ARB,   0>

_dDump          SEGdesc         <-1 , 0,0,    Data_ARB, 0>
_dNP            SEGdesc         < 1 , 0,0,    NP_ARB,   0>
_dScan          SEGdesc         <10h, 0,0,    Data_ARB, 0>
_dVdisk         SEGdesc         <-1,  0,10h,  Data_ARB, 0>

COMMENT $

                ; Put these gates in to test the GDT printout
                GATEdesc        <10h,20h,1,10000000b,0>
                GATEdesc        <11h,21h,1,10100001b,0>
                GATEdesc        <12h,22h,1,11000010b,0>
                GATEdesc        <13h,23h,1,11100011b,0>
                GATEdesc        <14h,24h,1,10000100b,0>
                GATEdesc        <15h,25h,1,10100101b,0>
                GATEdesc        <16h,26h,1,11000110b,0>
                GATEdesc        <17h,27h,1,11100111b,0>
                GATEdesc        <18h,28h,1,10001000b,0>
                GATEdesc        <19h,29h,1,10101001b,0>
                GATEdesc        <1ah,2ah,1,11001010b,0>
                GATEdesc        <1bh,2bh,1,11101011b,0>
                GATEdesc        <1ch,2ch,1,10001100b,0>
                GATEdesc        <1dh,2dh,1,10101101b,0>
                GATEdesc        <1eh,2eh,1,11001110b,0>
                GATEdesc        <1fh,2fh,1,11101111b,0>
$

; ----- Now descriptors for the memory manager and its allocated RAM

                SEGdesc        10 dup (<0,0,0,0,0>)



; ----- Ensure GDT always ends on a paragraph boundary

		if (($ - seg $) and 15) gt 0
			db	SEGdescLen dup (0)
		endif

GDTlen          equ     $ - seg $


;
; ------------------- End of GLOBAL DESCRIPTOR TABLE -------------------
;

; 'Segment' selector values

GDT_alias               equ     offset _dGDT
dDS                     equ     offset _dDS
dCS                     equ     offset _dCS
dES                     equ     offset _dES
dSS                     equ     offset _dSS
dScreen                 equ     offset _dScreen
dLoadSeg		equ	offset _dLoadSeg
dDump                   equ     offset _dDump
dNP                     equ     offset _dNP
dVdisk                  equ     offset _dVdisk
dScan                   equ     offset _dScan

MonGDT          ENDS








MonCode         SEGMENT para public 'CODE'
                ASSUME  cs:MonCode, ds:NOTHING


;===========================================================================
; Change Descriptor Type To AL = 0-15, BX=Selector
; N.B Selector **MUST** Reference A System Segment Descriptor
;===========================================================================
;
SetdType        PROC    near
                test    bx,TI_bit
                jnz     SdType_exit

                push    ds
                push    GDT_alias
                pop     ds
                and     al,0fh                          ;make sure type=0-15
                and     bptr [bx].sdesc_arb,0f0h        ;clear old type
                or      bptr [bx].sdesc_arb,al          ;set new type
                pop     ds

SdType_exit:    ret
SetdType        ENDP




;===========================================================================
;               Change Descriptor Type To System Segment, BX=Selector
;===========================================================================
;
SetdSystem      PROC    near
                test    bx,TI_bit
                jnz     SdSys_exit

                push    ds
                push    GDT_alias
                pop     ds
                and     [bx].sdesc_arb,11101111b        ;clear S bit
                pop     ds

SdSys_exit:     ret
SetdSystem      ENDP





;===========================================================================
;  Change Descriptor To Readable, Non-Conforming Code Segment, BX=Selector
;===========================================================================
;
SetdCode        PROC    near
                test    bx,TI_bit
                jnz     SdCode_exit

                push    ds
                push    GDT_alias
                pop     ds
                or      [bx].sdesc_arb,00011001b        ;set S,E and R bits
                and     [bx].sdesc_arb,11111011b        ;clear C bit
                pop     ds

SdCode_exit:    ret
SetdCode        ENDP





;===========================================================================
;       Change Descriptor To R/W, Expand Up, Data Segment, BX=Selector
;===========================================================================
;
SetdData        PROC    near
                test    bx,TI_bit
                jnz     SdData_exit

                push    ds
                push    GDT_alias
                pop     ds
                or      [bx].sdesc_arb,00010010b        ;set S and R bits
                and     [bx].sdesc_arb,11110010b        ;clear E,ED and A bits
                pop     ds

SdData_exit:    ret
SetdData        ENDP






;===========================================================================
;               Change Descriptor DPL To AL=0-3, BX=Selector
;===========================================================================
;
SetdDPL         PROC    near
                test    bx,TI_bit
                jnz     SdDPL_exit

                push    ds

                push    GDT_alias
                pop     ds
                and     al,3
                shl     al,5
                and     bptr [bx].sdesc_arb,10011111b
                or      bptr [bx].sdesc_arb,al

                pop     ds
SdDPL_exit:     ret
SetdDPL         ENDP





;===========================================================================
;                  Change Descriptor Limit To AX, BX=Selector
;===========================================================================
;
SetdLimit       PROC    near
                test    bx,TI_bit
                jnz     SdLimit_exit

                push    ds
                push    GDT_alias
                pop     ds
                mov     [bx].sdesc_limit, ax
                pop     ds

SdLimit_exit:   ret
SetdLimit       ENDP





;===========================================================================
;               Change Descriptor Base To DL:AX, BX=Selector
;===========================================================================
;
SetdBase        PROC    near
                test    bx,TI_bit
                jnz     SdBase_exit

                push    ds
                push    GDT_alias
                pop     ds
                mov     [bx].sdesc_baselo, ax
                mov     [bx].sdesc_basehi, dl
                pop     ds

SdBase_exit:    ret
SetdBase        ENDP




;===========================================================================
;               Mark Descriptor As Free (Set ARB=0)
;===========================================================================
;
SetdFree        PROC    near
                test    bx,TI_bit
                jnz     SdFree_exit

                push    ds
                push    GDT_alias
                pop     ds
                mov     [bx].sdesc_arb, 0		;0 in ARB = unused
                pop     ds

SdFree_exit:    ret
SetdFree        ENDP



;
; Return BX=selector to 1st free descriptor in GDT (C=0=OK)
;
FinddFree       PROC    near
                push    ds

                push    GDT_alias
                pop     ds
                mov     bx,8

FdF_loop:       cmp     [bx].sdesc_arb,0
                je      FdFree_OK
                add     bx,8
                cmp     bx,offset GDTlen
                jne     FdF_loop
                stc

FdFree_OK:      pop     ds
                ret                                     ;return C flag
FinddFree       ENDP






GetdBase        PROC    near
                push    ds

                push    GDT_alias
                pop     ds
                mov     dl,[bx].sdesc_basehi
                mov     ax,[bx].sdesc_baselo

                pop     ds
                ret
GetdBase        ENDP


GetdARB         PROC    near
                push    ds

                push    GDT_alias
                pop     ds
                mov     al,[bx].sdesc_arb

                pop     ds
                ret
GetdARB         ENDP



GetdLimit       PROC    near
                push    ds

                push    GDT_alias
                pop     ds
                mov     ax,[bx].sdesc_limit

                pop     ds
                ret
GetdLimit       ENDP



SetdPresent     PROC    near
                push    ds

                push    GDT_alias
                pop     ds
                or      [bx].sdesc_arb, 80h

                pop     ds
                ret
SetdPresent     ENDP



MonCode         ENDS

		END
