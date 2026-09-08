## Encodes an IPv4 address + port into a short shareable code like "K7QMD-3XZPA".
## Pure static functions so they can be unit-tested without the network.
class_name JoinCode

const ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"  # 32 symbols, no 0/O/1/I
const LENGTH := 10  # 10 * 5 bits = 50 bits >= 48 needed

static func encode(ip: String, port: int) -> String:
	var parts := ip.split(".")
	if parts.size() != 4:
		return ""
	var value: int = 0
	for p in parts:
		value = (value << 8) | (int(p) & 0xFF)
	value = (value << 16) | (port & 0xFFFF)
	var chars := PackedStringArray()
	for i in LENGTH:
		chars.append(ALPHABET[value & 31])
		value >>= 5
	chars.reverse()
	var s := "".join(chars)
	return s.substr(0, 5) + "-" + s.substr(5, 5)

## Returns {"ip": String, "port": int} or an empty Dictionary if invalid.
static func decode(code: String) -> Dictionary:
	var clean := code.strip_edges().to_upper().replace("-", "").replace(" ", "")
	# Allow raw "ip:port" / "ip" / "localhost" for LAN testing.
	var raw := code.strip_edges()
	if raw.to_lower() == "localhost":
		return { "ip": "127.0.0.1", "port": 7777 }
	if raw.count(".") == 3:
		var ip := raw
		var port := 7777
		if ":" in raw:
			ip = raw.get_slice(":", 0)
			port = int(raw.get_slice(":", 1))
		return { "ip": ip, "port": port }
	if clean.length() != LENGTH:
		return {}
	var value: int = 0
	for ch in clean:
		var idx := ALPHABET.find(ch)
		if idx < 0:
			return {}
		value = (value << 5) | idx
	var port := value & 0xFFFF
	value >>= 16
	var octets: Array[int] = []
	for i in 4:
		octets.push_front(value & 0xFF)
		value >>= 8
	return { "ip": "%d.%d.%d.%d" % octets, "port": port }
