; zx0_6309_mega.asm - ZX0 decompressor for H6309 - 149 bytes
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


; only get one bit from stream
zx0_get_1bit       macro
                   lsla                ; get next bit
                   bne done@           ; is bit stream empty? no, branch
                   lda ,x+             ; load another group of 8 bits
                   rola                ; get next bit
done@              equ *
                   endm

; get elias value
zx0_elias_bt       macro
                   bcs done@
loop@              lsla                ; get next bit
                   rolw                ; rotate bit into elias value
                   lsla                ; get next bit
                   bcc loop@           ; loop until done
                   bne done@           ; is bit stream empty? no, branch
                   bsr zx0_reload      ; process rest of elias until done
done@              equ *
                   endm


;------------------------------------------------------------------------------
; Function    : zx0_decompress
; Entry       : Reg X = start of compressed data
;             : Reg U = start of decompression buffer
; Exit        : Reg X = end of compressed data + 1
;             : Reg U = end of decompression buffer + 1
; Destroys    : Regs D, V, W, Y
; Description : Decompress ZX0 data (version 1)
;------------------------------------------------------------------------------
zx0_decompress     ldq #$ffff0001      ; init offset = -1 and elias = 1
                   tfr d,v             ; preserve offset
                   lda #$80            ; init bit stream
                   bra zx0_literals

; 1 - copy from new offset (repeat N bytes from new offset)
zx0_new_offset     zx0_get_1bit
                   zx0_elias_bt
                   comf
                   incf
                   beq zx0_rts
                   tfr f,e
                   ldf ,x+
                   rorw
                   tfr w,v
                   ldw #1              ; set elias = 1
                   zx0_elias_bt
                   incw
zx0_copy           tfr u,y
                   addr v,y
                   tfm y+,u+           ; copy match
                   incw                ; set elias = 1
                   lsla
                   bcs zx0_new_offset

; 0 - literal (copy next N bytes)
zx0_literals       zx0_get_1bit
                   zx0_elias_bt
                   tfm x+,u+           ; copy literals
                   incw                ; set elias = 1
                   lsla                ; copy from last offset or new offset?
                   bcs zx0_new_offset

; 0 - copy from last offset (repeat N bytes from last offset)
                   zx0_get_1bit
                   zx0_elias_bt
                   bra zx0_copy


; interlaced elias gamma coding
loop@              lsla                ; get next bit
                   rolw                ; rotate bit into elias value
                   lsla                ; get next bit
zx0_reload         lda ,x+             ; load another group of 8 bits
                   rola
                   bcs zx0_rts
                   lsla                ; get next bit
                   rolw                ; rotate bit into elias value
                   lsla                ; get next bit
                   bcs zx0_rts
                   lsla                ; get next bit
                   rolw                ; rotate bit into elias value
                   lsla                ; get next bit
                   bcs zx0_rts
                   lsla                ; get next bit
                   rolw                ; rotate bit into elias value
                   lsla                ; get next bit
                   bcc loop@
zx0_rts            rts
