CMD_SUB equ 0
STATE_TWO_OPERANDS equ 1
STATE_READ_OFFSET equ 2

; ASCII symbols
ASCII_CR equ 0Dh ; carriage return
ASCII_LF equ 0Ah ; line feed

SYS_WRITE_FILE equ 40h

.model small

JUMPS
LOCALS @@

.data
    mode db 0FFh ; mod byte
    register db 0FFh ; reg
    register_memory db 0FFh ; r/m
    direction db 0FFh ; d
    _width db 0FFh ; w
    command db 0FFh
    state db 0
    _offset dw 0
    current_offset_index db 0
    command_names   db "sub  "
                    db "aas  "
                    db "das  "
                    db "push "
                    db "inc  "
                    db "shr  "
                    db "ror  "
                    db "aaa  "
                    db "daa  "
    unknown_command db "nop  "
    command_break db ASCII_CR, ASCII_LF
    reg_operand db 30 dup (?)
    reg_mem_operand db 30 dup (?)
    operand_separator db ", "
    reg_byte     db "al"
    reg_byte_tag db "cl"
                 db "dl"
                 db "bl"
                 db "ah"
                 db "ch"
                 db "dh"
                 db "bh"
    reg_word     db "ax"
    reg_word_tag db "cx"
                 db "dx"
                 db "bx"
                 db "sp"
                 db "bp"
                 db "si"
                 db "di"
    ea_unary     db "[si"
    ea_unary_tag db "[di"
                 db "[bp"
                 db "[bx"
    ea_binary     db "[bx+si"
    ea_binary_tag db "[bx+di"
                  db "[bp+si"
                  db "[bp+di"
.code
    include .\lib\string.inc

    EA_UNARY_WIDTH equ [offset ea_unary_tag - offset ea_unary]
    EA_BINARY_WIDTH equ [offset ea_binary_tag - offset ea_binary]
    REG_WORD_WIDTH equ [offset reg_word_tag - offset reg_word]
    REG_BYTE_WIDTH equ [offset reg_byte_tag - offset reg_byte]

    PUBLIC decode_buffer

convert_offset proc near
        push bx
        mov ah, 0
        mov bl, 10h
        div bl
        
        cmp al, 10
        jb @@first_decimal

        add al, 'A' - 10
        jmp @@second
    @@first_decimal:
        add al, '0'
    @@second:
        cmp ah, 10
        jb @@second_decimal
        add ah, 'A' - 10
        jmp @@exit
    @@second_decimal:
        add ah, '0'
    @@exit:
        pop bx
        ret
convert_offset endp

dump_offset proc near
        cmp al, 0
        je @@exit

        mov bl, '+'
        mov byte ptr ds:[di], bl
        inc di

        mov bl, '0'
        mov byte ptr ds:[di], bl
        inc di

        push ax
        mov ax, word ptr _offset
        call convert_offset

        mov bl, al
        mov byte ptr ds:[di], bl
        inc di

        mov bl, ah
        mov byte ptr ds:[di], bl
        inc di
        pop ax

        cmp al, 01
        je @@offset_end

        push ax
        mov ax, word ptr _offset
        mov al, ah
        call convert_offset

        mov bl, al
        mov byte ptr ds:[di], bl
        inc di

        mov bl, ah
        mov byte ptr ds:[di], bl
        inc di
        pop ax
    @@offset_end:
        mov bl, 'h'
        mov byte ptr ds:[di], bl
        inc di
    @@exit:
        mov bl, ']'
        mov byte ptr ds:[di], bl
        inc di

        ret
dump_offset endp

dump_directed_operands proc near
        push si di

        lea si, reg_mem_operand
        lea di, reg_operand
        
        cmp register, 0FFh
        je @@reg_mem_only
    
        cmp reg_mem_operand, 0FFh
        je @@reg_only
        
        cmp direction, 1
        je @@dump

        lea si, reg_operand
        lea di, reg_mem_operand
        jmp @@dump
    @@reg_only:
        lea si, reg_operand
        jmp @@only_one
    @@reg_mem_only:
        cmp reg_mem_operand, 0FFh
        je @@exit
        jmp @@only_one
    @@dump:
        mov dx, di
        call str_len
        mov ah, SYS_WRITE_FILE
        int 21h

        lea dx, operand_separator
        mov cx, 2
        mov ah, SYS_WRITE_FILE
        int 21h
    @@only_one:
        mov dx, si
        call str_len
        mov ah, SYS_WRITE_FILE
        int 21h
    @@exit:
        pop di si
        ret

dump_directed_operands endp

; ah - r/m operand
; al - mod operand
; bh - w operand
; ds:[di] - output path
decode_operand proc near
        push ax si cx

        cmp al, 011b
        je @@register

        mov bl, ah
        shr bl, 2

        and ah, 011b

        cmp bl, 01b
        je @@effective_address_unary

        lea si, ea_binary
        mov cx, EA_BINARY_WIDTH
        jmp @@output
    @@effective_address_unary:
        lea si, ea_unary
        mov cx, EA_UNARY_WIDTH

        jmp @@output
    @@register:
        cmp bh, 1
        je @@word_register

        lea si, reg_byte
        jmp @@register_decode
    @@word_register:
        lea si, reg_word
    @@register_decode:
        mov cx, REG_BYTE_WIDTH
    @@output:
        push ax
        mov al, ah
        mul cl
        add si, ax
        pop ax
    @@output_loop:
        mov bl, byte ptr ds:[si]
        mov byte ptr ds:[di], bl
        inc si
        inc di
        loop @@output_loop

        cmp al, 011b
        je @@exit
        call dump_offset
    @@exit:
        mov bl, '$'
        mov byte ptr ds:[di], bl

        pop cx si ax
        ret
decode_operand endp

dump_command proc near
        push cx
        cmp command, 0FFh
        je @@unknown

        lea dx, command_names

        push ax
        mov al, command
        mov ah, 5
        mul ah
        add dx, ax
        pop ax

        mov ah, SYS_WRITE_FILE
        mov cx, 5
        int 21h

        push bx
        cmp register, 0FFh
        je @@register_skip

        mov ah, register
        mov al, 011b
        mov bh, _width
        lea di, reg_operand
        call decode_operand
    @@register_skip:
        cmp reg_mem_operand, 0FFh
        je @@reg_mem_skip

        mov ah, register_memory
        mov al, mode
        lea di, reg_mem_operand
        call decode_operand
    @@reg_mem_skip:
        pop bx

        call dump_directed_operands

        jmp @@exit
    @@unknown:
        lea dx, unknown_command
        mov ah, SYS_WRITE_FILE
        mov cx, 5
        int 21h
    @@exit:
        lea dx, command_break
        mov ah, SYS_WRITE_FILE
        mov cx, 2
        int 21h

        mov mode, 0FFh
        mov register, 0FFh
        mov direction, 0FFh
        mov _width, 0FFh
        mov command, 0FFh
        mov state, 0
        mov _offset, 0
        mov current_offset_index, 0

        pop cx
        ret
dump_command endp

decode_byte proc near
        cmp state, 0
        je @@match_command

        cmp state, STATE_TWO_OPERANDS
        je @@two_operands

        cmp state, STATE_READ_OFFSET
        je @@read_offset
    @@read_offset:
        cmp current_offset_index, 2
        je @@read_offset_next

        shl _offset, 8
        mov ah, 0
        add _offset, ax
        call dump_command
        ret
    @@read_offset_next:
        mov ah, 0
        mov _offset, ax
        dec current_offset_index

        ret
    @@two_operands:
        ; Get register
        mov ah, al
        and ah, 00111000b
        shr ah, 3
        mov register, ah

        ; Get register/memory
        mov ah, al
        and ah, 00000111b
        mov register_memory, ah

        ; Get mode
        mov ah, al
        and ah, 11000000b
        shr ah, 6
        mov mode, ah

        cmp mode, 01b
        je @@schedule_offset_read

        cmp mode, 10b
        je @@schedule_offset_read

        call dump_command
        ret
    @@schedule_offset_read:
        mov current_offset_index, ah
        mov state, STATE_READ_OFFSET

        ret
    @@match_command:
        mov ah, al
        and ah, 11111100b
        cmp ah, 00101000b
        je @@sub_1

        ; TODO: unrecognized
        call dump_command
        ret
    @@sub_1:
        ; Save width
        mov ah, al
        and ah, 1b
        mov _width, ah 

        ; Save direction
        mov ah, al
        and ah, 10b
        shr ah, 1
        mov direction, ah

        ; Set up flags for further processing
        mov command, CMD_SUB
        mov state, STATE_TWO_OPERANDS
        
        ret
decode_byte endp

decode_buffer proc near
        push ds es di

        mov ax, ds
        mov es, ax

        mov ax, @data
        mov ds, ax
    @@read_loop:
        mov al, byte ptr es:[si]
        call decode_byte
        inc si
        loop @@read_loop

        pop di es ds
        ret
decode_buffer endp

start:

end start