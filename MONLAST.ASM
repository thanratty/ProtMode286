.286P

;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;;
;;              PAGE            ,132
;;              TITLE           Real/Protected Mode Monitor
;;              SUBTTL          Last File Specified To Linker
;;              Author          Tony Hanratty
;;              Created         11/09/91
;;              Last Changed    11/09/91
;;
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-


;
; This module MUST be the last file specified to the linker. The labels
; defined here will then be at the very end of their respective segments.
; They are used in other modules to work out segment lengths etc..
;

;
; N.B. No class definition for zzzData segment so it comes after the
; C routines data segments and isnt grouped with MonData.


PGROUP		GROUP	zzzCode
DGROUP		GROUP	zzzData



zzzCode		SEGMENT para public 'CODE'
		PUBLIC	zzzCodeLen
zzzCodeLen	LABEL	byte
zzzCode		ENDS

zzzData		SEGMENT para public
		PUBLIC	zzzDataLen
zzzDataLen	LABEL	byte
zzzData		ENDS

		END
