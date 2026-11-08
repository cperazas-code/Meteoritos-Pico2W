/* Meteoritos: nave, meteorito, colisiones y marcador para Raspberry Pi Pico 2 W. */
.syntax unified
.cpu cortex-m33
.thumb
.section .text,"ax",%progbits
.balign 4
.word 0x20082000
.word reset
.rept 14
.word 0
.endr
/* Bloque IMAGE_DEF para arranque ARM desde flash. */
.word 0xffffded3, 0x10210142, 0x000001ff, 0, 0xab123579

.equ SDA, 0x100
.equ SCL, 0x200
.equ BUS, SDA | SCL
.equ IN, 0x04
.equ OUT_CLR, 0x20
.equ OE_SET, 0x38
.equ OE_CLR, 0x40

.global reset
.thumb_func
reset:
    cpsid i
    ldr r0, =0x40023000      /* RESETS_RESET, alias CLR. */
    movw r1, #0x240          /* IO_BANK0 y PADS_BANK0. */
    str r1, [r0]
    ldr r0, =0x40020008
1:  ldr r2, [r0]
    ands r2, r1
    cmp r2, r1
    bne 1b

    ldr r5, =0xd0000000
    movw r0, #BUS
    str r0, [r5, #OE_CLR]
    str r0, [r5, #OUT_CLR]
    ldr r0, =0x40038024      /* PADS_BANK0 GPIO8 y GPIO9. */
    movs r1, #0x5a           /* Entrada habilitada, pull-up, sin aislamiento. */
    str r1, [r0]
    str r1, [r0, #4]
    ldr r0, =0x40028044      /* IO_BANK0 GPIO8_CTRL y GPIO9_CTRL. */
    movs r1, #5              /* Función SIO. */
    str r1, [r0]
    str r1, [r0, #8]

    /* GP22: botón activo en bajo. GP26 y GP27: entradas analógicas. */
    ldr r0, =0x4003805c
    movs r1, #0x5a
    str r1, [r0]
    movs r1, #0
    str r1, [r0, #16]
    str r1, [r0, #20]
    ldr r0, =0x400280b4
    movs r1, #5
    str r1, [r0]
    movs r4, #0x78           /* OLED confirmada en 0x3C. */
    ldr r0, =2000000
    bl espera
    adr.w r1, configuracion
    movs r0, #0
    adr.w r2, ventana_total
    subs r2, r2, r1        /* Longitud exacta de los comandos de inicio. */
    bl i2c_bloque

    /* Limpieza inicial: ventana completa y 1024 bytes a cero. */
    ldr r11, =0x20000000
    mov r1, r11
    movs r0, #0
    movw r2, #256
1:  str r0, [r1], #4
    subs r2, #1
    bne 1b
nueva_partida:
    bl limpiar_oled
    movs r0, #0
    strh r0, [r11, #1028]
    bl dibujar_puntaje

    movs r6, #60            /* X inicial. */
    movs r7, #6             /* La nave empieza cerca del borde inferior. */
    movs r0, #16
    strb r0, [r11, #1024]  /* Columna del meteorito. */
    movs r0, #1
    strb r0, [r11, #1025]  /* Página del meteorito. */
    movs r0, #0
    strb r0, [r11, #1026]  /* Contador de ciclos entre caídas. */
    bl dibujar_meteorito

    mov r0, r6
    mov r1, r7
    adr.w r2, nave
    bl dibujar_ocho

    ldr r0, =0x4001006c
    movw r1, #0x840
    str r1, [r0]
    ldr r0, =0x40023000
    movs r1, #1
    str r1, [r0]             /* Quitar reset del ADC con su reloj activo. */
    ldr r0, =0x400a0000
    movs r1, #1
    str r1, [r0]

bucle:
    mov r8, r6              /* Guardar la posición anterior. */
    mov r9, r7
    movs r0, #0
    bl leer_adc
    movw r1, #1300
    cmp r0, r1
    bhs 1f
    cmp r6, #0
    it ne
    subne r6, #4
    b 2f
1:  movw r1, #2800
    cmp r0, r1
    blo 2f
    cmp r6, #120
    it lo
    addlo r6, #4
2:  movs r0, #1
    bl leer_adc
    movw r1, #1300
    cmp r0, r1
    bhs 3f
    cmp r7, #1
    it hi
    subhi r7, #1
    b 4f
3:  movw r1, #2800
    cmp r0, r1
    blo 4f
    cmp r7, #7
    it lo
    addlo r7, #1
4:  ldrb r3, [r11, #1026]
    adds r3, #1
    strb r3, [r11, #1026]
    cmp r3, #4
    beq actualizar
    cmp r6, r8
    bne actualizar
    cmp r7, r9
    beq pausa_joystick

actualizar:
    bl revisar_colision
    mov r0, r8
    mov r1, r9
    mov r2, r11
    bl dibujar_ocho         /* Borrar la posición anterior de la nave. */

    ldrb r3, [r11, #1026]
    cmp r3, #4
    bne pintar
    ldrb r0, [r11, #1024]
    ldrb r1, [r11, #1025]
    mov r2, r11
    bl dibujar_ocho         /* Borrar la posición anterior del meteorito. */
    movs r0, #0
    strb r0, [r11, #1026]
    ldrb r1, [r11, #1025]
    adds r1, #1
    cmp r1, #8
    blo guardar_pagina

    /* Al salir por abajo, reaparece arriba en otra columna. */
    ldrh r0, [r11, #1028]
    movw r1, #999
    cmp r0, r1
    it lo
    addlo r0, #1
    strh r0, [r11, #1028]
    bl dibujar_puntaje
    movs r1, #1
    ldrb r0, [r11, #1024]
    adds r0, #28
    cmp r0, #120
    it hi
    subhi r0, #124
    strb r0, [r11, #1024]
guardar_pagina:
    strb r1, [r11, #1025]

pintar:
    bl revisar_colision
    bl dibujar_meteorito
    mov r0, r6
    mov r1, r7
    adr.w r2, nave
    bl dibujar_ocho

pausa_joystick:
    ldr r0, =1100000
    bl espera
    b bucle

/* r7 y la página del meteorito deben coincidir.
 * Los dos sprites ocupan ocho columnas cada uno.
 */
.thumb_func
revisar_colision:
    ldrb r1, [r11, #1025]
    cmp r7, r1
    bne 1f
    ldrb r0, [r11, #1024]
    adds r1, r0, #8
    cmp r6, r1
    bhs 1f
    adds r1, r6, #8
    cmp r0, r1
    blo fin_partida
1:  bx lr

fin_partida:
    bl limpiar_oled
    adr.w r6, texto_fin
    movs r7, #28
1:  mov r0, r7
    movs r1, #3
    mov r2, r6
    bl dibujar_ocho
    adds r6, #8
    adds r7, #8
    cmp r7, #100
    blo 1b
    bl dibujar_puntaje

    /* Esperar primero que se suelte SW y luego un clic nuevo. */
2:  ldr r0, [r5, #IN]
    tst r0, #(1 << 22)
    beq 2b
3:  ldr r0, [r5, #IN]
    tst r0, #(1 << 22)
    bne 3b
    b nueva_partida

.thumb_func
limpiar_oled:
    push {r3, lr}
    movs r0, #0
    adr.w r1, ventana_total
    movs r2, #6
    bl i2c_bloque
    movs r0, #0x40
    mov r1, r11
    movw r2, #1024
    bl i2c_bloque

    pop {r3, pc}

.thumb_func
dibujar_puntaje:
    push {r6, r7, r8, lr}
    movs r0, #0
    movs r1, #0
    adr.w r2, etiqueta_p
    bl dibujar_ocho
    ldrh r6, [r11, #1028]
    movs r7, #100
    mov r8, #8
1:  udiv r3, r6, r7
    mls r6, r3, r7, r6
    adr.w r2, digitos
    add r2, r2, r3, lsl #3
    mov r0, r8
    movs r1, #0
    bl dibujar_ocho
    add r8, #8
    movs r3, #10
    udiv r7, r7, r3
    cmp r7, #0
    bne 1b
    pop {r6, r7, r8, pc}

.thumb_func
dibujar_meteorito:
    ldrb r0, [r11, #1024]
    ldrb r1, [r11, #1025]
    adr.w r2, meteorito
    b dibujar_ocho

.thumb_func
leer_adc:
    ldr r1, =0x400a0000
    lsls r0, #12
    orr r0, #1
    str r0, [r1]
    movw r3, #4096
1:  ldr r2, [r1]
    tst r2, #0x100
    bne 2f
    subs r3, #1
    bne 1b
    b 4f
2:  orr r0, #4              /* START_ONCE. */
    str r0, [r1]
    movw r3, #4096
3:  ldr r2, [r1]
    tst r2, #0x100
    bne 5f
    subs r3, #1
    bne 3b
4:  movw r0, #2048          /* Sin conversión: tratar el eje como centrado. */
    bx lr
5:  ldr r0, [r1, #4]
    ubfx r0, r0, #0, #12
    bx lr

/* r0 = X, r1 = página, r2 = dirección de ocho bytes del sprite. */
.thumb_func
dibujar_ocho:
    push {r6, lr}
    sub sp, #8
    mov r6, r2
    movs r3, #0x21
    strb r3, [sp]
    strb r0, [sp, #1]
    adds r0, #7
    strb r0, [sp, #2]
    movs r3, #0x22
    strb r3, [sp, #3]
    strb r1, [sp, #4]
    strb r1, [sp, #5]
    movs r0, #0
    mov r1, sp
    movs r2, #6
    bl i2c_bloque
    movs r0, #0x40
    mov r1, r6
    movs r2, #8
    bl i2c_bloque
    add sp, #8
    pop {r6, pc}

.balign 4
configuracion:
    .byte 0xae, 0xd5, 0x80, 0xa8, 0x3f, 0xd3, 0x00
    .byte 0x40, 0x8d, 0x14, 0xda, 0x12, 0x81, 0x7f
    .byte 0xd9, 0xf1, 0xdb, 0x40, 0xa4, 0xa6, 0x20, 0x00, 0xaf
ventana_total:
    .byte 0x21, 0, 127, 0x22, 0, 7
nave:
    .byte 0x40, 0x60, 0x38, 0x1f, 0x1f, 0x38, 0x60, 0x40
meteorito:
    .byte 0x00, 0x18, 0x3c, 0x7e, 0x76, 0x3c, 0x18, 0x00
etiqueta_p:
    .byte 0x00, 0x00, 0x7f, 0x09, 0x09, 0x06, 0x00, 0x00
digitos:
    .byte 0x00, 0x00, 0x3e, 0x41, 0x49, 0x3e, 0x00, 0x00
    .byte 0x00, 0x00, 0x41, 0x7f, 0x40, 0x00, 0x00, 0x00
    .byte 0x00, 0x00, 0x61, 0x71, 0x59, 0x4e, 0x00, 0x00
    .byte 0x00, 0x00, 0x41, 0x49, 0x49, 0x36, 0x00, 0x00
    .byte 0x00, 0x00, 0x18, 0x16, 0x7f, 0x10, 0x00, 0x00
    .byte 0x00, 0x00, 0x4f, 0x49, 0x49, 0x31, 0x00, 0x00
    .byte 0x00, 0x00, 0x3e, 0x4b, 0x49, 0x39, 0x00, 0x00
    .byte 0x00, 0x00, 0x01, 0x61, 0x3d, 0x07, 0x00, 0x00
    .byte 0x00, 0x00, 0x36, 0x49, 0x49, 0x36, 0x00, 0x00
    .byte 0x00, 0x00, 0x4e, 0x49, 0x69, 0x3e, 0x00, 0x00
texto_fin:
    .byte 0x00, 0x00, 0x3e, 0x41, 0x49, 0x79, 0x00, 0x00
    .byte 0x00, 0x00, 0x78, 0x27, 0x27, 0x78, 0x00, 0x00
    .byte 0x00, 0x00, 0x7f, 0x0e, 0x0e, 0x7f, 0x00, 0x00
    .byte 0x00, 0x00, 0x7f, 0x49, 0x49, 0x49, 0x00, 0x00
    .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    .byte 0x00, 0x00, 0x3e, 0x41, 0x41, 0x3e, 0x00, 0x00
    .byte 0x00, 0x00, 0x0f, 0x70, 0x70, 0x0f, 0x00, 0x00
    .byte 0x00, 0x00, 0x7f, 0x49, 0x49, 0x49, 0x00, 0x00
    .byte 0x00, 0x00, 0x7f, 0x09, 0x19, 0x77, 0x40, 0x00
.balign 2

.macro pausa
    movw r0, #480
    bl espera
.endm

.thumb_func
i2c_bloque:
    push {r6, r7, r8, lr}
    mov r8, r0              /* Control: 0x00 comandos, 0x40 datos. */
    mov r6, r1
    mov r7, r2
    movw r0, #BUS
    str r0, [r5, #OE_CLR]
    pausa
    movw r0, #SDA
    str r0, [r5, #OE_SET]
    pausa
    movw r0, #SCL
    str r0, [r5, #OE_SET]

    mov r0, r4
    bl byte_i2c
    cbnz r0, 1f
    mov r0, r8
    bl byte_i2c
    cbnz r0, 1f
2:  ldrb r0, [r6], #1
    bl byte_i2c
    cbnz r0, 1f
    subs r7, #1
    bne 2b

1:  mov r8, r0
    movw r0, #SDA
    str r0, [r5, #OE_SET]
    pausa
    movw r0, #SCL
    str r0, [r5, #OE_CLR]
    pausa
    movw r0, #SDA
    str r0, [r5, #OE_CLR]
    pausa
    mov r0, r8
    pop {r6, r7, r8, pc}

.thumb_func
byte_i2c:
    push {r3, r6, r7, lr}
    mov r6, r0
    movs r7, #8
1:  movw r0, #SDA
    tst r6, #0x80
    ite eq
    streq r0, [r5, #OE_SET]
    strne r0, [r5, #OE_CLR]
    pausa
    movw r0, #SCL
    str r0, [r5, #OE_CLR]
    pausa
    movw r0, #SCL
    str r0, [r5, #OE_SET]
    lsls r6, #1
    subs r7, #1
    bne 1b

    movw r0, #SDA           /* Soltar SDA y leer ACK en el noveno pulso. */
    str r0, [r5, #OE_CLR]
    pausa
    movw r0, #SCL
    str r0, [r5, #OE_CLR]
    pausa
    ldr r6, [r5, #IN]
    movw r0, #SCL
    str r0, [r5, #OE_SET]
    and r0, r6, #SDA
    pop {r3, r6, r7, pc}

.thumb_func
espera:
    ldr r1, =0xe000e010
    movs r2, #0
    str r2, [r1]
    subs r0, #1
    str r0, [r1, #4]
    str r2, [r1, #8]
    movs r2, #5
    str r2, [r1]
1:  ldr r2, [r1]
    tst r2, #0x10000
    beq 1b
    bx lr
.ltorg
