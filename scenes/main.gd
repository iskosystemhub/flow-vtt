extends Control

@export var rules_path: String = "res://starforged.json"
@export var card_scene: PackedScene

@onready var tree: Tree = $"Root Layout/MainArea/Sidebar/SidebarMargin/SidebarVBox/RuleTree"
@onready var status_label: Label = $"Root Layout/TopBar/StatusLabel"
@onready var card_layer: Control = $"Root Layout/MainArea/Board/BoardMargin/BoardArea/CardLayer"
@onready var reload_rules_button: Button = $"Root Layout/TopBar/ReloadRulesButton"
@onready var save_board_button: Button = $"Root Layout/TopBar/SaveBoardButton"
@onready var load_board_button: Button = $"Root Layout/TopBar/LoadBoardButton"

var rules_data: Dictionary = {}
var oracle_lookup: Dictionary = {}

func _ready() -> void:
    randomize()
    _connect_ui()
    _load_rules()
    _populate_rule_tree()

func _connect_ui() -> void:
    tree.item_activated.connect(_on_tree_item_activated)
    reload_rules_button.pressed.connect(_on_reload_rules)
    save_board_button.pressed.connect(_on_save_board)
    load_board_button.pressed.connect(_on_load_board)

func _load_rules() -> void:
    var file := FileAccess.open(rules_path, FileAccess.READ)
    if file == null:
        status_label.text = "Failed to load rules"
        return
    var json := JSON.parse_string(file.get_as_text())
    if typeof(json) != TYPE_DICTIONARY:
        status_label.text = "Invalid rules file"
        return
    rules_data = json
    status_label.text = "Rules loaded"
    _build_oracle_lookup()

func _build_oracle_lookup() -> void:
    oracle_lookup.clear()
    if not rules_data.has("oracles"):
        return
    for collection_key in rules_data["oracles"].keys().sorted():
        _collect_oracle_lookup(rules_data["oracles"][collection_key])

func _collect_oracle_lookup(node: Dictionary) -> void:
    if node.has("_id"):
        oracle_lookup[node["_id"]] = node
    if node.has("contents"):
        for child_key in node["contents"].keys().sorted():
            _collect_oracle_lookup(node["contents"][child_key])

func _populate_rule_tree() -> void:
    tree.clear()
    var root := tree.create_item()
    if rules_data.has("oracles"):
        var oracles_root := tree.create_item(root)
        oracles_root.set_text(0, "Oracles")
        _add_oracle_nodes(oracles_root, rules_data["oracles"])
    tree.update()

func _add_oracle_nodes(parent: TreeItem, contents: Dictionary) -> void:
    for key in contents.keys().sorted():
        var data: Dictionary = contents[key]
        var item := tree.create_item(parent)
        item.set_text(0, data.get("name", key.capitalize()))
        item.set_metadata(0, {"type": "oracle", "data": data})
        if data.has("oracle_type"):
            item.set_tooltip_text(0, data.get("oracle_type", ""))
        if data.has("contents"):
            _add_oracle_nodes(item, data["contents"])

func _on_tree_item_activated() -> void:
    var item := tree.get_selected()
    if item == null:
        return
    var meta: Dictionary = item.get_metadata(0)
    if meta.get("type", "") == "oracle":
        _spawn_oracle_card(meta["data"])

func _spawn_oracle_card(oracle_data: Dictionary) -> void:
    if card_scene == null:
        push_warning("Card scene not assigned")
        return
    var card := card_scene.instantiate()
    var title := oracle_data.get("name", "Oracle")
    var body := _format_oracle_text(oracle_data)
    card.position = _next_card_position()
    card.set_card_content(title, body)
    card.set_oracle_data(oracle_data)
    card_layer.add_child(card)
    status_label.text = "Added card: %s" % title

func _format_oracle_text(data: Dictionary) -> String:
    var lines: Array[String] = []
    if data.has("summary"):
        lines.append(str(data["summary"]))
    if data.has("rows"):
        for row in data["rows"]:
            var range_text := _row_range(row)
            var entry_text := row.get("text", "")
            if row.has("text2") and str(row["text2"]) != "":
                entry_text = "%s | %s" % [entry_text, row["text2"]]
            lines.append("%s: %s" % [range_text, entry_text])
    return "\n".join(lines)

func _row_range(row: Dictionary) -> String:
    var min_val: int = row.get("min", row.get("max", 0))
    var max_val: int = row.get("max", row.get("min", 0))
    return min_val == max_val ? str(min_val) : "%d-%d" % [min_val, max_val]

func _next_card_position() -> Vector2:
    var count := card_layer.get_child_count()
    var offset := 20 * count
    return Vector2(40 + offset, 40 + offset)

func _on_reload_rules() -> void:
    _load_rules()
    _populate_rule_tree()

func _on_save_board() -> void:
    var cards := []
    for child in card_layer.get_children():
        if child.has_method("to_serialized_dict"):
            cards.append(child.to_serialized_dict())
    var payload := {"cards": cards}
    var file := FileAccess.open("user://board.json", FileAccess.WRITE)
    if file == null:
        status_label.text = "Failed to save board"
        return
    file.store_string(JSON.stringify(payload, "  "))
    status_label.text = "Board saved to user://board.json"

func _on_load_board() -> void:
    var file := FileAccess.open("user://board.json", FileAccess.READ)
    if file == null:
        status_label.text = "No board file"
        return
    var data := JSON.parse_string(file.get_as_text())
    if typeof(data) != TYPE_DICTIONARY or not data.has("cards"):
        status_label.text = "Invalid board file"
        return
    _clear_board()
    for card_data in data["cards"]:
        _restore_card(card_data)
    status_label.text = "Board loaded"

func _restore_card(card_data: Dictionary) -> void:
    var card := card_scene.instantiate()
    card.apply_serialized_dict(card_data)
    if card_data.has("oracle_id") and oracle_lookup.has(card_data["oracle_id"]):
        card.set_oracle_data(oracle_lookup[card_data["oracle_id"]])
    card_layer.add_child(card)

func _clear_board() -> void:
    for child in card_layer.get_children():
        child.queue_free()

