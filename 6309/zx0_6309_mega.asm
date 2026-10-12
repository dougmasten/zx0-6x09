; zx0_6309_mega.asm - ZX0 decompressor for H6309 - 124 bytes
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



; get elias value
zx0_elias          macro
                   lsla                ; get next bit
                   bcc loop@           ; more elias bits? yes, branch
                   bne done@           ; is bit stream empty? no, branch (elias = 1)
reload@            lda ,x+             ; load another group of 8 bits
                   rola                ; get next bit
                   bcs done@           ; are we done? yes, branch
loop@              lsla                ; get next bit
                   rolw                ; rotate bit into elias value
                   lsla                ; get next bit
                   bcc loop@           ; loop until done
                   beq reload@         ; is bit stream empty? yes, refill it
done@              equ *
                   endm

; get elias value (first bit already in carry)
zx0_elias_bt       macro
                   bcs done@           ; are we done? yes, branch
loop@              lsla                ; get next bit
                   rolw                ; rotate bit into elias value
                   lsla                ; get next bit
                   bcc loop@           ; loop until done
                   bne done@           ; is bit stream empty? no, branch
                   lda ,x+             ; load another group of 8 bits
                   rola                ; get next bit
                   bcc loop@           ; loop until done
done@              equ *
                   endm


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
                   bra zx0_literals

; 1 - copy from new offset (repeat N bytes from new offset)
zx0_new_offset     zx0_elias
                   comf
                   incf
                   beq zx0_rts
                   tfr f,e
                   ldf ,x+
                   rorw
                   tfr w,y             ; save offset (ADDR would destroy carry)
                   ldw #1              ; set elias = 1
                   zx0_elias_bt
                   incw
                   addr u,y            ; calculate match address
zx0_copy           tfm y+,u+           ; copy match
                   incw                ; set elias = 1
                   lsla
                   bcs zx0_new_offset

; 0 - literal (copy next N bytes)
zx0_literals       zx0_elias
                   addr w,y            ; keep match address in step with reg U
                   tfm x+,u+           ; copy literals
                   incw                ; set elias = 1
                   lsla                ; copy from last offset or new offset?
                   bcs zx0_new_offset

; 0 - copy from last offset (repeat N bytes from last offset)
                   zx0_elias
                   bra zx0_copy

zx0_rts            rts                 ; return
