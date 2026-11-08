/* Nota de código: Inicializar una partida o reiniciarla después de una colisión. r6 guarda X de la nave y r7 su página vertical. El estado del meteorito y el marcador viven después de los 1024 bytes de píxeles. */
nueva_partida:
/* Nota de código: Poner a cero el marcador, el contador de cuadros y la lectura visible de FPS. */
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
/* Nota de código: Habilitar el reloj del ADC, liberar su reset y activar la conversión analógica antes de leer el joystick. */
    ldr r0, =0x4001006c
    movw r1, #0x840
    str r1, [r0]
    ldr r0, =0x40023000
    movs r1, #1
    str r1, [r0]             /* Quitar reset del ADC con su reloj activo. */
    ldr r0, =0x400a0000
    movs r1, #1
    str r1, [r0]

/* Nota de código: Mostrar el estado inicial y armar la alarma que marca el ritmo de la partida. */
    bl renderizar
    bl activar_alarma

bucle:
/* Nota de código: Esperar el aviso de TIMER0 antes de actualizar la nave y el meteorito. */
    bl esperar_cuadro
/* Nota de código: Leer el eje X. Por debajo de 1300 se resta y desde 2800 se suma. Entre ambos umbrales hay una zona muerta. X cambia de cuatro en cuatro y queda entre 0 y 120. */
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
/* Nota de código: Leer el eje Y con los mismos umbrales. La nave cambia de página y queda entre 1 y 7. La página 0 se reserva para el marcador y los FPS. */
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
/* Nota de código: Comprobar el choque tras mover la nave. Cada ocho actualizaciones, el meteorito avanza una página. */
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
/* Nota de código: Sumar un punto con tope de 999. Reaparecer en la página 1, desplazando la columna y volviendo al inicio al alcanzar el límite. */
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
/* Nota de código: Comprobar el choque de nuevo tras el avance del meteorito y dibujar el cuadro actual. */
    bl revisar_colision
    bl renderizar
    b bucle

.thumb_func
renderizar:
/* Nota de código: Construir el cuadro completo en RAM. Contabilizarlo para la medición únicamente si la transferencia I2C termina sin error. */
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

