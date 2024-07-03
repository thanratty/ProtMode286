.286P

;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;;
;;              PAGE            ,132
;;              TITLE           Real/Protected Mode Monitor
;;              SUBTTL          1Meg Memory Management Routines
;;              Author          Tony Hanratty
;;              Created         21/09/92
;;              Last Changed    15/10/92
;;
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-

                include         moncode.inc
                include         moncomn.inc
                include         mondesc.inc


; ----- Data Externals

                extrn   dScan:abs, GDTlen:abs

; ----- Code Externals

                extrn   DSload:near, Address24:near
                extrn   phexword:near, phexbyte:near, pcrlf:near
                extrn   pspace:near, pspace2:near, pstring:near
                extrn   phexwordPRN:near, phexbytePRN:near
                extrn   pcrlfPRN:near, pspacePRN:near
                extrn   gethexword:near

                extrn   SetdFree:near, SetdDPL:near, SetdData:near
                extrn   SetdLimit:near, SetdBase:near, FinddFree:near
                extrn   SetdPresent:near

; ----- Code Publics

                public  DeAllocMem, AllocMem, InitMemory
                public  ShowMemChain, SaveChainStart

; ----- Data Publics


; ----- Local Equatres

_alloc_free     equ     0
_alloc_used     equ     1


; LOCAL STRUCTURE, no other module should need to know the
; layout of a memory control block.

MemArena                STRUC
MemBlkAlloc             db      ?               ;1=this is allocated
MemBlkSize              dw      ?               ;size of this block in paras
MemBlkSelector          dw      ?               ;selector used if allocated
MemBlkNextLo            dw      ?               ;24 bit next arena address
MemBlkNextHi            db      ?
MemArena                ENDS
MemArenaLen             equ     size MemArena





MonData         SEGMENT para public 'DATA'

; ----- Read/Write Stuff First

RamFree                 dw      ?               ;free RAM in Paragraphs

; ----- Now Read Only Locations

RamSize                 dw      ?               ;total RAM in machine
ChainStartHi            db      ?               ;start of allocated mem chain
ChainStartLo            dw      ?
ChainStartPara          dw      ?

RamStart_mess           db      cr,lf,'Memory Chain Starts At ',null
AllocFree_mess          db      cr,lf,'Unallocated paragraphs      : ',null
AllocWhatParas          db      cr,lf,'Request how many paragraphs : ',null

MonData         ENDS





MonCode         SEGMENT para public 'CODE'
                ASSUME  cs:MonCode, ds:MonData



;===========================================================================
;                       ALLOCATE MEMORY BLOCK
;
; Call With:
;       DX=number of requested paragraphs
;       DX=0000, returns total free paragraphs in AX
; Returns:
;       C=0  success, AX=new GDT selector to RAM
;       C=1  fail, no mem allocated
;
; N.B.  All allocated blocks are given a slot in the GDT which defines them
;       as data segments. Use the 'Setd' routines to change their type and
;       DPL etc if you want to use them as code or system segments etc..
;===========================================================================
;
AllocMem        PROC    near
                push    ds
                call    DSload

                or      dx,dx                           ;asking how much free ?
                jne     am_request                      ;no - jump over
                mov     ax,RamFree                      ;else load answer
                pop     ds                              ;and get out
                clc
                ret


am_request:     cmp     RamFree,dx                      ;have we got enough ?
                jb      am_error                        ;no exit
                cmp     dx,1000h                        ;64k max ?
                ja      am_error

                mov     cx,dx                           ;paras wanted in CX
                mov     dl,ChainStartHi                 ;chain start address
                mov     ax,ChainStartLo


am_ScanChain:   call    BuildDescriptor                 ;fill in _dScan in GDT
                                                        ;& point ES to it
                cmp     es:[0].MemBlkAlloc,_alloc_free  ;free block ?
                jne     am_ScanNext                     ;no - try next one
                cmp     es:[0].MemBlkSize,cx            ;big enough ?
                jae     am_ScanFound                    ;yes, jmp to grab it

am_ScanNext:    mov     ax,es:[0].MemBlkNextLo          ;get link to next arena
                mov     dl,es:[0].MemBlkNextHi
                or      ax,ax                           ;carry on if <> 0
                jnz     am_ScanChain
                or      dl,dl
                jnz     am_ScanChain                    ;fall through if end

am_error:       pop     ds
                stc
                ret


; Found a free block, allocate it & set size to what was requested

am_ScanFound:   mov     es:[0].MemBlkAlloc,_alloc_used  ;mark it allocated
                sub     es:[0].MemBlkSize,cx            ;adjust size of block
                xchg    es:[0].MemBlkSize,cx            ;CX=RAM remaining
                dec     cx                              ;correct for arena size
                mov     RamFree,cx                      ;and save new value

; Fill out a GDT entry for it. DL:AX = arena, block size now in arena

                call    BuildGDTEntry                   ;get selector in BX
                jc      am_error                        ;no space in GDT
                mov     es:[0].MemBlkSelector,bx        ;else save descriptor

; Now GDT entry is valid, we can use it to zero the block

                push    es                              ;save current arena
                push    ax
                mov     es,bx                           ;get new block segment
                lsl     cx,bx                           ;get seg limit
                inc     cx                              ;true limit in bytes
                shr     cx,1                            ;= #words to blank
                xor     di,di                           ;offset zero
                xor     ax,ax                           ;fill with 0000
                rep     stosw
                pop     ax
                pop     es                              ;restore arena pointer

; Now build an new arena after allocated RAM (DL:AX still --> current arena)

                mov     bl,0                            ;BL:CX=what we grabbed
                mov     cx,es:[0].MemBlkSize            ;   in paras
                inc     cx                              ;+1 para for arena
                shl     cx,1                            ;*16 = bytes
                rcl     bl,1
                shl     cx,1
                rcl     bl,1
                shl     cx,1
                rcl     bl,1
                shl     cx,1
                rcl     bl,1

                add     ax,cx                           ;add to arena
                adc     dl,bl                           ;=address of new arena
                mov     es:[0].MemBlkNextLo,ax          ;fill in the link
                mov     es:[0].MemBlkNextHi,dl

                mov     cx,es:[0].MemBlkSelector        ;load return value now

                call    BuildDescriptor                 ;point ES to new arena
                mov     bx,RamFree
                mov     es:[0].MemBlkSize,bx            ;size of new block
                mov     es:[0].MemBlkAlloc, _alloc_free
                mov     es:[0].MemBlkNextLo,0
                mov     es:[0].MemBlkNextHi,0
                mov     es:[0].MemBlkSelector,0

                mov     ax,cx                           ;get return val in AX
                clc
                pop     ds
                ret                                     ;return selector in AX
AllocMem        ENDP





;===========================================================================
; Passed DL:AX = base address, fill in _dScan descriptor in GDT and point
; ES to it. Musnt hurt any regs!
;===========================================================================
;
BuildDescriptor PROC    near
                push    bx
                mov     bx,dScan
                call    SetdBase
                mov     es,bx
                pop     bx
                ret
BuildDescriptor ENDP







;==========================================================================
;   INITIALISE MEMORY CHAIN - FREE UP ANY ALOCATED SEGMENTS & DESCRIPTORS
;
; Calculate 1st free physical address and free RAM size
; Build an arena at the physical address using dScan in the GDT
; Adjust free size for arena size
; Mark RAM unallocated
;==========================================================================
;
InitMemory      PROC    near
                push    ds
                call    DSload

                mov     ax,ChainStartLo                 ;get chain start
                mov     dl,ChainStartHi                 ; (set by LoadSeg)
                mov     bx,ChainStartPara

; ----- Eval Size of Free RAM if none allocated

                mov     cx,RamSize                      ;set by LoadSeg
                sub     cx,bx                           ;- free RAM start
                dec     cx                              ;ammend for 1st arena
                mov     RamFree,cx                      ;init free paras


; DL:AX=RAM base, BX=base segment, CX=corrected free RAM paras
; Protected mode init, step through chain

WipeChain:      call    BuildDescriptor                 ;fill _dScan, load ES
                mov     dl,es:[0].MemBlkNextHi          ;get DL:AX-->Nxt arena
                mov     ax,es:[0].MemBlkNextLo

                cmp     es:[0].MemBlkAlloc, _alloc_used         ;this one used?
                je      WC2                                     ;yes - free it
                xor     ax,ax
                mov     dl,al
                jmp     short WC3


; Now reset the arena header

WC2:            mov     bx,es:[0].MemBlkSelector        ;get selector
                call    SetdFree                        ;free it

WC3:            mov     es:[0].MemBlkSize,cx            ;CX<>0 on 1st pass
                mov     es:[0].MemBlkAlloc, _alloc_free
                mov     es:[0].MemBlkNextLo,0
                mov     es:[0].MemBlkNextHi,0
                mov     es:[0].MemBlkSelector,0

                xor     cx,cx                           ;zero free paras

; If next link is null, that was the last one

                or      dl,dl
                jnz     WipeChain
                or      ax,ax
                jnz     WipeChain

MI_exit:        pop     ds
                ret
InitMemory      ENDP



	extrn	SER_outch:near

SERIAL		MACRO	c
			push	ax
			mov		al,c
			call	SER_outch
			pop		ax
			ENDM



;==========================================================================
;
; Called By LoadSeg :   DL:AX= Free Memory Start Address
;                       BX   = Total Memory Paras In Machine
;
; -*-*-*-*- ONLY CALLED IN >>>REAL<<< MODE BY LOADSEG -*-*-*-*-
;
SaveChainStart  PROC    far

;	SERIAL	'a'

                mov     RamSize,bx                      ;save total ram size
                mov     ChainStartLo,ax                 ;and free RAM start
                mov     ChainStartHi,dl

                mov     cx,4                            ;load shift count
scs_freepara:   shr     dl,1                            ;/16 = parag address
                rcr     ax,1
                loop    scs_freepara
                mov     ChainStartPara,ax               ;save paragraph address

                mov     es,ax                           ;load free ram parag
				sub		bx,ax							;ramsize-free start
				dec		bx								;-arena=# free paras
				mov		RamFree,bx

                mov     es:[0].MemBlkSize, bx           ;set initial free RAM
                mov     es:[0].MemBlkAlloc, _alloc_free
                mov     es:[0].MemBlkNextHi,0
                mov     es:[0].MemBlkNextLo,0
                mov     es:[0].MemBlkSelector,0

;	SERIAL	'b'

				ret

SaveChainStart  ENDP





;===========================================================================
;               BUILD AN ENTRY IN THE GDT FOR A NEW MEMORY BLOCK
;
; Passed arena address in DL:AX, block size already in arena.
; Find an unused descriptor in the GDT and fill it in.
;
; Returns: C=0   BX=new selector
;          C=1   No space in GDT, BX invalid
;===========================================================================
;
BuildGDTEntry   PROC    near

                call    FinddFree                       ;returned in BX
                jnc     bge_found
                ret

bge_found:      push    ax                              ;save arena address
                push    dx

                add     ax,10h                          ;skip base past arena
                adc     dl,0
                call    SetdBase                        ;to DL:AX

                mov     ax,es:[0].MemBlkSize            ;size in paras
                shl     ax,4                            ;*16 = bytes
                dec     ax                              ;= limit-1
                call    SetdLimit

                call    SetdData
                mov     al,3
                call    SetdDPL

                call    SetdPresent

                pop     dx
                pop     ax
                clc
                ret
BuildGDTEntry   ENDP





ShowMemChain    PROC    near

		mov     si,offset AllocFree_mess
                call    pstring
                xor     dx,dx
                call    AllocMem
                pushf
                push    ax
                mov     bl,0
                adc     bl,0
                call    phexbyte
                pop     ax
                popf
                jc      smc_grab
                mov     bx,ax
                call    pspace
                call    phexword

smc_grab:       mov     si,offset AllocWhatParas
                call    pstring
                call    gethexword
                call    pspace2

                mov     dx,bx
                call    AllocMem
                mov     bl,0
                adc     bl,0
                call    phexbyte
                call    pspace
                mov     bx,ax
                call    phexword
                call    pcrlf

                mov     si,offset RamStart_mess
                call    pstring

                mov     bl,ChainStartHi
                call    phexbyte
                mov     bx,ChainStartLo
                call    phexword
                call    pcrlf

                mov     ax,ChainStartLo
                mov     dl,ChainStartHi

smc_loop:       call    BuildDescriptor

                mov     bl,es:[0].MemBlkAlloc
                call    phexbyte
                call    pspace2
                mov     bx,es:[0].MemBlkSelector
                call    phexword
                call    pspace2
                mov     bx,es:[0].MemBlkSize
                call    phexword
                call    pspace2
                mov     bl,es:[0].MemBlkNextHi
                call    phexbyte
                mov     bx,es:[0].MemBlkNextLo
                call    phexword
                call    pcrlf

                mov     dl,es:[0].MemBlkNextHi
                mov     ax,es:[0].MemBlkNextLo

                mov     bl,0
                or      bl,dl
                or      bl,ah
                or      bl,al
                jnz     smc_loop

                call    pcrlf
                ret

ShowMemChain    ENDP








; ==========================================================================
;                       DEALLOCATE MEMORY BLOCK
; Passed:
;        BX = Selector to memory block
; Return:
;        CF = 1 Bad selector, fail
;        CF = 0 Memory deallocated OK, GDT descriptor slot erased.
; ==========================================================================
;
DeAllocMem      PROC    near
                push    ds
                call    DSload

                mov     dl,ChainStartHi                 ;chain start address
                mov     ax,ChainStartLo

dm_ScanChain:   call    BuildDescriptor                 ;fill in _dScan in GDT
                                                        ;& point ES to it
                cmp     es:[0].MemBlkAlloc,_alloc_used  ;used block ?
                jne     dm_ScanNext                     ;no - try next one
                cmp     es:[0].MemBlkSelector,bx        ;one were looking for?
                je      dm_ScanFound                    ;yes, jmp out

dm_ScanNext:    mov     ax,es:[0].MemBlkNextLo          ;get link to next arena
                mov     dl,es:[0].MemBlkNextHi
                or      ax,ax                           ;carry on if <> 0
                jnz     dm_ScanChain
                or      dl,dl
                jnz     dm_ScanChain                    ;fall through if end

dm_error:       pop     ds
                stc
                ret


; Found the block, deallocate it but leave arena there (for now!! tstst)

dm_ScanFound:   mov     es:[0].MemBlkAlloc,_alloc_free  ;mark it free
                mov     cx,es:[0].MemBlkSize            ;get its size
                dec     cx                              ;correct for arena size
                add     RamFree,cx                      ;add on to free pool

                call    SetdFree                        ;Kill its GDT entry

	%OUT	It would be nice to tidy up the arena chain in DeAllocMem !

                clc
                pop     ds
                ret                                     ;return selector in AX

DeAllocMem      ENDP


MonCode         ENDS

		END
