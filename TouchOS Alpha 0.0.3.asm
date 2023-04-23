	cpu 8086

stack:	equ 0x7700
line:	equ 0x7780
sector:	equ 0x7800
osbase:	equ 0x7a00
boot:	equ 0x7c00

entry_size:		equ 16
sector_size:	equ 512
max_entries:	equ sector_size/entry_size

	org osbase
start:
		xor ax,ax
		mov ds,ax
		mov es,ax
		mov ss,ax
		mov sp,stack

		cld
		mov si,boot
		mov di,osbase
		mov cx,sector_size
		rep movsb

		mov si,int_0x20
		mov di,0x0020*4
		mov cl,6
.load_vec
		movsw
		stosw
		loop .load_vec

ver_command:
		mov si,intro
		call output_string
		int int_restart

restart:
		cld
		push cs
		push cs
		push cs
		pop ds
		pop es
		pop ss
		mov sp,stack

		mov al,'$'
		call input_line

		cmp byte [si],0x00
		je restart

		mov di,commands

os11:
		mov al,[di]
		inc di
		and ax,0x00ff
		je os12
		xchg ax,cx
		push si
		rep cmpsb
		jne os14
		call word [di]
		jmp restart

os14:	add di,cx
		inc di
		inc di
		pop si
		jmp os11

os12:	mov bx,si
		mov di,boot
		int int_load_file
		jc os7
		jmp bx

os7:
		mov si,error_message
		call output_string
		int int_restart

del_command:
os22:
		mov bx,si
		lodsb
		cmp al,0x20
		je os22
		int int_delete_file
		jc os7
		ret

dir_command:
		call read_dir
		mov di,bx
os18:
		cmp byte [di],0
		je os17
		mov si,di
		call output_string
os17:	call next_entry
		jne os18
		ret

filename_length:
		push si
		xor cx,cx
.loop:
		lodsb
		inc cx
		cmp al,0
		jne .loop

		pop si
		mov di,sector
		ret

load_file:
		push di
		push es
		call find_file
		mov ah,0x02
shared_file:
		pop es
		pop bx
		jc ret_cf
		call disk

ret_cf:
		mov bp,sp
		rcl byte [bp+4],1
		iret

save_file:
		push di
		push es
		push bx
		int int_delete_file
		pop bx
		call filename_length

.find:	es cmp byte [di],0
		je .empty
		call next_entry
		jne .find
		jmp shared_file

.empty:	push di
		rep movsb
		call write_dir
		pop di
		call get_location
		mov ah,0x03
		jmp shared_file

delete_file:
		call find_file
		jc ret_cf
		mov cx,entry_size
		call write_zero_dir
		jmp ret_cf

find_file:
		push bx
		call read_dir
		pop si
		call filename_length
os6:
		push si
		push di
		push cx
		repe cmpsb
		pop cx
		pop di
		pop si
		je get_location
		call next_entry
		jne os6
		ret

next_entry:
		add di,byte entry_size
		cmp di,sector+sector_size
		stc
		ret

get_location:
		lea ax,[di-(sector-entrysize)]

		mov cl,4
		shl ax,cl
		inc ax
		xchg ax,cx
		ret

format_command:
		mov di,sector
		mov cx,sector_size
		call write_zero_dir
		mov bx,osbase
		dec cx
		jmp short disk

read_dir:
		push es
		pop es
		mov ah,0x02
		jmp short disk_dir

write_zero_dir:
		mov al,0
		rep stosb

write_dir:
		mov ah,0x03
disk_dir:
		mov bx,sector
		mov cx,0x0002

disk:
		push ax
		push bx
		push cx
		push es
		mov al,0x02
		xor dx,dx
		int 0x13
		pop es
		pop cx
		pop bx
		pop ax
		jc disk
		ret

input_line:
		int int_output_char
		mov si,line
		mov di,si
os1:	cmp al,0x08
		jne os2
		dec di
		dec di
os2:	int_input_key
		cmp al,0x0d
		jne os10
		mov al,0x00
os10:	stosb
		jne os1
		ret

input_key:
		mov ah,0x00
		int 0x16

output_char:
		cmp al,0x0d
		jne os3
		mov al,0x0a
		int int_output_char
		mov al,0x0d
os3:
		mov ah,0x0e
		mov bx,0x0007
		int 0x10
		iret

output_string:
		lodsb
		int int_output_char
		cmp al,0x00
		jne output_string
		mov al,0x0d
		int int_output_char
		ret

enter_command:
		mov di,boot
os23:	push di
		mov al,'h'
		call input_line
		pop di
		cmp byte [si],0
		je os20
os19:	call xdigit
		jnc 0s23
		mov cl,4
		shl al,cl
		xchg ax,cx
		call xdigit
		or al,cl
		stosb
		jmp os19
os20:
		mov al,'*'
		call input_line
		push si
		pop bx
		mov di_boot
		int int_save_file
		ret

xdigit:
		lodsb
		cmp al,0x00
		je os15
		sub al,0x30
		jc xdigit
		cmp al,0x0a
		jc os15
		sub al,0x07
		and al,0x0f
		stc
os15:
		ret

intro:
		db "TOUCHOS PUBLIC ALPHA 0.0.3",0

error_message:
		db "ERROR PLEASE RESTART",0

commands:
		db 3,"dir"
		dw dir_command
		db 6,"format"
		dw format_command
		db 5,"open"
        dw enter_command
        db 3,"del"
        dw del_command
        db 3,"ver"
        dw ver_command
        db 0

int_restart:            equ 0x20
int_input_key:          equ 0x21
int_output_char:        equ 0x22
int_load_file:          equ 0x23
int_save_file:          equ 0x24
int_delete_file:        equ 0x25

int_0x20:
		dw restart
		dw input_key
		dw output_char
		dw load_file
		dw save_file
		dw delete_file

		times 510-($-$$) db 0x4f
		db 0x55,0xaa