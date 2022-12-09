BUFFER_SIZE equ 20
LINE_SIZE equ 16

.model small
.stack 100H

JUMPS ; auto generate inverted condition jmp on far jumps
    
.data

    help_message db "Hex viewer$"
    err_s    	db 'Source failo nepavyko atidaryti skaitymui',13,10,'$'
    byte_no db " Addr.  $"
    file_name db " File: $"
    ascii db  " ASCII $" 
    sourceF db 12 dup (0)
    sourceFHandle dw ?

    line dd 00000000h

    buffer db BUFFER_SIZE dup (?)
    line_buffer db LINE_SIZE dup (?)
.code

start:
    mov ax, ds
    mov es, ax
    
    mov ax, @data
    mov ds, ax
 
    mov si, 81h ; programos paleidimo parametrai rasomi segmente es pradedant 129 (arba 81h) baitu        
 
    call skip_spaces
    
    mov al, byte ptr es:[si] ; nuskaityti pirma parametro simboli
    cmp al, 13 ; jei nera parametru
    je help ; tai isvesti pagalba
    ;; ar reikia isvesti pagalba
    mov ax, word ptr es:[si]
    cmp ax, 3F2Fh ; jei nuskaityta "/?" - 3F = '?'; 2F = '/'
    je help ; rastas "/?", vadinasi reikia isvesti pagalba

readSourceFile:
    ;; source failo pavadinimas
    lea di, sourceF
    call read_filename ; perkelti is parametro i eilute
    
    cmp byte ptr ds:[sourceF], 0 ; jei nieko nenuskaite
    je _end
source_from_file:
    mov dx, offset sourceF ; failo pavadinimas
    mov ah, 3dh ; atidaro faila - komandos kodas
    mov al, 0 ; 0 - reading, 1-writing, 2-abu
    int 21h ; INT 21h / AH= 3Dh - open existing file
    jc err_source ; CF set on error AX = error code.
    mov sourceFHandle, ax ; issaugojam filehandle

    push si
    call print_file_header

    mov word ptr line[0], 0
    mov word ptr line[1], 0

    lea si, line_buffer
skaitom:
    mov bx, sourceFHandle
    mov dx, offset buffer       ; address of buffer in dx
    mov cx, BUFFER_SIZE      ; kiek baitu nuskaitysim
    mov ah, 3fh  ; function 3Fh - read from file
    int 21h
    jc help ; CF set on error; AX = error code.
    
    lea di, buffer

    mov cx, ax ; bytes actually read
    cmp ax, 0 ; jei nenuskaite
    jne _6 ; tai ne pabaiga

    mov bx, sourceFHandle ; pabaiga skaitomo failo
    mov ah, 3eh ; uzdaryti
    int 21h

    cmp si, offset line_buffer
    je skip_line_printing
    call print_last_line
    call print_end_line
skip_line_printing:
    call print_file_footer
    pop si
    jmp readSourceFile ; atidaryti kita skaitoma faila, jei yra
_6:
    cmp sourceFHandle, 0
    jne atrenka
    cmp byte ptr ds:[di], 13
    je _end
atrenka:
    cmp si, offset line_buffer
    jne skip_line_print
    call print_line_no
skip_line_print:
    mov al, byte ptr ds:[di]
    inc di
    mov byte ptr ds:[si], al
    inc si

    call to_hex

    mov dl, ' '
    mov ah, 2
    int 21h

    cmp si, offset line_buffer + LINE_SIZE
    je end_line
continue:
    loop atrenka

    jmp skaitom
end_line:
    call print_end_line
    lea si, line_buffer
    jmp continue
help:
    mov ax, @data
    mov ds, ax
    
    mov dx, offset help_message         
    mov ah, 09h
    int 21h

    jmp _end
_end:
    mov ax, 4c00h
    int 21h  

err_source:
    mov ax, @data
    mov ds, ax
    
    mov dx, offset err_s        
    mov ah, 09h
    int 21h
    
    mov ax, 4c01h
    int 21h  
    
;; procedures
    
skip_spaces PROC near

skip_spaces_loop:
    cmp byte ptr es:[si], ' '
    jne skip_spaces_end
    inc si
    jmp skip_spaces_loop
skip_spaces_end:
    ret
    
skip_spaces ENDP

read_filename PROC near
    push ax
    call skip_spaces
read_filename_start:
    cmp byte ptr es:[si], 13 ; jei nera parametru
    je read_filename_end ; tai taip, tai baigtas failo vedimas
    cmp byte ptr es:[si], ' ' ; jei tarpas
    jne read_filename_next ; tai praleisti visus tarpus, ir sokti prie kito parametro
read_filename_end:
    mov al, 0 ; irasyti '\0' gale
    mov byte ptr ds:[di], al
    pop ax
    ret
read_filename_next:
    mov al, byte ptr es:[si]
    mov byte ptr ds:[di], al
    inc di
    inc si
    jmp read_filename_start

read_filename ENDP

to_hex proc near
    mov ah, 0h
    mov bl, 10h
    div bl
    
    cmp al, 9d
    jle numb

    sub al, 0Ah
    add al, 'a'
    jmp out1
numb:
    add al, '0'
out1:
    push ax
    mov ah, 2
    mov dl, al
    int 21h
    
    pop ax

    cmp ah, 9d
    jle numb2
    sub ah, 0Ah
    add ah, 'a'
    jmp out2
numb2:
    add ah, '0'
out2:
    mov dl, ah
    mov ah, 2
    int 21h
    
    ret
to_hex endp

print_line_no proc near
    push si
    push cx

    mov ah, 2
    mov dl, ' '
    int 21h

    mov dl, 0B3h
    int 21h

    lea si, line + 3
    mov cx, 4
print_line_no_loop:
    mov ax, ds:[si]
    dec si
    call to_hex

    loop print_line_no_loop

    mov dl, 0B3h
    mov ah, 2
    int 21h

    mov dl, ' '
    int 21h

    add word ptr line[0], LINE_SIZE
    jnc skip_line_increment
    add word ptr line[1], 1
skip_line_increment:

    pop cx
    pop si
    ret
print_line_no endp

print_end_line proc near
    mov dl, 0B3h
    mov ah, 2
    int 21h

    lea si, line_buffer

    push cx
    mov cx, LINE_SIZE
print_ascii:
    mov al, byte ptr ds:[si]
    inc si

    cmp al, 20h
    jl skip_ascii
    cmp al, 7Eh
    jg skip_ascii

    mov dl, al
    jmp ascii_continue
skip_ascii:
    mov dl, ' '
ascii_continue:
    mov ah, 2
    int 21h
    loop print_ascii

    mov dl, 0B3h
    mov ah, 2
    int 21h

    mov dl, 0Dh
    int 21h

    mov dl, 0Ah
    int 21h

    pop cx

    ret
print_end_line endp

print_last_line proc near
    mov ax, si
    sub ax, offset line_buffer
    mov cx, LINE_SIZE
    sub cx, ax
    mov dl, ' '
    mov ah, 2
filler:
    mov byte ptr ds:[si], ' '
    inc si
    
    int 21h
    int 21h
    int 21h

    loop filler
    ret
print_last_line endp

print_file_name proc near
    lea si, sourcef
    mov ah, 2
print_file_name_start:
    mov dl, byte ptr ds:[si]
    cmp dl, 0
    je print_file_name_exit
    inc si
    int 21h

    jmp print_file_name_start
print_file_name_exit:
    ret
print_file_name endp

print_file_header proc near
    ; Top row
    mov dl, ' '
    mov ah, 2
    int 21h

    mov dl, 0DAh
    int 21h

    mov cx, 8
    call print_line

    mov dl, 0C2h
    int 21h

    mov ax, LINE_SIZE
    mov bx, 3h
    mul bx
    mov cx, ax
    inc cx
    call print_line

    mov dl, 0C2h
    int 21h

    mov cx, LINE_SIZE
    call print_line

    mov dl, 0BFh
    int 21h

    mov dl, 0Dh
    int 21h

    mov dl, 0Ah
    int 21h

    ; Middle row
    
    mov dl, ' '
    mov ah, 2
    int 21h

    mov dl, 0B3h
    int 21h

    lea dx, byte_no
    mov ah, 9h
    int 21h

    mov ah, 2
    mov dl, 0B3h
    int 21h

    lea dx, file_name
    mov ah, 9h
    int 21h

    call print_file_name

    mov ax, LINE_SIZE
    mov bx, 3h
    mul bx
    inc ax

    mov cx, ax
    mov ax, si
    sub ax, offset sourcef

    sub cx, ax
    sub cx, 7
    mov dl, ' '
    call print_repeat

    mov ah, 2
    mov dl, 0B3h
    int 21h

    lea dx, ascii
    mov ah, 9h
    int 21h

    mov cx, LINE_SIZE
    sub cx, 7
    mov dl, ' '
    call print_repeat

    mov dl, 0B3h
    int 21h

    mov dl, 0Dh
    int 21h

    mov dl, 0Ah
    int 21h

    ; Bottom row
    mov dl, ' '
    mov ah, 2
    int 21h

    mov dl, 0C3h
    int 21h

    mov cx, 8
    call print_line

    mov dl, 0C5h
    int 21h

    mov ax, LINE_SIZE
    mov bx, 3h
    mul bx
    mov cx, ax
    inc cx
    call print_line

    mov dl, 0C5h
    int 21h

    mov cx, LINE_SIZE
    call print_line

    mov dl, 0B4h
    int 21h

    mov dl, 0Dh
    int 21h

    mov dl, 0Ah
    int 21h

    ret
print_file_header endp

print_line proc near
    mov dl, 0C4h
    call print_repeat

    ret
print_line endp

print_repeat proc near
    mov ah, 2
print_repeat_loop:
    int 21h
    loop print_repeat_loop

    ret
print_repeat endp

print_file_footer proc near
    mov dl, ' '
    mov ah, 2
    int 21h

    mov dl, 0C0h
    int 21h

    mov cx, 8
    call print_line

    mov dl, 0C1h
    int 21h

    mov ax, LINE_SIZE
    mov bx, 3h
    mul bx
    mov cx, ax
    inc cx
    call print_line

    mov dl, 0C1h
    int 21h

    mov cx, LINE_SIZE
    call print_line

    mov dl, 0D9h
    int 21h

    mov dl, 0Dh
    int 21h

    mov dl, 0Ah
    int 21h
    
    mov dl, 0Dh
    int 21h

    mov dl, 0Ah
    int 21h
    
    ret
print_file_footer endp

end start