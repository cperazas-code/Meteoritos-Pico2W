.thumb_func
leer_adc:
/* Nota de código: Entrada r0: canal ADC (0 para GP26, 1 para GP27). Salida r0: muestra de 12 bits o valor centrado si vence la espera. */
    ldr r1, =0x400a0000
/* Nota de código: Ubicar el número de canal en AINSEL y mantener habilitado el ADC. */
    lsls r0, #12
    orr r0, #1
    str r0, [r1]
/* Nota de código: Esperar READY con un contador acotado para evitar que el juego se bloquee. */
    movw r3, #4096
1:  ldr r2, [r1]
    tst r2, #0x100
    bne 2f
    subs r3, #1
    bne 1b
    b 4f
/* Nota de código: Solicitar una conversión puntual y volver a esperar READY antes de leer RESULT. */
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

