CL_ARGUMENTS_START equ 81h
BUFFER_SIZE equ 40
FILENAME_MAX_LENGTH equ 8
EXTENSION_MAX_LENGTH equ 3

; Interrupt codes
INT_FUN_DISPATCH equ 21h

; Function disptach codes (interrupt 21h)
SYS_PRINT equ 09h
SYS_TERMINATE equ 4Ch
SYS_OPEN_FILE equ 3Dh
SYS_CREATE_FILE equ 3Ch
SYS_CLOSE_FILE equ 3Eh
SYS_READ_FILE equ 3Fh

; File open modes
FILE_READ equ 0h

.model small
.stack 100h
JUMPS

.data
    source_filename db (FILENAME_MAX_LENGTH + EXTENSION_MAX_LENGTH + 2) dup (?)
    source_file_handle dw ?
    destination_filename db (FILENAME_MAX_LENGTH + EXTENSION_MAX_LENGTH + 2) dup (?)
    destination_file_handle dw ?
    filename  db (FILENAME_MAX_LENGTH + 1) dup (?)
    extension_sep db '.'
    extension db (EXTENSION_MAX_LENGTH + 1) dup (?)
    extension_output db ".asm$"
    buffer db BUFFER_SIZE dup (?)
.code
    include .\lib\filename.inc
    include .\lib\string.inc
    include .\lib\dis.inc
start:
    ; Swap data from data segment into extra segment
    mov dx, ds
    mov es, dx

    ; Put data into data segment
    mov dx, @data
    mov ds, dx

    mov si, CL_ARGUMENTS_START

    call parse_next
exit:
    mov al, 0
    mov ah, 4Ch
    int INT_FUN_DISPATCH
open_error:
    ; TODO: add error logging
    jmp exit
    jmp exit

parse_next proc near
        lea di, filename
        lea bx, extension

        call read_filename
        jc @@filename_error

        lea si, filename
        lea di, source_filename
        lea ax, extension_sep
        call str_concat

        lea si, filename
        lea di, destination_filename
        lea ax, extension_output
        call str_concat

        lea dx, source_filename
        mov al, FILE_READ
        mov ah, SYS_OPEN_FILE
        int INT_FUN_DISPATCH
        jc @@open_error
        mov source_file_handle, ax
        
        lea dx, destination_filename
        mov ah, SYS_CREATE_FILE
        mov cx, 0
        int INT_FUN_DISPATCH
        jc @@open_error
        mov destination_file_handle, ax

    @@read_loop:
        mov bx, source_file_handle
        lea dx, buffer
        mov cx, BUFFER_SIZE
        mov ah, SYS_READ_FILE
        int INT_FUN_DISPATCH
        ; TODO: add error logging
        cmp ax, 0
        je @@cleanup

        mov bx, destination_file_handle
        mov cx, ax
        lea si, buffer
        call decode_buffer

        jmp @@read_loop
    @@cleanup:
        mov bx, source_file_handle
        mov ah, SYS_CLOSE_FILE
        int INT_FUN_DISPATCH

        mov bx, destination_file_handle
        mov ah, SYS_CLOSE_FILE
        int INT_FUN_DISPATCH

        ret
    @@open_error:
        ; TODO: add error logging
        ret
    @@filename_error:
        call print_filename_read_error
        ret
parse_next endp

end start