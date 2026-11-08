/* Esperar primero que se suelte SW y luego un clic nuevo. */
.thumb_func
esperar_click:
/* Nota de código: GP22 usa pull-up: nivel alto en reposo y bajo al presionar. Esperar la liberación evita que un clic previo active también el reinicio. */
1:  ldr r0, [r5, #IN]
    tst r0, #(1 << 22)
    beq 1b
2:  ldr r0, [r5, #IN]
    tst r0, #(1 << 22)
    bne 2b
    bx lr

