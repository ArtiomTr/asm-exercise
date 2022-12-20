FILENAME_MAX_LENGTH equ 8
EXTENSION_MAX_LENGTH equ 3

ASCII_CR equ 0Dh ; carriage return

SYS_PRINT equ 09h
SYS_TERMINATE equ 4Ch

EXIT_FAILURE equ 1h

INT_FUN_DISPATCH equ 21h

.model small

LOCALS @@

.data
    filename_too_long_error db "Filename is too long - maximum allowed length is 8$"
    extension_too_long_error db "Extension is too long - maximum allowed length is 3$"
    invalid_filename_error db "Filename cannot contain dollar sign$"
.code
    PUBLIC read_filename, print_filename_read_error

print_filename_read_error proc near
        push dx
        push ds
        push ax

        mov dx, @data
        mov ds, dx

        cmp al, 01h
        je @@extension_error
        cmp ah, 01h
        je @@filename_invalid_character
        lea dx, filename_too_long_error
        jmp @@exit
    @@filename_invalid_character:
        lea dx, invalid_filename_error
        jmp @@exit
    @@extension_error:
        cmp ah, 01h
        je @@extension_invalid_character
        lea dx, extension_too_long_error
        jmp @@exit
    @@extension_invalid_character:
        lea dx, invalid_filename_error
    @@exit:
        mov ah, SYS_PRINT
        int 21h

        pop ax
        pop ds
        pop dx
        ret
print_filename_read_error endp

; Skips all blank characters from the beginning
; Uses es:[si]
trim_start PROC near

    @@loop:
        cmp byte ptr es:[si], ' '
        je @@continue

        ret
    @@continue:
        inc si
        jmp @@loop

trim_start ENDP

; Read filename from command line arguments
; Takes parameters:
;     es:[si] - current parsing command line argument
;     ds:[di] - pointer to the filename start
;     ds:[bx] - pointer to the extension start
read_filename PROC near
        push cx
        push ds

        ; Skip all whitespaces
        call trim_start
        
        mov ah, 0h
        mov cl, 0h
        mov ch, FILENAME_MAX_LENGTH
    @@loop:
        inc ah

        ; If filename contains '$', it is considered invalid
        cmp byte ptr es:[si], '$'
        je @@invalid_character
        ; If end of string occurred, filename is completely read
        cmp byte ptr es:[si], ASCII_CR
        je @@ending
        ; If a space occurred, filename is completely read
        cmp byte ptr es:[si], ' '
        je @@ending
        ; If a dot occurred, read extension
        cmp byte ptr es:[si], '.'
        je @@extension
        ; If filename length is greater than max length, print error
        cmp ch, ah 
        jl @@max_length_exceeded
    @@next:
        ; Read next character and append it to the filename
        mov al, es:[si]
        mov ds:[di], al
        inc si
        inc di
        jmp @@loop
    @@ending:
        ; End current string
        mov al, '$'

        mov ds:[di], al

        inc di
        ; If extension is empty, set it to "com"
        cmp cl, 1h
        je @@success_return
        mov di, bx
        mov al, 'c'
        mov ds:[di], al
        inc di
        mov al, 'o'
        mov ds:[di], al
        inc di
        mov al, 'm'
        mov ds:[di], al
    @@success_return:
        mov ax, 0
    @@return:
        pop ds
        pop cx

        ret
    @@extension:
        ; Check if already reading extension
        cmp cl, 1h
        je @@next

        ; Increment index to skip dot
        inc si
        ; End filename string
        mov al, '$'
        mov ds:[di], al
        inc di
        ; Prepare state for reading extension
        mov di, bx
        mov ah, 0
        mov ch, EXTENSION_MAX_LENGTH
        mov cl, 1h
        jmp @@loop
    @@invalid_character:
        stc
        mov ah, 01h
        mov al, cl
        jmp @@return
    @@max_length_exceeded:
        stc
        mov ah, 02h
        mov al, cl
        jmp @@return
read_filename ENDP
start:

end start