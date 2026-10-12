; zx0_6309_standard.asm - ZX0 decompressor for H6309 - 74 bytes
; Written for the LWTOOLS assembler, http://www.lwtools.ca/.
;
; Copyright (c) 2021 Doug Masten
; ZX0 compression (c) 2021 Einar Saukas, https://github.com/einar-saukas/ZX0
;
; This software is provided 'as-is', without any express or implied
; warranty. In no event will the authors be held liable for any damages
; arising from the use of this software.
;
; Permission is granted to anyone to use this software for any purpose,
; including commercial applications, and to alter it and redistribute it
; freely, subject to the following restrictions:
;
; 1. The origin of this software must not be misrepresented; you must not
;    claim that you wrote the original software. If you use this software
;    in a product, an acknowledgment in the product documentation would be
;    appreciated but is not required.
; 2. Altered source versions must be plainly marked as such, and must not be
;    misrepresented as being the original software.
; 3. This notice may not be removed or altered from any source distribution.


;------------------------------------------------------------------------------
; Function    : zx0_decompress
; Entry       : Reg X = start of compressed data
;             : Reg U = start of decompression buffer
; Exit        : Reg X = end of compressed data + 1
;             : Reg U = end of decompression buffer + 1
; Destroys    : Regs D, W, Y
; Description : Decompress ZX0 data (version 1)
;
; Reg Y always holds the match source address (U + offset). Since TFM Y+,U+
; advances both registers equally it only needs adjusting after literals.
;------------------------------------------------------------------------------
zx0_decompress     ldq #$80000001      ; init bit stream and elias = 1
                   leay -1,u           ; init offset = -1

; 0 - literal (copy next N bytes from compressed data)
zx0_literals       bsr zx0_elias       ; obtain length
                   addr w,y            ; keep offset address in step with reg U
                   tfm x+,u+           ; copy literals
                   incw                ; set elias = 1
                   lsla                ; get next bit
                   bcs zx0_new_offset  ; branch if next block is new offset

; 0 - copy from last offset (repeat N bytes from last offset)
                   bsr zx0_elias       ; obtain length
zx0_copy           tfm y+,u+           ; copy match
                   incw                ; set elias = 1
                   lsla                ; get next bit
                   bcc zx0_literals    ; branch if next block is literals

; 1 - copy from new offset (repeat N bytes from new offset)
zx0_new_offset     bsr zx0_elias       ; obtain MSB offset
                   comf                ; adjust for negative offset (set carry for RORW below)
                   incf                ;   "     "    "       "
                   beq zx0_rts         ; eof? (offset = 256) if so exit
                   tfr f,e             ; move to MSB position
                   ldf ,x+             ; obtain LSB offset
                   rorw                ; offset bit #0 becomes first length bit
                   tfr w,y             ; preserve new offset (ADDR would destroy carry)
                   ldw #1              ; set elias = 1
                   bsr zx0_elias_bt    ; get length but skip first elias bit
                   incw                ; length = length + 1
                   addr u,y            ; calculate offset address
                   bra zx0_copy        ; go copy new offset match


; interlaced elias gamma coding
zx0_elias_loop     lsla                ; get next bit
                   rolw                ; rotate bit into gamma value
zx0_elias          lsla                ; get next bit
                   bcc zx0_elias_loop  ; loop if more bits (stream can't be empty)
                   bne zx0_rts         ; done if bit stream is not empty
                   lda ,x+             ; load another group of 8 bits
                   rola                ; get next bit
zx0_elias_bt       bcc zx0_elias_loop  ; loop again until done
zx0_rts            rts                 ; return
