extends Node
## Codificación/decodificación de códigos para compartir poderes de forma
## asíncrona (sin backend). El código es una cadena corta que el niño manda
## por WhatsApp; el receptor lo pega y recibe 1 poder aleatorio de esa
## mochila marcado como "regalo".
##
## Formato interno (JSON compacto → base64url → grupos de 4 con guiones):
##   {"v":1,"n":"Nombre","p":[1,2,3]}
## Prefijo visible: "MDP1-" (Mundos de Poder v1) para reconocer al pegar.

const PREFIX := "MDP1-"


func encode(player_name: String, powers: Array) -> String:
	var payload := {
		"v": 1,
		"n": player_name.substr(0, 12),
		"p": powers,
	}
	var json := JSON.stringify(payload)
	var b64 := Marshalls.utf8_to_base64(json)
	# base64url-safe
	b64 = b64.replace("+", "-").replace("/", "_").replace("=", "")
	return PREFIX + _group(b64, 4)


func decode(code: String) -> Dictionary:
	var clean := code.strip_edges().to_upper().replace(" ", "")
	if not clean.begins_with(PREFIX):
		return {"ok": false, "error": "Código no reconocido"}
	var body := clean.substr(PREFIX.length()).replace("-", "")
	# volver a base64 estándar
	body = body.replace("_", "/").replace("-", "+")
	# padding
	while body.length() % 4 != 0:
		body += "="
	var json := Marshalls.base64_to_utf8(body)
	if json == "":
		return {"ok": false, "error": "Código corrupto"}
	var parsed = JSON.parse_string(json)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "error": "Código inválido"}
	return {
		"ok": true,
		"version": int(parsed.get("v", 0)),
		"from": String(parsed.get("n", "?")),
		"powers": parsed.get("p", []),
	}


## Devuelve 1 poder aleatorio de la mochila del emisor. El receptor lo suma
## a sus regalos; el emisor no pierde nada (es una copia).
func pick_gift(decoded: Dictionary) -> int:
	if not decoded.get("ok", false):
		return -1
	var pool: Array = decoded.get("powers", [])
	if pool.is_empty():
		return -1
	randomize()
	return int(pool[randi() % pool.size()])


func _group(s: String, n: int) -> String:
	var out := ""
	for i in range(0, s.length(), n):
		if i > 0:
			out += "-"
		out += s.substr(i, n)
	# limitar a 5 grupos máximo para no ser un tocho
	var parts := out.split("-")
	if parts.size() > 5:
		parts.resize(5)
		out = "-".join(parts)
	return out
