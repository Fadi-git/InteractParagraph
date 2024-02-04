extends Control

@onready var _paragraph: InteractParagraph = $InteractParagraph

func _ready()-> void:
	pass # Replace with function body.


func _input(_event: InputEvent)-> void:
	if _event is InputEventMouseButton:
		var mbEvent := _event as InputEventMouseButton
		if mbEvent.is_released():
			var wordRect : InteractParagraph.WordRectInfo = _paragraph.get_word_rect_at(mbEvent.position)
			if wordRect:
				print("Word clicked: '%s'" % wordRect.text)
				_paragraph.set_word_rect_color(wordRect, Color.hex(randi() | 0x000000FF))
