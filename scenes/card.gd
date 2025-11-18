extends PanelContainer

@export var title_text: String = ""
@export var body_text: String = ""
var oracle_id: String = ""
var oracle_data: Dictionary = {}
var dragging := false
var drag_offset := Vector2.ZERO

@onready var title_label: Label = $VBox/TitleBar/TitleLabel
@onready var body_label: RichTextLabel = $VBox/BodyLabel
@onready var roll_label: Label = $VBox/RollResult
@onready var notes_edit: TextEdit = $VBox/NotesEdit

func _ready() -> void:
    title_label.text = title_text
    body_label.text = body_text
    body_label.fit_content_height = true
    body_label.scroll_active = true
    body_label.bbcode_enabled = false

func set_card_content(title: String, body: String) -> void:
    title_text = title
    body_text = body
    title_label.text = title
    body_label.text = body

func set_oracle_data(data: Dictionary) -> void:
    oracle_data = data
    oracle_id = data.get("_id", "")

func _on_roll_button_pressed() -> void:
    if oracle_data.is_empty():
        roll_label.text = "No oracle attached"
        return
    if not oracle_data.has("rows"):
        roll_label.text = "Oracle has no rows"
        return
    var roll := randi_range(1, 100)
    var result_text := _find_row_result(roll)
    roll_label.text = "Roll: %d → %s" % [roll, result_text]

func _find_row_result(roll: int) -> String:
    for row in oracle_data.get("rows", []):
        var min_val: int = row.get("min", row.get("max", 0))
        var max_val: int = row.get("max", row.get("min", 0))
        if roll >= min_val and roll <= max_val:
            var parts := []
            if row.has("text"):
                parts.append(str(row["text"]))
            if row.has("text2"):
                parts.append(str(row["text2"]))
            return ": ".join(parts)
    return "No matching row"

func to_serialized_dict() -> Dictionary:
    return {
        "title": title_text,
        "body": body_text,
        "notes": notes_edit.text,
        "position": position,
        "oracle_id": oracle_id,
        "roll": roll_label.text,
    }

func apply_serialized_dict(data: Dictionary) -> void:
    set_card_content(data.get("title", "Card"), data.get("body", ""))
    notes_edit.text = data.get("notes", "")
    roll_label.text = data.get("roll", "")
    if data.has("position"):
        position = data["position"]

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            dragging = true
            drag_offset = event.position
            grab_focus()
        else:
            dragging = false
    elif event is InputEventMouseMotion and dragging:
        position += event.relative

