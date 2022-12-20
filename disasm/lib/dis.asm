CMD_SUB equ 0
STATE_TWO_OPERANDS equ 1
STATE_READ_OFFSET equ 2

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
    command_names db "SUB  "
                  db "AAS  "
                  db "DAS  "
                  db "PUSH "
                  db "INC  "
                  db "SHR  "
                  db "ROR  "
                  db "AAA  "
                  db "DAA  "
    unknown_command db "NOP  "
    reg_operand db 30 dup (?)
    reg_mem_operand db 30 dup (?)
    reg_w_0 db "AL"
            db "CL"
            db "DL"
            db "BL"
            db "AH"
            db "CH"
            db "DH"
            db "BH"
    reg_w_1 db "AX"
            db "CX"
            db "DX"
            db "BX"
            db "SP"
            db "BP"
            db "SI"
            db "DI"
.code
    PUBLIC decode_buffer

decode_register proc near
    
decode_register endp

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

        cmp register, 0FFh
        je @@skip_reg

        cmp _width, 1h
        je @@reg_word

    @@reg_word:

    @@skip_reg:
        jmp @@exit
    @@unknown:
        lea dx, unknown_command
        mov ah, SYS_WRITE_FILE
        mov cx, 5
        int 21h
    @@exit:
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
        je @@read_offset_2

        cmp current_offset_index, 3
        je @@read_offset_3

        shl _offset, 8
        mov ah, 0
        add _offset, ax
    @@read_offset_3:
        call dump_command
        ret
    @@read_offset_2:
        mov ah, 0
        mov _offset, ax
        dec current_offset_index

        ret
    @@two_operands:
        ; Get mode
        mov ah, al
        and ah, 11000000b
        shr ah, 6
        mov mode, ah
        mov current_offset_index, ah

        ; Get register
        mov ah, al
        and ah, 00111000b
        shr ah, 3
        mov register, ah

        ; Get register/memory
        mov ah, al
        and ah, 00000111b
        mov register_memory, ah

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