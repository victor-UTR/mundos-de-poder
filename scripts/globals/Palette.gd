extends Node
## Paleta única del juego. Fuente de verdad para TODOS los colores.
##
## Antes había 97 literales `Color()` repartidos por 25 archivos, con cuatro
## grises "inactivo" distintos que deberían haber sido el mismo. Aquí se
## define cada color una vez y los scripts lo aplican en `_ready()`.
##
## OJO: los archivos .tscn NO pueden leer constantes de un autoload; guardan
## valores literales. Por eso los .tscn llevan los mismos colores copiados,
## pero sólo sirven de vista previa en el editor: en ejecución mandan los de
## aquí. Si cambias un color, cámbialo AQUÍ; el .tscn es cosmético.
##
## Criterio de diseño (esquema "intermedio"):
##   - El mundo es frío, oscuro y poco saturado: da ambiente y se queda atrás.
##   - Los actores y lo interactivo son cálidos y saturados: se leen al vuelo.
##   - Cuanto más lejos está algo, más oscuro y más azul.

# --- Cielo y fondo ---------------------------------------------------------
## Degradado del cielo, de arriba a abajo.
const SKY_TOP := Color("0a0c14")
const SKY_BOTTOM := Color("161a27")

## Las tres capas de ciudad del parallax, de lejos a cerca.
const CITY_FAR := Color("1b2030")
const CITY_MID := Color("232a3d")
const CITY_NEAR := Color("2d3548")

## Ventanas encendidas en los edificios lejanos. Poquísimas y apagadas: la
## ciudad está desolada, no viva.
const CITY_WINDOW := Color("4a5570")

# Aquí iba un CanvasModulate con tinte nocturno, y se descartó a propósito:
# multiplica TODOS los CanvasItem, así que oscurecería también al jugador y
# a los poderes, aplanando justo el contraste fondo/primer plano que esta
# paleta busca. El ambiente nocturno ya está en los colores del fondo.

# --- Geometría sólida ------------------------------------------------------
# Clave de legibilidad: TODO esto es más claro que cualquier capa de fondo,
# para que el niño distinga de un vistazo por dónde puede pisar.
const GROUND := Color("3d4559")
const GROUND_EDGE := Color("515b73")
const PLATFORM := Color("4a5468")
const PLATFORM_EDGE := Color("626e88")
## Plataforma oculta, sólo visible con el poder de Visión.
const PLATFORM_GHOST := Color(0.43, 0.80, 1.0, 0.10)
const PLATFORM_REVEALED := Color(0.43, 0.80, 1.0, 0.55)

# --- Jugador ---------------------------------------------------------------
## Ámbar cálido. Antes era #F2D966, casi idéntico al amarillo del poder EMP:
## el niño no distinguía su propio personaje del icono del poder.
const PLAYER := Color("ffb84d")
const PLAYER_HITBOX := Color(1.0, 0.85, 0.45, 0.55)
const SHIELD_RING := Color(0.43, 0.80, 1.0, 0.30)
const SHIELD_INNER := Color(0.55, 0.88, 1.0, 0.18)

# --- Enemigos --------------------------------------------------------------
const ENEMY_SCANNER := Color("e0455c")
const ENEMY_SCANNER_EYE := Color("ffe14d")
const ENEMY_SIREN := Color("3d8fd6")
const ENEMY_SIREN_LIGHT := Color("ffe14d")
const ENEMY_SIREN_ANTENNA := Color("ff6b4d")
const ENEMY_TURRET := Color("5c6478")
const ENEMY_TURRET_BARREL := Color("b32d2d")
const ENEMY_TURRET_BASE := Color("353b4a")
const LASER := Color("ff4d3d")

# --- Poderes ---------------------------------------------------------------
# Son las tres anclas cromáticas del juego: aparecen en el HUD, la mochila,
# el aura del escudo y las plataformas reveladas. No tocar a la ligera.
const POWER_VISION := Color("6ecbff")
const POWER_SHIELD := Color("5ee68a")
const POWER_EMP := Color("ffd84d")
const POWER_UNKNOWN := Color("9aa4b8")

# --- Puertas y servidores --------------------------------------------------
const DOOR_FRAME := Color(0.35, 0.52, 0.78, 0.35)
const DOOR_GLOW := Color(0.55, 0.82, 1.0, 0.25)
const SERVER_BODY := Color("59333d")
const SERVER_BODY_OFF := Color("365947")
const SERVER_LIGHT_LOCKED := Color("f04d4d")
const SERVER_LIGHT_READY := Color("5ee68a")

# --- Flashes de feedback ---------------------------------------------------
const FLASH_HURT := Color("ff4040")
const FLASH_KNOCKBACK := Color("ff9950")
const FLASH_SHIELD := Color("66ccff")
const FLASH_EMP := Color("ffff66")
const FLASH_STUN := Color("80ccff")
const FLASH_CHARGE := Color("ffffcc")

# --- Interfaz --------------------------------------------------------------
const UI_PANEL := Color(0.05, 0.06, 0.09, 0.80)
const UI_SLOT := Color("2b3142")
## Un único gris "apagado". Antes eran cuatro valores distintos casi iguales.
const UI_INACTIVE := Color("454d61")
const UI_TEXT := Color("e8ecf5")
const UI_TEXT_DIM := Color("9aa4b8")
const UI_TEXT_WARM := Color("ffe9b0")
const UI_TEXT_HILITE := Color("ffee80")
const UI_LIFE := Color("f04d4d")
const UI_PIP := Color("ffe14d")


## Color del poder por id. Centraliza lo que antes vivía en GameState.
func power(power_id: int) -> Color:
	match power_id:
		1: return POWER_VISION
		2: return POWER_SHIELD
		3: return POWER_EMP
	return POWER_UNKNOWN


## Mismo color con otra transparencia. Evita repetir Color(c.r, c.g, c.b, a).
func alpha(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)
