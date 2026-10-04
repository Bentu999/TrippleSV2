class_name OrderedJson
extends RefCounted
## JSON writer that preserves Dictionary insertion order (Godot's JSON.stringify sorts keys).


static func stringify(value: Variant, indent: String = "  ") -> String:
	return _write(value, indent, 0)


static func _write(value: Variant, indent: String, depth: int) -> String:
	match typeof(value):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if value else "false"
		TYPE_INT:
			return str(value)
		TYPE_FLOAT:
			var f := float(value)
			if is_nan(f) or is_inf(f):
				return "0.0"
			# Godot str(1.0) -> "1.0"; ensure wholes keep a decimal point.
			var s := str(f)
			if not s.contains(".") and not s.contains("e") and not s.contains("E"):
				s += ".0"
			return s
		TYPE_STRING:
			return _escape_string(str(value))
		TYPE_ARRAY:
			return _write_array(value, indent, depth)
		TYPE_DICTIONARY:
			return _write_dict(value, indent, depth)
		_:
			return _escape_string(str(value))


static func _write_array(arr: Array, indent: String, depth: int) -> String:
	if arr.is_empty():
		return "[]"
	var pad := indent.repeat(depth + 1)
	var pad_close := indent.repeat(depth)
	var parts: PackedStringArray = PackedStringArray()
	for item in arr:
		parts.append(pad + _write(item, indent, depth + 1))
	return "[\n" + ",\n".join(parts) + "\n" + pad_close + "]"


static func _write_dict(dict: Dictionary, indent: String, depth: int) -> String:
	if dict.is_empty():
		return "{}"
	var pad := indent.repeat(depth + 1)
	var pad_close := indent.repeat(depth)
	var parts: PackedStringArray = PackedStringArray()
	for key in dict.keys():
		var k := _escape_string(str(key))
		var v := _write(dict[key], indent, depth + 1)
		parts.append("%s%s: %s" % [pad, k, v])
	return "{\n" + ",\n".join(parts) + "\n" + pad_close + "}"


static func _escape_string(s: String) -> String:
	var out := "\""
	for i in s.length():
		var ch := s[i]
		match ch:
			"\\":
				out += "\\\\"
			"\"":
				out += "\\\""
			"\b":
				out += "\\b"
			"\f":
				out += "\\f"
			"\n":
				out += "\\n"
			"\r":
				out += "\\r"
			"\t":
				out += "\\t"
			_:
				var code := ch.unicode_at(0)
				if code < 0x20:
					out += "\\u%04x" % code
				else:
					out += ch
	out += "\""
	return out
