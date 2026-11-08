/* Meteoritos: nave, meteorito, colisiones, marcador y menú para Raspberry Pi Pico 2 W. */
/* Nota de código: Directivas del ensamblador para Cortex-M33 en modo Thumb. El programa y sus constantes se enlazan en la sección de código de flash. */
.syntax unified
.cpu cortex-m33
.thumb
.section .text,"ax",%progbits
.balign 4
/* Nota de código: Tabla de vectores: valor inicial de SP, entrada reset, excepciones reservadas por este programa e IRQ 0 de TIMER0. */
.word 0x20082000
.word reset
.rept 14
.word 0
.endr
.word irq_timer0
/* Bloque IMAGE_DEF para arranque ARM desde flash. */
.word 0xffffded3, 0x10210142, 0x000001ff, 0, 0xab123579

/* Nota de código: Mapa compartido: IN es el desplazamiento de lectura de GPIO en SIO. TIMER0 e I2C0 son bases de periféricos. Los nombres de FPS son desplazamientos respecto al framebuffer en r11. */
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
/* Nota de código: Mantener las interrupciones enmascaradas mientras se inicializa la placa. Escribir la dirección de la tabla de vectores en VTOR y sincronizar antes de continuar. */
    cpsid i
    ldr r0, =0xe000ed08
    ldr r1, =0x10000000
    str r1, [r0]
    dsb sy
    isb sy
    bl configurar_reloj

/* Nota de código: Liberar los periféricos necesarios del reset y esperar a que todos indiquen disponibilidad en RESET_DONE. */
    ldr r0, =0x40023000      /* RESETS_RESET, alias CLR. */
    ldr r1, =0x00800250      /* TIMER0, PADS_BANK0, IO_BANK0 e I2C0. */
    str r1, [r0]
    ldr r0, =0x40020008
1:  ldr r2, [r0]
    ands r2, r1
    cmp r2, r1
    bne 1b

/* Nota de código: Mantener la base SIO en r5. Habilitar las entradas de GP8 y GP9 y asignar ambos pines a I2C0. */
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
/* Nota de código: Configurar la base de tiempo e I2C. La espera de arranque da tiempo a la OLED antes de enviar sus comandos. */
    bl configurar_timer
    bl configurar_i2c
    ldr r0, =2000000
    bl espera
/* Nota de código: Pasar a i2c_bloque el byte de control 0x00, el puntero de configuración y la longitud del bloque. */
    adr.w r1, configuracion
    movs r0, #0
    adr.w r2, ventana_total
    subs r2, r2, r1        /* Longitud exacta de los comandos de inicio. */
    bl i2c_bloque

/* Nota de código: r11 apunta al framebuffer. Componer el menú en RAM, enviarlo a la pantalla y esperar un clic del joystick. */
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

