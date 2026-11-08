/* r7 y la página del meteorito deben coincidir.
 * Los dos sprites ocupan ocho columnas cada uno.
 */
.thumb_func
revisar_colision:
/* Nota de código: Comparar las páginas y después los intervalos horizontales semiabiertos [X, X+8). Si los bordes solo se tocan, no hay choque. */
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

/* Nota de código: La colisión transfiere el control a GAME OVER. Se desarma la alarma, se envía la pantalla con el puntaje final y un clic nuevo reinicia la partida. */
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

