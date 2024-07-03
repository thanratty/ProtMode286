;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;;
		PAGE		,132
		TITLE		Real/Protected Mode Monitor
		SUBTTL		Segment Ordering Module
;;		Author		Tony Hanratty
;;		Created		12/04/91
;;		Last Changed	22/11/92
;;
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;; -*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
;
;
;; This module MUST be the first one passed to the linker so the segments
;; are written to the final .EXE in this order. The GDT table sizing and
;; code relocation routines make presumptions about code & data positions
;; relative to each other. All the strange names below are the various
;; uninitialised, initialised, code and heap segments used by my 'C' compiler
;; by default. All code is grouped into PGROUP, and data into DGROUP. Labels
;; defined in the last file passed to the linker (MONLAST.ASM) will be at the
;; last physical byte in the code and data groups. In other words, dont mess
;; with this file unless you're sure what you're doing.
;;
;;==========================================================================


;;
;; Load segment - discarded once monitor relocated and running
;;
LoadSeg         segment para public 'CODE'
LoadSeg         ends


;;
;; Main monitor code segment
;;
MonCode         segment para public 'CODE'
MonCode         ends


;;
;; 'C' code segment
;;
@CODE           segment byte public 'CODE'
@CODE           ends


;;
;; Last physical code segment in group PGROUP. (contains no code)
;;
zzzCode		segment byte public 'CODE'
zzzCode		ends


;;
;; Main monitor data segment
;;
MonData         segment para public 'DATA'
MonData         ends


;;
;; Separate segment for Global Descriptor Table for protected mode
;;
MonGDT          segment para public 'DATA'
MonGDT          ends


;;
;; 5 Data segments defined by 'C'. All empty bar one.
;;
@DATAB          segment word public 'DATAB'
@DATAB          ends

@DATAI          segment word public 'DATAI'
@DATAI          ends

@DATAT          segment word public 'DATAT'
@DATAT          ends

@DATAU          segment word public 'DATAU'
@DATAU          ends

@DATAV          segment word public 'DATAV'
@DATAV          ends


;;
;; Last physical data segment in group DGROUP. (contains no data)
;;
zzzData		segment word public
zzzData		ends


;;
;; MUST be last physical segment in load image. (empty)
;;
DummySeg        segment para public
DummySeg        ends





;;
;; Group definitions, (D)ata and (P)rogram
;;
DGROUP          GROUP	MonData, MonGDT, @DATAB, @DATAI, @DATAT, @DATAU, @DATAV, zzzData, DummySeg
PGROUP          GROUP   MonCode, @CODE, zzzCode

		END
