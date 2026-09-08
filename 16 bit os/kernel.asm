[org 0x8000]

start:
    call clear_screen
    mov si, WELCOME_MSG
    call print_string

login_loop:
    mov si, PASS_PROMPT
    call print_string
    
    mov di, password_buffer
    call read_string_hidden     
    
    mov si, password_buffer
    mov di, CORRECT_PASS
    call strcmp
    jc login_success

    mov si, PASS_ERR
    call print_string
    jmp login_loop

login_success:
    mov si, LOGIN_OK_MSG
    call print_string

main_loop:
    mov si, PROMPT
    call print_string
    
    call read_string
    
    ; Compare input with commands
    mov si, input_buffer
    mov di, CMD_INFO
    call strcmp
    jc do_info

    mov si, input_buffer
    mov di, CMD_CLEAR
    call strcmp
    jc do_clear
    
    mov si, input_buffer
    mov di, CMD_HELP
    call strcmp
    jc do_help
    
    mov si, input_buffer
    mov di, CMD_CAT
    call strcmp
    jc do_cat

    mov si, input_buffer
    mov di, CMD_CPUID
    call strcmp
    jc do_cpuid
    
    mov si, input_buffer
    mov di, CMD_REBOOT
    call strcmp
    jc do_reboot

    ; Unknown command
    mov si, ERR_MSG
    call print_string
    jmp main_loop

do_info:
    mov si, INFO_MSG
    call print_string
    jmp main_loop

do_clear:
    call clear_screen
    jmp main_loop
    
do_help:
    mov si, HELP_MSG
    call print_string
    jmp main_loop

do_cat:
    mov si, FILE_DATA
    call print_string
    jmp main_loop

do_cpuid:
    mov eax, 0
    cpuid
    mov [cpu_vendor + 0], ebx
    mov [cpu_vendor + 4], edx
    mov [cpu_vendor + 8], ecx
    mov byte [cpu_vendor + 12], 0

    mov si, CPU_MSG
    call print_string
    mov si, cpu_vendor
    call print_string
    mov si, NEWLINE
    call print_string
    jmp main_loop
    
do_reboot:
    jmp 0xFFFF:0x0000

; --- Helper Functions ---

clear_screen:
    mov ah, 0x06
    mov al, 0x00
    mov bh, 0x0A                ; Light Green on Black
    mov cx, 0x0000
    mov dx, 0x184F
    int 0x10
    
    mov ah, 0x02
    mov bh, 0x00
    mov dx, 0x0000
    int 0x10
    ret

print_string:
    mov ah, 0x0e
.loop:
    lodsb
    cmp al, 0
    je .done
    int 0x10
    jmp .loop
.done:
    ret

read_string:
    mov di, input_buffer
.loop:
    mov ah, 0x00
    int 0x16                    
    cmp al, 0x0d                
    je .done
    cmp al, 0x08                
    je .backspace
    
    stosb
    mov ah, 0x0e
    int 0x10
    jmp .loop

.backspace:
    cmp di, input_buffer
    je .loop
    dec di
    mov byte [di], 0
    mov ah, 0x0e
    mov al, 0x08
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 0x08
    int 0x10
    jmp .loop

.done:
    mov byte [di], 0
    mov si, NEWLINE
    call print_string
    ret

read_string_hidden:
    mov di, password_buffer
.loop:
    mov ah, 0x00
    int 0x16
    cmp al, 0x0d
    je .done
    cmp al, 0x08
    je .backspace
    
    stosb
    mov ah, 0x0e
    mov al, '*'                 
    int 0x10
    jmp .loop

.backspace:
    cmp di, password_buffer
    je .loop
    dec di
    mov byte [di], 0
    mov ah, 0x0e
    mov al, 0x08
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 0x08
    int 0x10
    jmp .loop

.done:
    mov byte [di], 0
    mov si, NEWLINE
    call print_string
    ret

strcmp:
    push si
    push di
.loop:
    mov al, [si]
    mov bl, [di]
    cmp al, bl
    jne .notequal
    cmp al, 0
    je .equal
    inc si
    inc di
    jmp .loop
.notequal:
    clc
    pop di
    pop si
    ret
.equal:
    stc
    pop di
    pop si
    ret

; --- Data Section ---

WELCOME_MSG:   db '=== *MYRA* === SECURE 16-BIT KERNEL v2.0 ===', 13, 10, 0
PASS_PROMPT:   db 'Enter Password (root): ', 0
CORRECT_PASS:  db 'root', 0
PASS_ERR:      db 'Access Denied. Try again.', 13, 10, 0
LOGIN_OK_MSG:  db 'Access Granted. Welcome, BOSS!', 13, 10, 0

PROMPT:        db 'OS> ', 0
NEWLINE:       db 13, 10, 0
INFO_MSG:      db 'Kernel v2.0 - Protected Real Mode Session', 13, 10, 0
HELP_MSG:      db 'Commands: info, clear, cat, cpuid, help, reboot', 13, 10, 0
FILE_DATA:     db 'Sector Data: System integrity 100% operational.', 13, 10, 0
CPU_MSG:       db 'CPU Vendor: ', 0
ERR_MSG:       db 'Unknown command. Type help.', 13, 10, 0

CMD_INFO:      db 'info', 0
CMD_CLEAR:     db 'clear', 0
CMD_HELP:      db 'help', 0
CMD_CAT:       db 'cat', 0
CMD_CPUID:     db 'cpuid', 0
CMD_REBOOT:    db 'reboot', 0

cpu_vendor:      times 16 db 0
password_buffer: times 32 db 0
input_buffer:    times 64 db 0