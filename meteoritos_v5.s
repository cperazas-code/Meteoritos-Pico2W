/* Meteoritos: nave, meteorito, colisiones, marcador y menú para Raspberry Pi Pico 2 W. */
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
.word irq_timer0
/* Bloque IMAGE_DEF para arranque ARM desde flash. */
.word 0xffffded3, 0x10210142, 0x000001ff, 0, 0xab123579

.equ IN, 0x04
.equ TIMER0, 0x400b0000
.equ I2C0, 0x40090000
.equ PERIODO_US, 33333
.equ AVISO_CUADRO, 0x20000408
.equ TIEMPO_ENVIO, 0x2000040c
.equ FPS_INICIO, 1040
.equ FPS_CUADROS, 1044
.equ FPS_DECIMAS, 1048

.global reset
.thumb_func
reset:
    cpsid i
    ldr r0, =0xe000ed08
    ldr r1, =0x10000000
    str r1, [r0]
    dsb sy
    isb sy
    bl configurar_reloj

    ldr r0, =0x40023000      /* RESETS_RESET, alias CLR. */
    ldr r1, =0x00800250      /* TIMER0, PADS_BANK0, IO_BANK0 e I2C0. */
    str r1, [r0]
    ldr r0, =0x40020008
1:  ldr r2, [r0]
    ands r2, r1
    cmp r2, r1
    bne 1b

    ldr r5, =0xd0000000
    ldr r0, =0x40038024      /* PADS_BANK0 GPIO8 y GPIO9. */
    movs r1, #0x5a           /* Entrada habilitada, pull-up, sin aislamiento. */
    str r1, [r0]
    str r1, [r0, #4]
    ldr r0, =0x40028044      /* IO_BANK0 GPIO8_CTRL y GPIO9_CTRL. */
    movs r1, #3              /* Función I2C0 para GP8 y GP9. */
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
    bl configurar_timer
    bl configurar_i2c
    ldr r0, =2000000
    bl espera
    adr.w r1, configuracion
    movs r0, #0
    adr.w r2, ventana_total
    subs r2, r2, r1        /* Longitud exacta de los comandos de inicio. */
    bl i2c_bloque

    ldr r11, =0x20000000     /* Framebuffer OLED de 1024 bytes. */
    bl limpiar_buffer
    movs r0, #24
    movs r1, #2
    adr.w r2, texto_menu
    movs r3, #10
    bl dibujar_texto
    movs r0, #28
    movs r1, #4
    adr.w r2, texto_inicio
    movs r3, #9
    bl dibujar_texto
    bl enviar_cuadro
    bl esperar_click

nueva_partida:
    movs r0, #0
    strh r0, [r11, #1028]
    str r0, [r11, #FPS_CUADROS]
    str r0, [r11, #FPS_DECIMAS]

    movs r6, #60            /* X inicial. */
    movs r7, #6             /* La nave empieza cerca del borde inferior. */
    movs r0, #16
    strb r0, [r11, #1024]  /* Columna del meteorito. */
    movs r0, #1
    strb r0, [r11, #1025]  /* Página del meteorito. */
    movs r0, #0
    strb r0, [r11, #1026]  /* Contador de ciclos entre caídas. */
    ldr r0, =0x4001006c
    movw r1, #0x840
    str r1, [r0]
    ldr r0, =0x40023000
    movs r1, #1
    str r1, [r0]             /* Quitar reset del ADC con su reloj activo. */
    ldr r0, =0x400a0000
    movs r1, #1
    str r1, [r0]

    bl renderizar
    bl activar_alarma

bucle:
    bl esperar_cuadro
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
4:  bl revisar_colision
    ldrb r3, [r11, #1026]
    adds r3, #1
    strb r3, [r11, #1026]
    cmp r3, #8
    blo pintar
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
    bl renderizar
    b bucle

.thumb_func
renderizar:
    push {r3, lr}
    bl limpiar_buffer
    bl dibujar_puntaje
    bl dibujar_fps
    bl dibujar_meteorito
    mov r0, r6
    mov r1, r7
    adr.w r2, nave
    bl dibujar_ocho
    bl enviar_cuadro
    cbnz r0, 1f
    bl contar_cuadro
1:
    pop {r3, pc}

/* Registrar solo transferencias completas que terminan sin error. */
.thumb_func
contar_cuadro:
    ldr r0, =TIMER0
    ldr r0, [r0, #0x28]
    ldr r1, [r11, #FPS_CUADROS]
    cbz r1, 2f
    adds r1, #1
    str r1, [r11, #FPS_CUADROS]
    cmp r1, #31
    bne 3f

    /* Entre el primer cuadro y el 31 hay 30 intervalos. */
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
2:  str r0, [r11, #FPS_INICIO]
    movs r1, #1
    str r1, [r11, #FPS_CUADROS]
3:  bx lr

/* Fxx.x en la esquina superior derecha. */
.thumb_func
dibujar_fps:
    push {r6, r7, r8, lr}
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
    bl detener_alarma
    bl limpiar_buffer
    movs r0, #28
    movs r1, #3
    adr.w r2, texto_fin
    movs r3, #9
    bl dibujar_texto
    bl dibujar_puntaje
    bl enviar_cuadro
    bl esperar_click
    b nueva_partida

/* Esperar primero que se suelte SW y luego un clic nuevo. */
.thumb_func
esperar_click:
1:  ldr r0, [r5, #IN]
    tst r0, #(1 << 22)
    beq 1b
2:  ldr r0, [r5, #IN]
    tst r0, #(1 << 22)
    bne 2b
    bx lr

/* r0 = X, r1 = página, r2 = glifos, r3 = cantidad de caracteres. */
.thumb_func
dibujar_texto:
    push {r3, r6, r7, r8, r9, lr}
    mov r6, r0
    mov r7, r1
    mov r8, r2
    mov r9, r3
1:  mov r0, r6
    mov r1, r7
    mov r2, r8
    bl dibujar_ocho
    adds r6, #8
    add r8, #8
    subs r9, #1
    bne 1b
    pop {r3, r6, r7, r8, r9, pc}

.thumb_func
limpiar_buffer:
    mov r1, r11
    movs r0, #0
    movw r2, #256
1:  str r0, [r1], #4
    subs r2, #1
    bne 1b
    bx lr

.thumb_func
enviar_cuadro:
    push {r3, r6, r7, lr}
    ldr r6, =TIMER0
    ldr r7, [r6, #0x28]
    movs r0, #0
    adr.w r1, ventana_total
    movs r2, #6
    bl i2c_bloque
    cbnz r0, 1f
    movs r0, #0x40
    mov r1, r11
    movw r2, #1024
    bl i2c_bloque
1:  ldr r1, [r6, #0x28]
    subs r1, r1, r7
    cbz r0, 2f
    mov r1, #-1              /* Error de I2C: medida inválida. */
2:  ldr r2, =TIEMPO_ENVIO
    str r1, [r2]
    pop {r3, r6, r7, pc}

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
    add r0, r0, r1, lsl #7
    add r0, r0, r11
    movs r1, #8
1:  ldrb r3, [r2], #1
    strb r3, [r0], #1
    subs r1, #1
    bne 1b
    bx lr

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
etiqueta_f:
    .byte 0, 0, 0x7f, 0x09, 0x09, 0x01, 0, 0
punto_fps:
    .byte 0, 0, 0x40, 0, 0, 0, 0, 0
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
texto_menu:
    .byte 0x00, 0x00, 0x7f, 0x0e, 0x0e, 0x7f, 0x00, 0x00
    .byte 0x00, 0x00, 0x7f, 0x49, 0x49, 0x49, 0x00, 0x00
    .byte 0x00, 0x01, 0x01, 0x7f, 0x01, 0x01, 0x00, 0x00
    .byte 0x00, 0x00, 0x7f, 0x49, 0x49, 0x49, 0x00, 0x00
    .byte 0x00, 0x00, 0x3e, 0x41, 0x41, 0x3e, 0x00, 0x00
    .byte 0x00, 0x00, 0x7f, 0x09, 0x19, 0x77, 0x40, 0x00
    .byte 0x00, 0x00, 0x41, 0x7f, 0x41, 0x00, 0x00, 0x00
    .byte 0x00, 0x01, 0x01, 0x7f, 0x01, 0x01, 0x00, 0x00
    .byte 0x00, 0x00, 0x3e, 0x41, 0x41, 0x3e, 0x00, 0x00
    .byte 0x00, 0x00, 0x26, 0x49, 0x49, 0x3a, 0x00, 0x00
texto_inicio:
    .byte 0x00, 0x00, 0x7f, 0x09, 0x09, 0x06, 0x00, 0x00
    .byte 0x00, 0x00, 0x3f, 0x40, 0x40, 0x3f, 0x00, 0x00
    .byte 0x00, 0x00, 0x7f, 0x40, 0x40, 0x40, 0x00, 0x00
    .byte 0x00, 0x00, 0x26, 0x49, 0x49, 0x3a, 0x00, 0x00
    .byte 0x00, 0x00, 0x78, 0x27, 0x27, 0x78, 0x00, 0x00
    .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    .byte 0x00, 0x00, 0x26, 0x49, 0x49, 0x3a, 0x00, 0x00
    .byte 0x00, 0x1f, 0x78, 0x04, 0x78, 0x1f, 0x00, 0x00
.balign 2

/* La Pico 2 W usa un cristal de 12 MHz. SYS y REF se fijan a XOSC. */
.thumb_func
configurar_reloj:
    ldr r0, =0x40048000
    movs r1, #47
    str r1, [r0, #0x0c]
    ldr r1, =0x00fabaa0
    str r1, [r0]
1:  ldr r1, [r0, #4]
    cmp r1, #0
    bpl 1b

    ldr r0, =0x40010000
    movs r1, #2
    str r1, [r0, #0x30]
2:  ldr r2, [r0, #0x38]
    tst r2, #4
    beq 2b
    movs r1, #0
    str r1, [r0, #0x3c]
3:  ldr r2, [r0, #0x44]
    tst r2, #1
    beq 3b
    mov.w r1, #0x10000
    str r1, [r0, #0x34]
    str r1, [r0, #0x40]
    bx lr

.thumb_func
configurar_timer:
    ldr r0, =0x40108018
    movs r1, #0
    str r1, [r0]
    movs r1, #12
    str r1, [r0, #4]
    movs r1, #1
    str r1, [r0]
    bx lr

.thumb_func
activar_alarma:
    ldr r0, =AVISO_CUADRO
    movs r1, #0
    str r1, [r0]
    ldr r0, =TIMER0
    ldr r2, [r0, #0x28]
    movw r3, #PERIODO_US
    adds r2, r2, r3
    str r2, [r0, #0x10]
    movs r1, #1
    str r1, [r0, #0x3c]
    str r1, [r0, #0x40]
    ldr r0, =0xe000e100
    str r1, [r0]
    cpsie i
    bx lr

.thumb_func
detener_alarma:
    cpsid i
    ldr r0, =TIMER0
    movs r1, #0
    str r1, [r0, #0x40]
    movs r1, #1
    str r1, [r0, #0x20]
    str r1, [r0, #0x3c]
    ldr r0, =0xe000e280
    str r1, [r0]
    bx lr

.thumb_func
irq_timer0:
    ldr r0, =TIMER0
    movs r1, #1
    str r1, [r0, #0x3c]
    ldr r2, [r0, #0x10]
    movw r3, #PERIODO_US
    adds r2, r2, r3
    str r2, [r0, #0x10]
    ldr r0, =AVISO_CUADRO
    str r1, [r0]
    dsb sy
    sev
    bx lr

.thumb_func
esperar_cuadro:
    ldr r0, =AVISO_CUADRO
1:  cpsid i
    ldr r1, [r0]
    cbnz r1, 2f
    cpsie i
    wfe
    b 1b
2:  movs r1, #0
    str r1, [r0]
    cpsie i
    bx lr

/* DW_apb_i2c en Fast Mode. HCNT y LCNT ajustados para SYS a 12 MHz. */
.thumb_func
configurar_i2c:
    ldr r0, =I2C0
    movs r1, #0
    str r1, [r0, #0x6c]
1:  ldr r2, [r0, #0x9c]
    tst r2, #1
    bne 1b
    movs r1, #0x65
    str r1, [r0]
    movs r1, #0x3c
    str r1, [r0, #4]
    movs r1, #12
    str r1, [r0, #0x1c]
    movs r1, #18
    str r1, [r0, #0x20]
    movs r1, #1
    str r1, [r0, #0xa0]
    str r1, [r0, #0x6c]
    bx lr

/* r0 = byte de control; r1 = datos; r2 = cantidad de bytes (positiva).
 * TX FIFO de hardware, STOP en el último byte. Límite: 40 ms por bloque.
 */
.thumb_func
i2c_bloque:
    push {r4, r6, r7, r8, r9, lr}
    ldr r4, =I2C0
    ldr r8, =TIMER0
    ldr r9, [r8, #0x28]
    mov r6, r1
    mov r7, r2
    ldr r3, [r4, #0x40]     /* Leer CLR_INTR. */
    str r0, [r4, #0x10]
1:  ldr r0, [r4, #0x34]     /* RAW_INTR_STAT. */
    tst r0, #0x40           /* TX_ABRT. */
    bne 4f
    ldr r1, [r8, #0x28]
    sub r1, r1, r9
    movw r2, #40000
    cmp r1, r2
    bhs 4f
    cmp r7, #0
    beq 3f
    ldr r1, [r4, #0x70]
    tst r1, #2              /* TFNF: hay espacio en TX FIFO. */
    beq 1b
    ldrb r0, [r6], #1
    subs r7, #1
    it eq
    orreq r0, #0x200        /* STOP en el último byte. */
    str r0, [r4, #0x10]
    b 1b
3:  tst r0, #0x200          /* STOP_DET. */
    beq 1b
    movs r0, #0
    pop {r4, r6, r7, r8, r9, pc}
4:  ldr r0, [r4, #0x54]     /* Limpiar TX_ABRT. */
    movs r0, #1
    pop {r4, r6, r7, r8, r9, pc}

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
