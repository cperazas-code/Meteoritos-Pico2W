/* Punto de entrada. El orden conserva la disposición original en flash. */
/* Nota de código: Este es el archivo que se pasa al ensamblador. Cada .include inserta un módulo. El orden mantiene la tabla de vectores al inicio, conserva la disposición de la versión probada y deja el pool de literales al final. */
.include "arranque.s"
.include "juego.s"
.include "medicion_fps.s"
.include "colisiones.s"
.include "boton.s"
.include "renderizado.s"
.include "joystick_adc.s"
.include "sprites_y_glifos.s"
.include "reloj_y_timer.s"
.include "i2c_oled.s"
.include "retardo_arranque.s"
