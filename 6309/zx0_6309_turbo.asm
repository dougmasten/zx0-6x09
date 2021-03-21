; zx0_6309_turbo.asm - ZX0 decompressor for H6309 - 126 bytes
; Written by Doug Masten, based on the ZX0 Z80 decompressor by Einar Saukas.
;
; ZX0 compression algorithms are (c) 2021 Einar Saukas,
; see https://github.com/einar-saukas/ZX0


; get elias value
zx0_elias_next_value macro
                   lsla                ; get next bit
                   bne a@              ; is bit stream empty? no, branch
                   lda ,x+             ; load another group of 8 bits
                   rola                ; get next bit
a@                 bcs b@              ; are we done? yes, branch
                   bsr zx0_elias       ; more processing required for elias
b@                 equ *
                   endm

; rotate next bit into elias value
zx0_elias_rotate   macro
                   lsla                ; get next bit
                   rolw                ; rotate into elias value
                   lsla                ; get next bit
                   endm


;------------------------------------------------------------------------------
; Function    : zx0_decompress
; Entry       : Reg X = start of compressed data
;             : Reg U = start of decompression buffer
; Exit        : Reg X = end of compressed data + 1
;             : Reg U = end of decompression buffer + 1
; Destroys    : Regs D, V, W, Y
; Description : Decompress ZX0 data
;------------------------------------------------------------------------------
zx0_decompress     ldq #$ffff0001      ; init offset = -1 and elias = 1
                   tfr d,v             ; preserve offset
                   lda #$80            ; init bit stream
                   bra zx0_literals    ; start with literals

; 1 - copy from new offset (repeat N bytes from new offset)
zx0_new_offset
                   zx0_elias_next_value ; obtain MSB offset
                   comf                ; adjust for negative offset (set carry for RORW below)
                   incf                ;   "     "    "       "
                   beq zx0_rts         ; eof? (length = 256) if so exit
                   tfr f,e             ; move to MSB position
                   ldf ,x+             ; obtain LSB offset
                   rorw                ; last offset bit becomes first length bit
                   tfr w,v             ; preserve offset value
                   ldw #1              ; set elias = 1
                   bcs skip@           ; test first length bit
                   bsr zx0_elias       ; get elias but skip first bit
skip@              incw                ; elias = elias + 1
zx0_copy           tfr u,y             ; get current buffer address
                   addr v,y            ; and calculate offset address
                   tfm y+,u+           ; copy match
                   incw                ; set elias = 1
                   lsla                ; get next bit
                   bcs zx0_new_offset  ; branch if next block is new offset

; 0 - literal (copy next N bytes)
zx0_literals
                   zx0_elias_next_value ; obtain length
                   tfm x+,u+           ; copy literals
                   incw                ; set elias = 1
                   lsla                ; copy from last offset or new offset?
                   bcs zx0_new_offset  ; branch if next block is new offset

; 0 - copy from last offset (repeat N bytes from last offset)
                   zx0_elias_next_value
                   bra zx0_copy        ; go copy last offset block


; interlaced elias gamma coding
zx0_elias
                   zx0_elias_rotate
                   bcc zx0_elias       ; loop until done
                   beq zx0_elias_reload ; is bit stream empty? if yes, refill it
zx0_rts            rts                 ; return

loop@              zx0_elias_rotate
zx0_elias_reload   lda ,x+             ; load another group of 8 bits
                   rola                ; get next bit
                   bcs zx0_rts
                   zx0_elias_rotate
                   bcs zx0_rts
                   zx0_elias_rotate
                   bcs zx0_rts
                   zx0_elias_rotate
                   bcc loop@
                   rts
