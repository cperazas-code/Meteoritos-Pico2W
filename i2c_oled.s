/* DW_apb_i2c en Fast Mode. HCNT y LCNT ajustados para SYS a 12 MHz. */
.thumb_func
configurar_i2c:
/* Nota de código: Desactivar el controlador antes de escribir los parámetros y esperar la confirmación en ENABLE_STATUS. */
    ldr r0, =I2C0
    movs r1, #0
    str r1, [r0, #0x6c]
1:  ldr r2, [r0, #0x9c]
    tst r2, #1
    bne 1b
/* Nota de código: Configurar I2C0 como maestro en modo rápido. La dirección de 7 bits de la OLED es 0x3C. */
    movs r1, #0x65
    str r1, [r0]
    movs r1, #0x3c
    str r1, [r0, #4]
/* Nota de código: Programar los contadores alto y bajo de SCL y el filtro de pulsos antes de habilitar el controlador. */
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
/* Nota de código: Preservar registros de trabajo y guardar la marca de tiempo inicial. El byte de control distingue comandos (0x00) de píxeles (0x40). */
    push {r4, r6, r7, r8, r9, lr}
    ldr r4, =I2C0
    ldr r8, =TIMER0
    ldr r9, [r8, #0x28]
    mov r6, r1
    mov r7, r2
    ldr r3, [r4, #0x40]     /* Leer CLR_INTR. */
    str r0, [r4, #0x10]
/* Nota de código: Supervisar un aborto y el límite de tiempo mientras se alimenta la cola de transmisión. */
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
/* Nota de código: Colocar un byte en la cola cuando hay espacio. Marcar el último con STOP para terminar la transacción. */
    ldrb r0, [r6], #1
    subs r7, #1
    it eq
    orreq r0, #0x200        /* STOP en el último byte. */
    str r0, [r4, #0x10]
    b 1b
/* Nota de código: Devolver r0=0 al detectar STOP. Si hubo aborto o expiró el límite, devolver r0=1. */
3:  tst r0, #0x200          /* STOP_DET. */
    beq 1b
    movs r0, #0
    pop {r4, r6, r7, r8, r9, pc}
4:  ldr r0, [r4, #0x54]     /* Limpiar TX_ABRT. */
    movs r0, #1
    pop {r4, r6, r7, r8, r9, pc}

