# Meteoritos en ensamblador ARM

Videojuego para Raspberry Pi Pico 2 W (RP2350, Cortex-M33). Usa una OLED
SSD1306 de 128 × 64 en I²C (0x3C) y un joystick analógico de dos ejes con botón.

## Conexiones

| Señal | Pico 2 W | Pin físico |
|---|---|---:|
| OLED SDA | GP8 | 11 |
| OLED SCK | GP9 | 12 |
| OLED GND | GND | 13 |
| OLED VDD y joystick VCC | 3V3(OUT) | 36 |
| Joystick VRx | GP26 / ADC0 | 31 |
| Joystick VRy | GP27 / ADC1 | 32 |
| Joystick SW | GP22 | 29 |
| Joystick GND | AGND | 33 |

## Código y compilación

`src/main.s` incluye los módulos de arranque, juego, colisiones, joystick,
renderizado, medición de FPS, reloj, temporizador e I²C. Se ensamblan como
una unidad para conservar el orden de instrucciones y datos de la v5.

1. En Windows, extrae esta carpeta dentro de `arquitectura proyecto final`,
   junto a las carpetas `bin` de Arm GNU Toolchain y `picotool`.
2. Abre PowerShell dentro de `Meteoritos_Pico2W` y ejecuta:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\compilar.ps1
   ```

   Si las herramientas están en otro lugar, indica sus rutas con
   `-ArmBin` y `-PicotoolDir` al final del comando.
3. Con BOOTSEL presionado, conecta la Pico y copia `build/meteoritos.uf2`
   a la unidad RP2350. También se incluye el binario v5 probado en
   `firmware/meteoritos_v5.uf2`.

## Cómo jugar

Pulsa el joystick para comenzar. Mueve la nave en ambos ejes y esquiva los
meteoritos. Cada meteorito que sale por abajo suma un punto. Un choque
muestra GAME OVER y detiene la alarma de físicas. Pulsa el joystick
nuevamente para reiniciar. El indicador F muestra cuadros completos enviados
por segundo, redondeados a una décima.
