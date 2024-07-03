;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;;
;;		PAGE		,132
;;		TITLE		Real/Protected Mode Monitor
;;		SUBTTL		Main Module (MONCODE.ASM) Include File
;;		Author		Tony Hanratty
;;		Created		11/08/91
;;		Changed		29/09/92
;;
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-


.xlist

SCREEN_LEN	equ	(80*2*25)
STACK_LEN	equ	8192			;2000 hex bytes
STACK_TOP	equ	STACK_LEN		;initial stack pointer

.list

