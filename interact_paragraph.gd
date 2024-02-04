@tool
class_name InteractParagraph extends Control

class WordRectInfo:
	var text: String
	var rect: Rect2
	var start: int
	var end: int

class ColorRange:
	var start: int
	var end: int
	var color: Color

@export var text_font: Font:
	get:
		return _font
	set(value):
		_font = value
		_font_id = _font.get_rids()[0]
		_try_update_paragraph()

@export var font_size: int:
	get:
		return _font_size
	set(value):
		_font_size = value
		_try_update_paragraph()

@export_multiline var text: String:
	get:
		return _text
	set(value):
		_text = value
		_try_update_paragraph()

@export var default_color: Color:
	get:
		return _def_color
	set(value):
		_def_color = value
		for i in _buffer_glyph_color.size():
			_buffer_glyph_color[i] = _get_char_color(_buffer_glyph_start[i]).to_rgba32()
		queue_redraw()

@export_enum("Left", "Center", "Right", "Fill") var alignment: int:
	get:
		return _alignment
	set(value):
		_alignment = value
		_try_update_paragraph()

@export_enum("Top", "Middle", "Bottom") var vertical_alignment: int:
	get:
		return _ver_alignment
	set(value):
		_ver_alignment = value
		_try_update_paragraph()

@export var line_spacing: float:
	get:
		return _line_spacing
	set(value):
		_line_spacing = value
		_try_update_paragraph()

@export var preview_words_rect: bool:
	get:
		return _show_words_rect
	set(value):
		_show_words_rect = value
		queue_redraw()

@export var show_text_bg: bool:
	get:
		return _show_text_bg
	set(value):
		_show_text_bg = value
		queue_redraw()

@export var text_bg_color: Color:
	get:
		return _text_bg_color
	set(value):
		_text_bg_color = value
		queue_redraw()

@export var text_bg_margin: float:
	get:
		return _text_bg_margin
	set(value):
		_text_bg_margin = value
		queue_redraw()

var _color_ranges: Array[ColorRange]

var _font: Font
var _font_size: int
var _def_color: Color
var _text: String
var _alignment: int = 0
var _ver_alignment: int = 0
var _line_spacing: float = 0.0
var _show_words_rect: bool
var _show_text_bg: bool
var _text_bg_color: Color = Color.TRANSPARENT
var _text_bg_margin: float

var _is_ready: bool
var _ts : TextServer
var _font_id : RID
var _words_rects: Array[WordRectInfo] = []
var text_rect: Rect2

var _buffer_glyph_pos: PackedVector2Array
var _buffer_glyph_idx: PackedInt32Array
var _buffer_glyph_color: PackedInt32Array
var _buffer_glyph_start: PackedInt32Array

func _ready()-> void:
	_is_ready = true
	_ts = TextServerManager.get_primary_interface()
	item_rect_changed.connect(_on_item_rect_changed)
	_update_paragraph()

func _try_update_paragraph()-> void:
	if _is_ready:
		_update_paragraph()

func _on_item_rect_changed()-> void:
	call_deferred("_update_paragraph")

func _update_paragraph()-> void:
	#clear all drawing buffers
	_buffer_glyph_pos.clear()
	_buffer_glyph_idx.clear()
	_buffer_glyph_color.clear()
	_buffer_glyph_start.clear()
	_words_rects.clear()
	
	#Avoid font related errors
	if not _font or _font_size == 0:
		return
	
	#TextParagraph is used to generate the layout and lines
	var paragraph := TextParagraph.new()
	paragraph.add_string(_text, _font, _font_size)
	paragraph.width = size.x
	#For some reason, the egnerated lines are not affected by the HorizontalAlignment option
	#annd we need to align the lines manually
	paragraph.alignment = _alignment as HorizontalAlignment

	#calculate total lines height to align vertically
	var linesCount := paragraph.get_line_count()
	var height := _line_spacing * (linesCount - 1)
	for lineIdx in paragraph.get_line_count():
		var line := paragraph.get_line_rid(lineIdx)
		height += _ts.shaped_text_get_ascent(line) + _ts.shaped_text_get_descent(line)
	
	#Align the paragraph vertically
	var linePos := Vector2.ZERO
	match _ver_alignment:
		1:
			linePos.y = (size.y - height) / 2.0
		2:
			linePos.y = size.y - height
	
	for lineIdx in paragraph.get_line_count():
		#line is actually RID of an internal line object
		var line := paragraph.get_line_rid(lineIdx)
		var ascent := _ts.shaped_text_get_ascent(line)
		var descent := _ts.shaped_text_get_descent(line)
		var lineWidth := _ts.shaped_text_get_width(line)
		#jump to line base-line
		linePos.y += ascent
		
		var glyphs := _ts.shaped_text_get_glyphs(line)
		var glyphPos := linePos
		#align the line horizontaly using line width and contaol width
		match _alignment:
			1:
				glyphPos.x += (size.x - lineWidth) / 2.0
			2:
				glyphPos.x += size.x - lineWidth
		#store the line start x
		var curWordX := glyphPos.x
		var curWordCharStart := -1
		var curWordCharEnd := 0
		for iGlyph in glyphs.size():
			var glyph := glyphs[iGlyph]
			#_ts.font_draw_glyph(_font_id, get_canvas_item(), _font_size, glyphPos, glyph.index, Color.WHITE)
			_buffer_glyph_pos.append(glyphPos)
			_buffer_glyph_idx.append(glyph.index)
			_buffer_glyph_color.append(_get_char_color(glyph.start).to_rgba32())
			_buffer_glyph_start.append(glyph.start)
			var gryphFlags : TextServer.GraphemeFlag = glyph.flags
			var is_valid := gryphFlags & TextServer.GRAPHEME_IS_VALID != 0
			var advance : float = glyph.advance
			var is_rtl := gryphFlags & TextServer.GRAPHEME_IS_RTL != 0
			var is_space := gryphFlags & TextServer.GRAPHEME_IS_SPACE != 0
			#print("glyph s: %s ,e: %s ,t: %s" % [glyph.start, glyph.end, glyphText])
			#Update word start and end character position
			if is_valid and not is_space:
				if curWordCharStart == -1:
					if is_rtl:
						curWordCharEnd = glyph.end
					else:
						curWordCharStart = glyph.start
				if is_rtl:
					curWordCharStart = glyph.start
				else:
					curWordCharEnd = glyph.end
			#Generate a word when we hit a space or end of the line
			if is_space or iGlyph == glyphs.size() - 1:
				var endAdvance := 0.0 if is_space else advance
				if curWordCharStart != -1:
					var wordInfo := WordRectInfo.new()
					wordInfo.text = _text.substr(curWordCharStart, curWordCharEnd - curWordCharStart)
					if is_rtl:
						wordInfo.rect = Rect2(glyphPos.x + endAdvance, linePos.y - ascent, curWordX - glyphPos.x - endAdvance, ascent + descent).abs()
					else:
						wordInfo.rect = Rect2(curWordX, linePos.y - ascent, glyphPos.x - curWordX + endAdvance, ascent + descent)
					wordInfo.start = curWordCharStart
					wordInfo.end = curWordCharEnd
					_words_rects.append(wordInfo)
					curWordCharStart = -1
					if _words_rects.size() == 1:
						text_rect = wordInfo.rect
					else:
						text_rect = rect2_union(text_rect, wordInfo.rect)
			glyphPos.x += advance
			#If the word has no start, advance word start x
			if curWordCharStart == -1:
				curWordX = glyphPos.x
		linePos.y += descent + _line_spacing
	queue_redraw()

func rect2_union(r1: Rect2, r2: Rect2)-> Rect2:
	return Rect2(minf(r1.position.x, r2.position.x), minf(r1.position.y, r2.position.y), maxf(r1.end.x, r2.end.x) - minf(r1.position.x, r2.position.x), maxf(r1.end.y, r2.end.y) - minf(r1.position.y, r2.position.y))

func _draw()-> void:
	if _show_text_bg:
		var rect := text_rect.grow(_text_bg_margin)
		draw_rect(rect, _text_bg_color, true)
	#Draw the already buffered charachters
	if _show_words_rect:
		for wordRect in _words_rects:
			draw_rect(wordRect.rect, Color.YELLOW, false, 1)
	for i in _buffer_glyph_idx.size():
		_ts.font_draw_glyph(_font_id, get_canvas_item(), _font_size, _buffer_glyph_pos[i], _buffer_glyph_idx[i], _buffer_glyph_color[i])

func set_color_range(start: int, end: int, color: Color)-> void:
	#Update the color of an already existing matching rane
	var alreadyExist := false
	for colorRange in _color_ranges:
		if colorRange.start == start and colorRange.end == end:
			colorRange.color = color
			alreadyExist = true
			break
	#Add new color range if not already exists
	if not alreadyExist:
		var colorRange := ColorRange.new()
		colorRange.start = start
		colorRange.end = end
		colorRange.color = color
		_color_ranges.append(colorRange)
	for i in _buffer_glyph_color.size():
		if _buffer_glyph_start[i] >= start and _buffer_glyph_start[i] <= end:
			_buffer_glyph_color[i] = color.to_rgba32()
	queue_redraw()

func clear_color_ranges()-> void:
	_color_ranges.clear()
	for i in _buffer_glyph_color.size():
		_buffer_glyph_color[i] = _def_color.to_rgba32()

func _get_char_color(charPos: int)-> Color:
	for colorRange in _color_ranges:
		if charPos >= colorRange.start and charPos <= colorRange.end:
			return colorRange.color
	return _def_color

func get_word_rect_at(pos: Vector2)-> WordRectInfo:
	pos -= position
	for wordRect in _words_rects:
		if wordRect.rect.has_point(pos):
			return wordRect
	return null

func set_word_rect_color(wordRect: WordRectInfo, color: Color)-> void:
	set_color_range(wordRect.start, wordRect.end, color)
