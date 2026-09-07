# Catálogo de Poderes

Los IDs son enteros cortos para que quepan en los códigos de compartir.

| ID | Nombre     | Tecla | Efecto                                                    | Fuente (nivel 1)  |
|----|------------|-------|-----------------------------------------------------------|-------------------|
| 1  | Visión     | Q     | Revela plataformas y botones ocultos durante 6 s.         | Robot-Escáner     |
| 2  | Escudo     | Q     | Añade 1 carga; bloquea el próximo golpe recibido.         | Robot-Torreta     |
| 3  | Pulso EMP  | Q     | Aturde enemigos en radio de 120 px durante 2 s.           | Robot-Sirena      |

## Reglas de uso

- Solo hay **un poder activo** a la vez. Se cambia con `TAB`.
- El poder activo es el que se dispara con `Q`.
- Los poderes son **infinitos en uso** durante el Nivel 1 (sin cooldown
  para no frustrar). En Nivel 3 tendrán cooldown y consumirán "energía".

## Regla clave del juego (Nivel 3, futuro)

> Los poderes obtenidos solo se **activan** en el Nivel 3 si han sido
> compartidos o recibidos como regalo de otro jugador. Un poder que solo
> tienes tú, sin haberlo compartido, no se puede usar en el combate final.

Esto fuerza la mecánica social/didáctica del juego.

## Añadir un poder nuevo

1. Añadir entrada en el enum `Power` de `GameState.gd`.
2. Añadir metadatos en `POWER_INFO`.
3. Añadir caso en `_use_active_power()` de `Player.gd`.
4. Crear el enemigo que lo suelta y documentarlo aquí.
