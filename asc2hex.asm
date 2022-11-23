ASCII_CR equ 0Dh
ASCII_LF equ 0Ah
INT_FUN_DISPATCH equ 21h
SYS_PRINT equ 09h
SYS_OUT equ 02h
SYS_TERMINATE equ 4ch
SYS_READ_STR equ 0Ah

ToHex macro word1
local @@exit, @@digit
    cmp word1, 9h
    jle @@digit
    sub word1, 0Ah
    add word1, 'A'
    jmp @@exit
@@digit:
    add word1, '0'
@@exit:
endm ToHex

.model small
.stack 100h

.data
    msg db "Hello! Please enter ASCII symbols: $"
    output_msg db ASCII_CR, ASCII_LF, "The hexadecimal values of ASCII symbols: $"
    empty_error db "Input cannot be empty! Please, try again: $"
    input db 100, ?, 100 dup (0)
.code

start:
    mov dx, @data
    mov ds, dx

    mov dx, offset msg
    mov ah, SYS_PRINT
    int INT_FUN_DISPATCH

input_start:    
    mov dx, offset input
    mov ah, SYS_READ_STR
    int INT_FUN_DISPATCH
    
    mov cl, input[1]
    cmp cl, 0
	je error

    mov dx, offset output_msg
    mov ah, SYS_PRINT
    int INT_FUN_DISPATCH

    mov si, offset input + 2
    xor ch, ch

print_char:
    mov al, byte ptr [si]
    inc si
    
    mov ah, 0
    mov bh, 10h
    div bh
    
    mov bx, ax
    
    ToHex bh
    ToHex bl

    mov ah, SYS_OUT
    mov dl, bl
    int INT_FUN_DISPATCH

    mov ah, SYS_OUT
    mov dl, bh
    int INT_FUN_DISPATCH
    
    mov ah, SYS_OUT
    mov dl, ' '
    int INT_FUN_DISPATCH

    loop print_char
    jmp ending
    
error:
    mov dx, offset empty_error
    mov ah, SYS_PRINT
    int INT_FUN_DISPATCH

    jmp input_start

ending:
    mov al, 0
    mov ah, SYS_TERMINATE
    int INT_FUN_DISPATCH
end start