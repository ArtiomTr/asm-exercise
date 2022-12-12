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
    PUBLIC read_filename

; Skips all blank characters from the beginning
; Uses es:[si]
trim_start PROC near

    trim_start_loop:
        cmp byte ptr es:[si], ' '
        je trim_start_continue

        ret
    trim_start_continue:
        inc si
        jmp trim_start_loop

trim_start ENDP

; Read filename from command line arguments
; Takes parameters:
;     es:[si] - current parsing command line argument
;     ds:[di] - pointer to the filename start
;     ds:[bx] - pointer to the extension start
read_filename PROC far
        push ax
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
        je @@return
        mov di, bx
        mov al, 'c'
        mov ds:[di], al
        inc di
        mov al, 'o'
        mov ds:[di], al
        inc di
        mov al, 'm'
        mov ds:[di], al
    @@return:
        pop ds
        pop cx
        pop ax

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
        lea dx, invalid_filename_error
        jmp read_filename_error_end
    @@max_length_exceeded:
        mov dx, @data
        mov ds, dx
        ; Pick error message
        cmp cl, 1h
        je @@extension_error
        lea dx, filename_too_long_error
        jmp read_filename_error_end
    @@extension_error:
        push dx
        
        mov dx, @data
        mov ds, dx
        lea dx, extension_too_long_error
    read_filename_error_end:
        pop dx
        ; Print error message
        mov ah, SYS_PRINT
        int INT_FUN_DISPATCH

        ; Failure exit
        mov al, EXIT_FAILURE
        mov ah, SYS_TERMINATE
        int INT_FUN_DISPATCH
read_filename ENDP
start:

end start