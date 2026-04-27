.386
.model flat, stdcall
option casemap:none

include \masm32\include\windows.inc
include \masm32\include\kernel32.inc
include \masm32\include\user32.inc
include \masm32\include\masm32.inc
include \masm32\macros\macros.asm

includelib \masm32\lib\kernel32.lib
includelib \masm32\lib\user32.lib
includelib \masm32\lib\masm32.lib
.data
    tablero db 200 dup(0)  ; 10 columnas x 20 filas
    ancho dd 10
    alto dd 20
    piezaActual dd 0
    fila dd 0
    columna dd 4
    velocidad dd 500
    rotacionActual dd 0  ; Nueva: estado de rotación (0-3)
    lastFall dd 0  ; Nueva: para timing de caída
    hConsole dd 0
    msgInicio db "Tetris en MASM32", 13, 10, 0
    msgGameOver db "GAME OVER!", 13, 10, 0
    cursorInfo CONSOLE_CURSOR_INFO <>  ; Para ocultar cursor
    
    ; Piezas con rotaciones (cada pieza tiene 4 matrices de 4x4)
    ; I-piece (línea)
    formaI dd offset formaI0, offset formaI1, offset formaI2, offset formaI3
    formaI0 db 0,0,0,0, 1,1,1,1, 0,0,0,0, 0,0,0,0
    formaI1 db 0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0
    formaI2 db 0,0,0,0, 0,0,0,0, 1,1,1,1, 0,0,0,0
    formaI3 db 0,1,0,0, 0,1,0,0, 0,1,0,0, 0,1,0,0
    
    ; O-piece (cuadrado)
    formaO dd offset formaO0, offset formaO1, offset formaO2, offset formaO3
    formaO0 db 1,1,0,0, 1,1,0,0, 0,0,0,0, 0,0,0,0
    formaO1 db 1,1,0,0, 1,1,0,0, 0,0,0,0, 0,0,0,0  ; Misma para todas las rotaciones
    formaO2 db 1,1,0,0, 1,1,0,0, 0,0,0,0, 0,0,0,0
    formaO3 db 1,1,0,0, 1,1,0,0, 0,0,0,0, 0,0,0,0
    
    ; T-piece
    formaT dd offset formaT0, offset formaT1, offset formaT2, offset formaT3
    formaT0 db 0,1,0,0, 1,1,1,0, 0,0,0,0, 0,0,0,0
    formaT1 db 0,1,0,0, 0,1,1,0, 0,1,0,0, 0,0,0,0
    formaT2 db 0,0,0,0, 1,1,1,0, 0,1,0,0, 0,0,0,0
    formaT3 db 0,1,0,0, 1,1,0,0, 0,1,0,0, 0,0,0,0
    
    ; S-piece
    formaS dd offset formaS0, offset formaS1, offset formaS2, offset formaS3
    formaS0 db 0,1,1,0, 1,1,0,0, 0,0,0,0, 0,0,0,0
    formaS1 db 0,1,0,0, 0,1,1,0, 0,0,1,0, 0,0,0,0
    formaS2 db 0,0,0,0, 0,1,1,0, 1,1,0,0, 0,0,0,0
    formaS3 db 1,0,0,0, 1,1,0,0, 0,1,0,0, 0,0,0,0
    
    ; Z-piece
    formaZ dd offset formaZ0, offset formaZ1, offset formaZ2, offset formaZ3
    formaZ0 db 1,1,0,0, 0,1,1,0, 0,0,0,0, 0,0,0,0
    formaZ1 db 0,0,1,0, 0,1,1,0, 0,1,0,0, 0,0,0,0
    formaZ2 db 0,0,0,0, 1,1,0,0, 0,1,1,0, 0,0,0,0
    formaZ3 db 0,1,0,0, 1,1,0,0, 1,0,0,0, 0,0,0,0
    
    ; J-piece
    formaJ dd offset formaJ0, offset formaJ1, offset formaJ2, offset formaJ3
    formaJ0 db 1,0,0,0, 1,1,1,0, 0,0,0,0, 0,0,0,0
    formaJ1 db 0,1,1,0, 0,1,0,0, 0,1,0,0, 0,0,0,0
    formaJ2 db 0,0,0,0, 1,1,1,0, 0,0,1,0, 0,0,0,0
    formaJ3 db 0,1,0,0, 0,1,0,0, 1,1,0,0, 0,0,0,0
    
    ; L-piece
    formaL dd offset formaL0, offset formaL1, offset formaL2, offset formaL3
    formaL0 db 0,0,1,0, 1,1,1,0, 0,0,0,0, 0,0,0,0
    formaL1 db 0,1,0,0, 0,1,0,0, 0,1,1,0, 0,0,0,0
    formaL2 db 0,0,0,0, 1,1,1,0, 1,0,0,0, 0,0,0,0
    formaL3 db 1,1,0,0, 0,1,0,0, 0,1,0,0, 0,0,0,0
    
    ; Array de piezas (ahora 7 piezas)
    formas dd offset formaI, offset formaO, offset formaT, offset formaS, offset formaZ, offset formaJ, offset formaL
    colores dd 1, 4, 2, 6, 5, 3, 7  ; Colores para cada pieza (azul, rojo, verde, amarillo, magenta, cyan, blanco)

.code

; Nueva función para rotar pieza
rotar_pieza proc
    mov eax, [rotacionActual]
    inc eax
    cmp eax, 4
    jl no_reset
    xor eax, eax  ; Reset a 0 si llega a 4
no_reset:
    mov [rotacionActual], eax
    call verificar_colision
    cmp eax, 1
    jne rotacion_ok
    ; Si colisión, revertir rotación
    mov eax, [rotacionActual]
    dec eax
    cmp eax, -1
    jne no_underflow
    mov eax, 3
no_underflow:
    mov [rotacionActual], eax
rotacion_ok:
    ret
rotar_pieza endp

; función para verificar colisión
verificar_colision proc
    mov esi, OFFSET formas
    mov eax, [piezaActual]
    mov esi, [esi + eax*4]  ; Obtener array de rotaciones
    mov eax, [rotacionActual]
    mov esi, [esi + eax*4]  ; Obtener forma actual
    xor ecx, ecx  ; i = 0 to 3
verificar_i:
    cmp ecx, 4
    je no_collision
    xor edx, edx  ; j = 0 to 3
verificar_j:
    cmp edx, 4
    je next_i
    ; check if forma[ecx*4 + edx] == 1
    mov eax, ecx
    shl eax, 2
    add eax, edx
    mov al, [esi + eax]
    cmp al, 1
    jne next_j
    ; calculate pos = (fila + ecx) * ancho + (columna + edx)
    mov ebp, [columna]
    add ebp, edx
    cmp ebp, 0
    jl collision
    cmp ebp, [ancho]
    jge collision
    mov eax, [fila]
    add eax, ecx
    cmp eax, [alto]
    jge collision
    imul eax, [ancho]
    add eax, ebp
    cmp tablero[eax], 0
    jne collision
next_j:
    inc edx
    jmp verificar_j
next_i:
    inc ecx
    jmp verificar_i
no_collision:
    mov eax, 0
    ret
collision:
    mov eax, 1
    ret
verificar_colision endp

; función para fijar pieza
fijar_pieza proc
    mov esi, OFFSET formas
    mov eax, [piezaActual]
    mov esi, [esi + eax*4]
    mov eax, [rotacionActual]
    mov esi, [esi + eax*4]
    xor ecx, ecx
fijar_i:
    cmp ecx, 4
    je fijar_end
    xor edx, edx
fijar_j:
    cmp edx, 4
    je fijar_next_i
    mov eax, ecx
    shl eax, 2
    add eax, edx
    mov al, [esi + eax]
    cmp al, 1
    jne fijar_next_j
    mov eax, [fila]
    add eax, ecx
    imul eax, [ancho]
    add eax, [columna]
    add eax, edx
    mov ebx, [piezaActual]
    inc ebx
    mov tablero[eax], bl
fijar_next_j:
    inc edx
    jmp fijar_j
fijar_next_i:
    inc ecx
    jmp fijar_i
fijar_end:
    ret
fijar_pieza endp

; función para borrar líneas completas
borrar_lineas proc
    cld
    mov ecx, [alto]
    dec ecx
scan_row:
    mov edx, ecx
    imul edx, [ancho]
    mov esi, edx
    mov ebx, [ancho]
check_line:
    mov al, tablero[esi]
    cmp al, 0
    je next_row
    inc esi
    dec ebx
    jnz check_line
    ; la fila está completa, desplazar todo hacia abajo
    mov eax, ecx
shift_rows:
    cmp eax, 0
    jl clear_top
    mov edx, eax
    dec edx
    imul edx, [ancho]
    mov esi, edx
    mov edi, eax
    imul edi, [ancho]
    lea esi, tablero[esi]
    lea edi, tablero[edi]
    mov ecx, [ancho]
    rep movsb
    dec eax
    jge shift_rows
clear_top:
    lea edi, tablero
    mov ecx, [ancho]
    xor al, al
    rep stosb
    jmp scan_row
next_row:
    dec ecx
    jge scan_row
    ret
borrar_lineas endp

; función para dibujar tablero
dibujar_tablero proc
    invoke SetConsoleCursorPosition, [hConsole], 0
    invoke SetConsoleTextAttribute, [hConsole], 7
    invoke StdOut, chr$("+--------------------+", 13, 10)
    xor ebx, ebx  ; r = 0 to 19
dibujar_r:
    cmp ebx, [alto]
    je dibujar_end
    invoke StdOut, chr$("|")
    xor edi, edi  ; c = 0 to 9
dibujar_c:
    cmp edi, [ancho]
    je dibujar_next_r
    push ebx
    push edi
    ; check if current piece covers this pos
    mov ebp, 0  ; is_piece = 0
    mov esi, OFFSET formas
    mov edx, [piezaActual]
    mov esi, [esi + edx*4]
    mov edx, [rotacionActual]
    mov esi, [esi + edx*4]  ; Usar rotación actual
    xor ecx, ecx  ; i
check_piece_i:
    cmp ecx, 4
    je check_done
    xor edx, edx  ; j
check_piece_j:
    cmp edx, 4
    je check_next_i
    mov eax, ecx
    shl eax, 2
    add eax, edx
    cmp byte ptr [esi + eax], 1
    jne check_next_j
    mov eax, [fila]
    add eax, ecx
    cmp eax, ebx
    jne check_next_j
    mov eax, [columna]
    add eax, edx
    cmp eax, edi
    jne check_next_j
    mov ebp, 1
    jmp check_done
check_next_j:
    inc edx
    jmp check_piece_j
check_next_i:
    inc ecx
    jmp check_piece_i
check_done:
    ; if is_piece or tablero[r*ancho + c]
    mov edx, ebx
    imul edx, ancho
    add edx, edi
    cmp tablero[edx], 0
    jne draw_block_from_board
    cmp ebp, 0
    je draw_space
draw_block:
    mov eax, [piezaActual]
    mov ecx, colores[eax*4]
    invoke SetConsoleTextAttribute, [hConsole], ecx
    invoke StdOut, chr$(219,219)
    jmp next_c
draw_block_from_board:
    mov al, tablero[edx]
    dec al
    movzx eax, al
    mov ecx, colores[eax*4]
    invoke SetConsoleTextAttribute, [hConsole], ecx
    invoke StdOut, chr$(219,219)
    jmp next_c
draw_space:
    invoke SetConsoleTextAttribute, [hConsole], 7
    invoke StdOut, chr$("  ")
next_c:
    pop edi
    pop ebx
    inc edi
    jmp dibujar_c
dibujar_next_r:
    invoke SetConsoleTextAttribute, [hConsole], 7
    invoke StdOut, chr$("|",13,10)
    inc ebx
    jmp dibujar_r
dibujar_end:
    invoke SetConsoleTextAttribute, [hConsole], 7
    invoke StdOut, chr$("+--------------------+", 13, 10)
    ret
dibujar_tablero endp

start:
    invoke AllocConsole
    invoke GetStdHandle, STD_OUTPUT_HANDLE
    mov [hConsole], eax

    ; Ocultar cursor
    invoke GetConsoleCursorInfo, [hConsole], addr cursorInfo
    mov cursorInfo.bVisible, FALSE
    invoke SetConsoleCursorInfo, [hConsole], addr cursorInfo

    ; Configuración de terminal
    invoke SetConsoleOutputCP, 437
    invoke SetConsoleCP, 437

    ; configuración de atributos de consola
    invoke SetConsoleTextAttribute, eax, 7
    invoke StdOut, addr msgInicio

    ; inicializar tablero
    invoke RtlZeroMemory, addr tablero, 200

    ; bucle principal
bucle_juego:
    ; elegir nueva pieza (ahora 7 piezas)
    invoke GetTickCount
    mov ecx, 7
    xor edx, edx
    div ecx
    mov piezaActual, edx
    mov fila, 0
    mov columna, 4
    mov rotacionActual, 0  ; Reset rotación
    invoke GetTickCount
    mov lastFall, eax  ; Inicializar timing por pieza

    ; verificar si puede colocar pieza
    call verificar_colision
    cmp eax, 1
    je game_over

    ; bucle de caída
bucle_caida:
    ; dibujar tablero
    call dibujar_tablero

    ; leer teclado
    invoke GetAsyncKeyState, 'A'
    test ax, 8000h
    jz check_d
    dec columna
    call verificar_colision
    cmp eax, 1
    jne check_d
    inc columna  ; revertir
check_d:
    invoke GetAsyncKeyState, 'D'
    test ax, 8000h
    jz check_g
    inc columna
    call verificar_colision
    cmp eax, 1
    jne check_g
    dec columna  ; revertir
check_g:
    invoke GetAsyncKeyState, 'G'
    test ax, 8000h
    jz check_s
    call rotar_pieza  ; Nueva: rotar al presionar G
check_s:
    invoke GetAsyncKeyState, 'S'
    test ax, 8000h
    jz check_fall
    inc fila
    call verificar_colision
    cmp eax, 1
    je revert_and_fijar
check_fall:
    ; check timing para caer
    invoke GetTickCount
    mov ebx, eax
    sub ebx, lastFall
    cmp ebx, velocidad
    jl no_fall
    mov lastFall, eax
    inc fila
    call verificar_colision
    cmp eax, 1
    je revert_and_fijar
no_fall:
    jmp bucle_caida

revert_and_fijar:
    dec fila
    call fijar_pieza
    call borrar_lineas
    jmp bucle_juego

game_over:
    invoke StdOut, addr msgGameOver
    invoke ExitProcess, 0

END start
