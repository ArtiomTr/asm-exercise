CL_ARGUMENTS_START equ 81h

.model large
.stack 100h
JUMPS

.data
    filename  db 9 dup (?), '$'
    extension db 4 dup (?), '$'
.code
    include .\lib\filename.inc
start:
    ; Swap data from data segment into extra segment
    mov dx, ds
    mov es, dx

    ; Put data into data segment
    mov dx, @data
    mov ds, dx

    mov si, CL_ARGUMENTS_START
    
    lea di, filename
    lea bx, extension

    call read_filename
    
    lea dx, filename
    mov ah, 09h
    int 21h

    mov dl, '.'
    mov ah, 2
    int 21h

    lea dx, [extension]
    mov ah, 09h
    int 21h

    mov al, 0
    mov ah, 4Ch
    int 21h
end start