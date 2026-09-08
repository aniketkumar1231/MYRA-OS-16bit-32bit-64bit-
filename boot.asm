[org 0x7c00]

    mov [BOOT_DISK], dl         ; Store boot disk number

    mov bp, 0x9000              ; Set up stack
    mov sp, bp

    call load_kernel            ; Load expanded kernel from disk
    jmp 0x0000:0x8000           ; Jump to kernel entry

load_kernel:
    mov bx, 0x8000              ; Destination memory address
    mov dh, 4                   ; Read 4 sectors (2KB total)
    mov dl, [BOOT_DISK]         
    
    mov ah, 0x02                ; BIOS read sector function
    mov al, dh                  ; Sectors to read
    mov ch, 0x00                ; Cylinder 0
    mov dh, 0x00                ; Head 0
    mov cl, 0x02                ; Start at sector 2
    int 0x13                    
    jc disk_error               
    ret

disk_error:
    jmp $

BOOT_DISK: db 0

times 510-($-$$) db 0       
dw 0xaa55