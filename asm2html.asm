; ASCII symbols
ASCII_CR equ 0Dh ; carriage return
ASCII_LF equ 0Ah ; line feed
ASCII_TAB equ 09h ; horizontal tab
ASCII_FF equ 0Ch ; form feed
ASCII_SPACE equ 20h ; space ' '
ASCII_HELP_WORD equ 3F2Fh ; help string ("/?")
ASCII_QUOTE equ '"'
ASCII_BACKSLASH equ 5Ch

; Interrupt codes
INT_FUN_DISPATCH equ 21h

; Function disptach codes (interrupt 21h)
SYS_PRINT equ 09h
SYS_TERMINATE equ 4Ch
SYS_OUT equ 02h
SYS_OPEN_FILE equ 3Dh
SYS_CREATE_FILE equ 3Ch
SYS_READ_FILE equ 3Fh
SYS_WRITE_FILE equ 40h
SYS_CLOSE_FILE equ 3Eh

; Exit codes
EXIT_SUCCESS equ 0h
EXIT_FAILURE equ 1h

; File open modes
FILE_READ equ 0h

; Handy constants
CL_ARGUMENTS_START equ 81h
FILENAME_MAX_LENGTH equ 8
EXTENSION_MAX_LENGTH equ 3
BUFFER_SIZE equ 1000

; Booleans
TRUE equ 1h
FALSE equ 0h

; HTML generation constants
HTML_OPEN_SIZE equ 217
HTML_BODY_SIZE equ 174
HTML_CLOSE_SIZE equ 38
HTML_ROW_SIZE equ 33

.model small
.stack 100h

JUMPS

.data
    help db "Generates html page, displaying assmelby code (with syntax highlight)", ASCII_CR, ASCII_LF, ASCII_CR, ASCII_LF, \
            "Usage: asm2html [/?] [...files]", ASCII_CR, ASCII_LF, \
            ASCII_TAB, "/?         - display help", ASCII_CR, ASCII_LF, \
            ASCII_TAB, "[...files] - path to files to display.", ASCII_CR, ASCII_LF, \
            ASCII_TAB, "             Output will be written into [filename].html files.", ASCII_CR, ASCII_LF, \
            ASCII_TAB, "             If no files specified, input will be read from stdin.", ASCII_CR, ASCII_LF, '$' 
    filename_too_long_error db "Filename is too long - maximum allowed length is 8$"
    extension_too_long_error db "Extension is too long - maximum allowed length is 3$"
    invalid_filename_error db "Filename cannot contain dollar sign$"
    failed_to_open_file db "Failed to open file $"
    filename db FILENAME_MAX_LENGTH dup (?), '$'
    extension db EXTENSION_MAX_LENGTH dup (?), '$'
    source_filename db FILENAME_MAX_LENGTH dup (?), ?, EXTENSION_MAX_LENGTH dup (?), '$'
    desitantion_filename db FILENAME_MAX_LENGTH dup (?), ?, EXTENSION_MAX_LENGTH dup (?), '$'
    destination_file_handle dw ?
    source_file_handle dw ?
    buffer db BUFFER_SIZE dup (?), '$'

; HTML generation template
    html_open db       "<!DOCTYPE html>", ASCII_CR, ASCII_LF, \
                       "<html lang=", ASCII_QUOTE, "en", ASCII_QUOTE, ">", ASCII_CR, ASCII_LF, \
                       "<head>", ASCII_CR, ASCII_LF, \
                       "    <meta charset=", ASCII_QUOTE, "UTF-8", ASCII_QUOTE, ">", ASCII_CR, ASCII_LF, \
                       "    <meta http-equiv=", ASCII_QUOTE, "X-UA-Compatible", ASCII_QUOTE, " content=", ASCII_QUOTE, "IE=edge", ASCII_QUOTE, ">", ASCII_CR, ASCII_LF, \
                       "    <meta name=", ASCII_QUOTE, "viewport", ASCII_QUOTE, " content=", ASCII_QUOTE, "width=device-width, initial-scale=1.0", ASCII_QUOTE, ">", ASCII_CR, ASCII_LF, \
                       "    <title>"
    html_body db       "</title>", ASCII_CR, ASCII_LF, \
                       "<style>", ASCII_CR, ASCII_LF, \
                       "    .row {", ASCII_CR, ASCII_LF, \
                       "        white-space: pre;", ASCII_CR, ASCII_LF, \
                       "        font-family: monospace;", ASCII_CR, ASCII_LF, \
                       "    }", ASCII_CR, ASCII_LF, \
                       "</style>", ASCII_CR, ASCII_LF, \
                       "</head>", ASCII_CR, ASCII_LF, \
                       "<body>", ASCII_CR, ASCII_LF, \
                       "    <div class=", ASCII_QUOTE, "code", ASCII_QUOTE, ">", ASCII_CR, ASCII_LF, \
                       "        <div class=", ASCII_QUOTE, "row", ASCII_QUOTE, ">"
    html_close db      "</div>", ASCII_CR, ASCII_LF, \
                       "    </div>", ASCII_CR, ASCII_LF, \
                       "</body>", ASCII_CR, ASCII_LF, \
                       "</html>", ASCII_CR, ASCII_LF
    html_row db        "</div>", ASCII_CR, ASCII_LF, \
                       "        <div class=", ASCII_QUOTE, "row", ASCII_QUOTE, ">"
; HTML escape constants
    html_escape_lt db "&lt;$"
    html_escape_gt db "&gt;$"
    html_escape_quot db "&quot;$"
    html_escape_slash db "&#47;$"
    html_escape_backslash db "&#92;$"
; Syntax highlight variables
    is_comment db FALSE
    is_string db FALSE
    is_character db FALSE
.code

start:
    ; Swap data from data segment into extra segment
    mov dx, ds
    mov es, dx

    ; Put data into data segment
    mov dx, @data
    mov ds, dx

    ; Parse parameters
    mov si, CL_ARGUMENTS_START
    
    ;; Parse help argument

    ;;; Erase spaces from command arguments beginning
    call trim_start
    ;;; Read first 2 non-blank characters
    mov ax, word ptr es:[si]
    ;;; Show help, if argument is "/?"
    cmp ax, ASCII_HELP_WORD
    je show_help
    
    ;; Parse file arguments (if there are any)
    call read_filename
    cmp ds:[filename], '$'
    je show_help
transform_file:
    call create_html
    
    lea dx, source_filename
    mov ah, SYS_PRINT
    int INT_FUN_DISPATCH

    call read_filename
    cmp ds:[filename], '$'
    jne transform_file

; When program execution ended successfully
successful_exit:
    mov al, EXIT_SUCCESS
    mov ah, SYS_TERMINATE
    int INT_FUN_DISPATCH

; Print help for command
show_help:
    ; Print help message
    lea dx, help
    mov ah, SYS_PRINT
    int INT_FUN_DISPATCH
    
    jmp successful_exit

; Skip all blank characters from command line arguments
trim_start PROC near

    trim_start_loop:
        cmp byte ptr es:[si], ASCII_SPACE
        je trim_start_continue

        ret
    trim_start_continue:
        inc si
        jmp trim_start_loop

trim_start ENDP

; Read filename from command line arguments
read_filename PROC near
        ; Skip all whitespaces
        call trim_start
        lea di, filename
        push ax
        push cx

        mov ah, 0h
        mov cl, 0h
        mov ch, FILENAME_MAX_LENGTH
    read_filename_loop:
        inc ah

        ; If filename contains '$', it is considered invalid
        cmp byte ptr es:[si], '$'
        je read_filename_invalid_character
        ; If end of string occurred, filename is completely read
        cmp byte ptr es:[si], ASCII_CR
        je read_filename_end
        ; If a space occurred, filename is completely read
        cmp byte ptr es:[si], ' '
        je read_filename_end
        ; If a dot occurred, read extension
        cmp byte ptr es:[si], '.'
        je read_filename_extension
        ; If filename length is greater than FILENAME_MAX_LENGTH, print error
        cmp ch, ah 
        jl read_filename_error
    read_filename_next:
        ; Read next character and append it to the filename
        mov al, es:[si]
        mov ds:[di], al
        inc si
        inc di
        jmp read_filename_loop
    read_filename_end:
        ; End current string
        mov al, '$'
        mov ds:[di], al
        inc di
        ; If extension is empty, set it to "asm"
        cmp cl, 1h
        je read_filename_return
        lea di, extension
        mov al, 'a'
        mov ds:[di], al
        inc di
        mov al, 's'
        mov ds:[di], al
        inc di
        mov al, 'm'
        mov ds:[di], al
    read_filename_return:
        pop ax
        pop cx
        ret
    read_filename_extension:
        ; Check if already reading extension
        cmp cl, 1h
        je read_filename_next

        ; Increment index to skip dot
        inc si
        ; End filename string
        mov al, '$'
        mov ds:[di], al
        inc di
        ; Prepare state for reading extension
        lea di, extension
        mov ah, 0
        mov ch, EXTENSION_MAX_LENGTH
        mov cl, 1h
        jmp read_filename_loop
    read_filename_invalid_character:
        lea dx, invalid_filename_error
        jmp read_filename_error_end
    read_filename_error:
        ; Pick error message
        cmp cl, 1h
        je read_filename_extension_error
        lea dx, filename_too_long_error
        jmp read_filename_error_end
    read_filename_extension_error:
        lea dx, extension_too_long_error
    read_filename_error_end:

        ; Print error message
        mov ah, SYS_PRINT
        int INT_FUN_DISPATCH

        ; Failure exit
        mov al, EXIT_FAILURE
        mov ah, SYS_TERMINATE
        int INT_FUN_DISPATCH
read_filename ENDP

construct_full_filename PROC near
        
        ; Begin reading filename
        lea si, filename
        ; Flag, to determine if currently copying extension
        mov ah, 0h
    construct_full_filename_loop:
        ; Take next byte
        mov al, ds:[si]
        ; If current string fully copied, try to copy next part
        cmp al, '$'
        je construct_full_filename_copy_next
        mov ds:[di], al
        inc si
        inc di
        jmp construct_full_filename_loop
    ; Copy extension
    construct_full_filename_copy_next:
        ; Check, if extension is already copied        
        cmp ah, 0h
        mov ah, 1h
        jne construct_full_filename_exit

        ; If not, copy extension
        lea si, extension
        mov al, '.'
        mov ds:[di], al
        inc di
        jmp construct_full_filename_loop
    ; Finalize filename
    construct_full_filename_exit:
        ; End filename
        mov al, '$'
        inc di
        mov ds:[di], al
        
        ; Return
        ret
construct_full_filename ENDP

write_string_to_file PROC near
        mov si, dx
        mov cx, 0
    write_string_to_file_loop:    
        cmp byte ptr ds:[si], '$'
        je write_string_to_file_dump
        inc cx
        inc si
        jmp write_string_to_file_loop
    write_string_to_file_dump:
        mov ah, SYS_WRITE_FILE
        int INT_FUN_DISPATCH
        ret

write_string_to_file ENDP

highlight_buffer PROC near
        mov cx, ax
        lea di, buffer
    highlight_buffer_loop:
        ; Special character handling
        ;; EOL
        cmp byte ptr ds:[di], ASCII_CR
        je highlight_new_line
        cmp byte ptr ds:[di], ASCII_LF
        je highlight_buffer_continue
        ;; Escape characters
        cmp byte ptr ds:[di], '<'
        je highlight_escape_lt
        cmp byte ptr ds:[di], '>'
        je highlight_escape_gt
        cmp byte ptr ds:[di], '"'
        je highlight_escape_quot
        cmp byte ptr ds:[di], '/'
        je highlight_escape_slash
        cmp byte ptr ds:[di], ASCII_BACKSLASH
        je highlight_escape_backslash

        push cx

        ; Copy contents back to file
        mov ah, SYS_WRITE_FILE
        mov bx, destination_file_handle
        mov dx, di
        mov cx, 1
        int INT_FUN_DISPATCH
        
        pop cx
    highlight_buffer_continue:
        inc di
        loop highlight_buffer_loop

        ret
    highlight_new_line:
        push cx

        mov bx, destination_file_handle
        mov ah, SYS_WRITE_FILE
        lea dx, html_row
        mov cx, HTML_ROW_SIZE
        int INT_FUN_DISPATCH

        pop cx

        jmp highlight_buffer_continue
    highlight_escape_lt:
        lea dx, html_escape_lt

        jmp highlight_escape
    highlight_escape_gt:
        lea dx, html_escape_gt

        jmp highlight_escape
    highlight_escape_quot:
        lea dx, html_escape_quot

        jmp highlight_escape
    highlight_escape_slash:
        lea dx, html_escape_slash

        jmp highlight_escape
    highlight_escape_backslash:
        lea dx, html_escape_backslash

        jmp highlight_escape
    highlight_escape:
        mov bx, destination_file_handle
        push cx
        call write_string_to_file
        pop cx
        jmp highlight_buffer_continue
highlight_buffer ENDP

create_html PROC near
        push si
        lea di, source_filename
        call construct_full_filename

        ; open input file
        lea dx, source_filename
        mov al, FILE_READ
        mov ah, SYS_OPEN_FILE
        int INT_FUN_DISPATCH
        jc create_html_file_open_failure
        mov source_file_handle, ax

        ; create output file
        ;; construct filename
        lea di, extension
        mov al, 'h'
        mov ds:[di], al
        inc di
        mov al, 't'
        mov ds:[di], al
        inc di
        mov al, 'm'
        mov ds:[di], al
        
        lea di, desitantion_filename
        call construct_full_filename
        
        ;; create new file
        lea dx, desitantion_filename
        mov ah, SYS_CREATE_FILE
        mov cx, 0
        int INT_FUN_DISPATCH
        jc create_html_file_open_failure
        mov destination_file_handle, ax
        
        ;; write header
        mov ah, SYS_WRITE_FILE
        mov bx, destination_file_handle
        mov cx, HTML_OPEN_SIZE
        lea dx, html_open
        int INT_FUN_DISPATCH
    
        lea dx, source_filename
        call write_string_to_file

        mov ah, SYS_WRITE_FILE
        mov bx, destination_file_handle
        lea dx, html_body
        mov cx, HTML_BODY_SIZE
        int INT_FUN_DISPATCH
    create_html_file_reading_loop:
        ; Reading from input file
        mov bx, source_file_handle
        lea dx, buffer
        mov cx, BUFFER_SIZE
        mov ah, SYS_READ_FILE
        int INT_FUN_DISPATCH
        
        cmp ax, 0
        je create_html_file_end
        
        call highlight_buffer

        jmp create_html_file_reading_loop
    create_html_file_end:
        ; Write closing tag
        mov ah, SYS_WRITE_FILE
        mov bx, destination_file_handle
        lea dx, html_close
        mov cx, HTML_CLOSE_SIZE
        int INT_FUN_DISPATCH

        ; Close files
        mov bx, source_file_handle
        mov ah, SYS_CLOSE_FILE
        int INT_FUN_DISPATCH

        mov bx, destination_file_handle
        int INT_FUN_DISPATCH

        pop si
        ret
    create_html_file_open_failure:
        mov cx, dx
        ; Print error message
        lea dx, failed_to_open_file
        mov ah, SYS_PRINT
        int INT_FUN_DISPATCH

        mov dx, cx
        mov ah, SYS_PRINT
        int INT_FUN_DISPATCH

        ; Failure exit
        mov al, EXIT_FAILURE
        mov ah, SYS_TERMINATE
        int INT_FUN_DISPATCH
create_html ENDP

end start