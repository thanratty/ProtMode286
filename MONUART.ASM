.286P

		include		moncomn.inc		;common equates

		public		CommSetup
		public		SER_phexword, SER_phexbyte, SER_phexchar, SER_pcrlf, SER_outch

	



;;
;; Serial Port Addresses
;;

_COM_BASE_REG	equ		3f8h

TXRX			equ		_COM_BASE_REG + 0		;Rx/Tx reg
IER				equ		_COM_BASE_REG + 1		;interrupt enable
IIR				equ		_COM_BASE_REG + 2		;interrupt ident
LCR				equ		_COM_BASE_REG + 3		;line control
MCR				equ		_COM_BASE_REG + 4		;modem control
LSR				equ		_COM_BASE_REG + 5		;line status
MSR				equ		_COM_BASE_REG + 6		;modem status


; Serial port default contents now

_LINE_STATE		equ		00000011b				;8 data, no parity, 1 stop
_MODEM_STATE	equ		00001011b				;ints on, RTS DTR active
_IER_STATE		equ		00000000b				;no ints on
_FIFO_STATE		equ		10000111b				;8 bytes, reset & enable
_DLAB			equ		80h						;UART divisor latch enable 


TXRX			equ		_COM_BASE_REG + 0		;Rx/Tx reg
IER				equ		_COM_BASE_REG + 1		;interrupt enable
IIR				equ		_COM_BASE_REG + 2		;interrupt ident
LCR				equ		_COM_BASE_REG + 3		;line control
MCR				equ		_COM_BASE_REG + 4		;modem control
LSR				equ		_COM_BASE_REG + 5		;line status
MSR				equ		_COM_BASE_REG + 6		;modem status

; Baud rate divisors

div_1200		equ		0060h
div_2400		equ		0030h
div_4800		equ		0018h
div_9600		equ		000ch
div_19200		equ		0006h
div_38400		equ		0003h
div_57600		equ		0002h
div_115200		equ		0001h






LoadSeg		SEGMENT para public 'CODE' USE16
			ASSUME	cs:LoadSeg, ds:NOTHING



; Set COM1 to 38400,N,8,1

CommSetup		PROC	near

				mov	dx,LCR
				in	al,dx
				or	al,_DLAB
				out	dx,al			;set DLAB bit
		
				mov	dx,TXRX			;point to divisor latches
				mov	ax,div_38400
				out	dx,al
				inc	dx
				mov	al,ah
				out	dx,al			;set baud rate divisor
		
				mov	dx,LCR			;line control reg
				mov	al,_LINE_STATE
				out	dx,al			;clear DLAB & set line
		
				mov	dx,MCR			;modem control reg
				mov	al,_MODEM_STATE
				out	dx,al			;set modem control reg
		
				mov	dx,MSR
				in	al,dx			;clear delta flags
				mov	dx,LSR
				in	al,dx			;clear delta flags
		
				mov	dx,IIR			;set FIFO threshold etc
				mov	al,_FIFO_STATE
				out	dx,al
		
				mov	dx,IER			;int enable reg
				mov	al,_IER_STATE	;load enable 'mask'
				out	dx,al			;unmask sources
		
				ret
CommSetup		ENDP






SER_phexword        proc    near            ;print hex word in bx
	        	push    bx
	        	mov     bl,bh
	        	call    SER_phexbyte
	        	pop     bx
	        	call    SER_phexbyte
	        	ret
SER_phexword        endp


SER_phexbyte        proc    near            ;print hex byte in bl
	        	push    cx
	        	push    bx
	        	mov     cl,4
	        	shr     bl,cl
	        	call    SER_phexchar
	        	pop     bx
	        	and     bl,0fh
	       	 	call    SER_phexchar
	        	pop     cx
	        	ret
SER_phexbyte        endp


SER_phexchar        proc    near            ;print hex char in bl
	        	push    bx
	        	push    ax
	        	or      bl,30h
	       		cmp     bl,'9'
	        	jle     SHORT phc_2
	        	add     bl,7
phc_2:			mov     al,bl
				call	SER_outch
	        	pop     ax
	        	pop     bx
	        	ret
SER_phexchar        endp


SER_pcrlf   		proc    near
	        	push    ax
	        	mov     al,cr
	        	call	SER_outch
	        	mov     al,lf
				call	SER_outch
	        	pop     ax
	        	ret
SER_pcrlf   		endp




SER_outch  			PROC    near			; char in AL to COM1
				push	dx
				push	ax
				mov		dx,03fdh
SER_outch_1:	in		al,dx
				test	al,20h
				jz		SER_outch_1
				mov		dx,03f8h
				pop		ax
				out		dx,al
				pop		dx
				ret
SER_outch  			ENDP



pspace			proc	near
				push	ax
				mov		al,20h
				call	SER_outch
				pop		ax
				ret
pspace			endp







SER_decout			PROC	near
				push	bx		;save regs we use
				push	dx
				cmp		ax,9
				jbe		SHORT decout9
				cmp		ax,99
				jbe		SHORT decout99
				cmp		ax,999
				jbe		decout999
				cmp		ax,9999
				jbe		decout9999	;fall through now to decout99999

decout99999:	mov		bx,10000	; output decimal in AX <=99999
				call	dodiv
decout9999:		mov		bx,1000		; output decimal in AX <=9999
				call	dodiv
decout999:		mov		bx,100		; output decimal in AX <=999
				call	dodiv
decout99:		mov		bx,10		; output decimal in AX <=99
				call	dodiv
decout9:		or		al,30h		; output decimal in AX <=9
				call	SER_outch
				pop		dx			; restore regs
				pop	bx
				ret					; return to caller

dodiv:			xor		dx,dx
				div		bx			; al = int, dx = rem
				push	dx			; save remainder
				or		al,30h
				call	SER_outch
				pop		ax			; remainder = new quotient
				ret
SER_decout			ENDP


LoadSeg		ENDS
			END


