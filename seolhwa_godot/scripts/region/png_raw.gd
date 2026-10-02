# PNG 원시값 읽기 — Godot 이미지 로더는 16비트 PNG를 8비트로 줄이고(높이맵 정밀도 손실), 팔레트 PNG는 색으로 바꾼다.
# 그래서 PNG 머리(IHDR)만 고쳐 다시 Godot(libpng)에 넘긴다(필터 해제·압축 풀기는 엔진이 한다):
#   16비트 회색  → 8비트 회색+알파(픽셀당 2바이트, 필터 단위도 2바이트로 같음) → 바이트 [상위, 하위]
#   8비트 팔레트 → 8비트 회색(PLTE 버림) → 바이트 = 인덱스
# 반환: { w, h, bpp(1|2), bytes: PackedByteArray } (bpp=2면 값 = bytes[2i]·256 + bytes[2i+1])
extends RefCounted

static var _crc_table := PackedInt64Array()

static func load_gray(path: String) -> Dictionary:
	var buf := FileAccess.get_file_as_bytes(path)
	if buf.size() < 33:
		push_error("PNG 읽기 실패: " + path)
		return {}
	var pos := 8
	var w := 0; var h := 0; var depth := 0; var ctype := 0; var interlace := 0
	var idat := []
	while pos + 8 <= buf.size():
		var n := _u32(buf, pos)
		var typ := buf.slice(pos + 4, pos + 8).get_string_from_ascii()
		if typ == "IHDR":
			w = _u32(buf, pos + 8); h = _u32(buf, pos + 12)
			depth = buf[pos + 16]; ctype = buf[pos + 17]; interlace = buf[pos + 20]
		elif typ == "IDAT":
			idat.append(buf.slice(pos, pos + 12 + n))
		elif typ == "IEND":
			break
		pos += 12 + n
	var new_type := ctype; var bpp := 1
	if depth == 16 and ctype == 0: new_type = 4; bpp = 2
	elif depth == 8 and (ctype == 0 or ctype == 3): new_type = 0
	else:
		# 그 밖의 형식은 엔진 로더 그대로(8비트로 줄어든다)
		var img := Image.load_from_file(path)
		img.convert(Image.FORMAT_L8)
		return { w = img.get_width(), h = img.get_height(), bpp = 1, bytes = img.get_data() }
	var out := PackedByteArray([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])
	var ihdr := PackedByteArray()
	ihdr.append_array("IHDR".to_ascii_buffer())
	ihdr.append_array(_be32(w)); ihdr.append_array(_be32(h))
	ihdr.append_array(PackedByteArray([8, new_type, 0, 0, interlace]))
	out.append_array(_be32(13)); out.append_array(ihdr); out.append_array(_be32(_crc(ihdr)))
	for c in idat: out.append_array(c)
	out.append_array(PackedByteArray([0, 0, 0, 0, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82]))
	var im := Image.new()
	var err := im.load_png_from_buffer(out)
	if err != OK:
		push_error("PNG 다시 읽기 실패: %s (%s)" % [path, err])
		return {}
	var want := Image.FORMAT_LA8 if bpp == 2 else Image.FORMAT_L8
	if im.get_format() != want:
		push_error("PNG 형식이 예상과 다름: %s → %s" % [path, im.get_format()])
	return { w = w, h = h, bpp = bpp, bytes = im.get_data() }

static func _u32(b: PackedByteArray, p: int) -> int:
	return (b[p] << 24) | (b[p + 1] << 16) | (b[p + 2] << 8) | b[p + 3]

static func _be32(v: int) -> PackedByteArray:
	return PackedByteArray([(v >> 24) & 255, (v >> 16) & 255, (v >> 8) & 255, v & 255])

static func _crc(b: PackedByteArray) -> int:
	if _crc_table.is_empty():
		_crc_table.resize(256)
		for n in 256:
			var c := n
			for k in 8:
				c = (0xedb88320 ^ (c >> 1)) if (c & 1) else (c >> 1)
			_crc_table[n] = c
	var c := 0xffffffff
	for x in b:
		c = _crc_table[(c ^ x) & 0xff] ^ (c >> 8)
	return c ^ 0xffffffff
