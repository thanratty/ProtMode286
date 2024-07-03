;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;;
;;		PAGE		,132
;;		TITLE		Real/Protected Mode Monitor
;;		SUBTTL		Protected Mode Descriptors Include File
;;		Author		Tony Hanratty
;;		Created		23/07/91
;;		Changed		29/09/92
;;
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-


.xlist


; ----- Different Descriptor Type Codes

dtype_free286TSS	equ	1
dtype_LDT		equ	2
dtype_busy286TSS	equ	3
dtype_286callgate	equ	4
dtype_286taskgate	equ	5
dtype_286intgate	equ	6
dtype_286trapgate	equ	7
dtype_free486TSS	equ	9
dtype_busy486TSS	equ	11
dtype_486callgate	equ	12
dtype_486intgate	equ	14
dtype_486taskgate	equ	15


; ----- Basic segment descriptor format

SEGdesc			STRUC
sdesc_limit		dw	?
sdesc_baselo		dw	?
sdesc_basehi		db	?
sdesc_arb		db	?
sdesc_reserved		dw	?
SEGdesc			ENDS
SEGdescLen		equ	size SEGdesc


; ----- IDT descriptor format

IDTdesc			STRUC
idesc_offset		dw	?
idesc_selector		dw	?
idesc_word_count	db	?
idesc_arb		db	?
idesc_reserved		dw	?
IDTdesc			ENDS
IDTdescLen		equ	size IDTdesc


; ----- Any gate descriptor format

GATEdesc		STRUC
gdesc_offset		dw	?
gdesc_selector		dw	?
gdesc_word_count	db	?
gdesc_arb		db	?
gdesc_reserved		dw	?
GATEdesc		ENDS


; ----- Structure of a Task State Segment (not a descriptor)

TSSstruc		STRUC
tdesc_backlink		dw	?
tdesc_SP0		dw	?
tdesc_SS0		dw	?
tdesc_SP1		dw	?
tdesc_SS1		dw	?
tdesc_SP2		dw	?
tdesc_SS2		dw	?
tdesc_IP		dw	?
tdesc_flags		dw	?
tdesc_AX		dw	?
tdesc_CX		dw	?
tdesc_DX		dw	?
tdesc_BX		dw	?
tdesc_SP		dw	?
tdesc_BP		dw	?
tdesc_SI		dw	?
tdesc_DI		dw	?
tdesc_ES		dw	?
tdesc_CS		dw	?
tdesc_SS		dw	?
tdesc_DS		dw	?
tdesc_LDT		dw	?
TSSstruc		ENDS
TSSlen			equ	size TSSstruc



; ----- Default access rights byte for differant descriptor types

Code_ARB	equ		10011110b
Data_ARB	equ		10010010b
Stack_ARB	equ		10010010b	;NB expand up for static stack
Screen_ARB	equ		11110010b	;same as Data_ARB but DPL=3
NP_ARB		equ		00010010b
LDT_ARB		equ		10000010b
Gate_ARB	equ		11100100b	;DPL 3 call gate
TSS_ARB		equ		11100001b	;available TSS, DPL 3

TI_bit		equ		4		;Table Indicator in selector

.list
