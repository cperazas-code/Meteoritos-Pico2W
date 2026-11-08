/* Registrar solo transferencias completas que terminan sin error. */
.thumb_func
contar_cuadro:
/* Nota de código: Tomar la marca de TIMER0 tras un envío completo. Conservar la primera marca y acumular 30 intervalos entre cuadros. */
    ldr r0, =TIMER0
    ldr r0, [r0, #0x28]
    ldr r1, [r11, #FPS_CUADROS]
    cbz r1, 2f
    adds r1, #1
    str r1, [r11, #FPS_CUADROS]
    cmp r1, #31
    bne 3f

    /* Entre el primer cuadro y el 31 hay 30 intervalos. */
/* Nota de código: Obtener décimas de FPS con 30 × 1 000 000 × 10 dividido entre los microsegundos transcurridos. Limitar el resultado a las tres cifras disponibles. */
    ldr r2, [r11, #FPS_INICIO]
    subs r2, r0, r2
    cbz r2, 2f
    ldr r1, =300000000
    add r1, r1, r2, lsr #1  /* Redondear a una décima de FPS. */
    udiv r1, r1, r2
    movw r3, #999
    cmp r1, r3
    it hi
    movhi r1, r3
    str r1, [r11, #FPS_DECIMAS]
/* Nota de código: Usar el último cuadro como primera marca de la ventana siguiente. */
2:  str r0, [r11, #FPS_INICIO]
    movs r1, #1
    str r1, [r11, #FPS_CUADROS]
3:  bx lr

/* Fxx.x en la esquina superior derecha. */
.thumb_func
dibujar_fps:
    push {r6, r7, r8, lr}
/* Nota de código: Colocar la F en X=88 y el punto en X=112. Las cifras ocupan X=96, X=104 y X=120. */
    movs r0, #88
    movs r1, #0
    adr.w r2, etiqueta_f
    bl dibujar_ocho
    movs r0, #112
    movs r1, #0
    adr.w r2, punto_fps
    bl dibujar_ocho
    ldr r6, [r11, #FPS_DECIMAS]
    movs r7, #100
    mov r8, #96
/* Nota de código: Separar centenas, decenas y unidades del valor expresado en décimas y buscar cada glifo por su índice. */
1:  udiv r3, r6, r7
    mls r6, r3, r7, r6
    adr.w r2, digitos
    add r2, r2, r3, lsl #3
    mov r0, r8
    movs r1, #0
    bl dibujar_ocho
    add r8, #8
    cmp r8, #112
    it eq
    addeq r8, #8
    movs r3, #10
    udiv r7, r7, r3
    cmp r7, #0
    bne 1b
    pop {r6, r7, r8, pc}

