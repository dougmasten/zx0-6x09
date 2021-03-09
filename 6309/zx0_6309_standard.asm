; zx0_6309_standard.asm - ZX0 decompressor for H6309 - 75 bytes
; Written by Doug Masten
; Based on the ZX0 Z-80 decompressor by Einar Saukas
;
; ZX0 compression algorithms are (c) 2021 Einar Saukas,
; see https://github.com/einar-saukas/ZX0


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

; 0 - literal (copy next N bytes from compressed data)
zx0_literals       bsr zx0_elias       ; obtain length
                   tfm x+,u+           ; copy literals
                   incw                ; set elias = 1
                   lsla                ; get next bit
                   bcs zx0_new_offset  ; branch if next block is new offset

; 0 - copy from last offset (repeat N bytes from last offset)
                   bsr zx0_elias       ; obtain length
zx0_copy           tfr u,y             ; get current buffer address
                   addr v,y            ; and calculate offset address
                   tfm y+,u+           ; copy match
                   incw                ; set elias = 1
                   lsla                ; get next bit
                   bcc zx0_literals    ; branch if next block is literals

; 1 - copy from new offset (repeat N bytes from new offset)
zx0_new_offset     bsr zx0_elias       ; obtain offset MSB
                   comf                ; adjust for negative offset (set carry for RORW below)
                   incf                ;   "     "    "       "
                   beq zx0_eof         ; eof? (length = 256) if so exit
                   tfr f,e             ; move to MSB position
                   ldf ,x+             ; obtain LSB offset
                   rorw                ; last offset bit becomes first length bit
                   tfr w,v             ; preserve new offset
                   ldw #1              ; set elias = 1
                   bcs skip@           ; test first length bit
                   bsr zx0_backtrace   ; get elias but skip first bit
skip@              incw                ; elias = elias + 1
                   bra zx0_copy        ; go copy new offset match


; interlaced elias gamma coding
zx0_backtrace
loop@              lsla                ; get next bit
                   rolw                ; rotate bit into gamma value
zx0_elias          lsla                ; get next bit
                   bne skip@           ; branch if bit stream is not empty
                   lda ,x+             ; load another group of 8 bits
                   rola                ; get next bit
skip@              bcc loop@           ; loop again until done
zx0_eof            rts                 ; return
