
.model small

LOCALS @@

.data
.code

PUBLIC str_concat, str_len

; Concats two strings
; ds:[di] - destination
; ds:[si] - first source
; ds:[ax] - second source
str_concat proc near
        push bx
        mov bh, 0h
    @@loop:
        mov bl, byte ptr ds:[si]
        cmp bl, '$'
        je @@break
        mov byte ptr ds:[di], bl
        inc di
        inc si
        jmp @@loop
    @@break:
        cmp bh, 1h
        je @@exit

        mov bh, 1h
        mov si, ax
        jmp @@loop
    @@exit:
        mov byte ptr ds:[di], 0
        pop bx
        ret
str_concat endp

; Calculates string length
; ds:[dx] - source
; cx - output
str_len proc near
        push si
        mov si, dx
        mov cx, 0
    @@loop:
        cmp byte ptr ds:[si], '$'
        je @@exit
        inc si
        inc cx
        jmp @@loop
    @@exit:
        pop si
        ret
str_len endp

start:

end start