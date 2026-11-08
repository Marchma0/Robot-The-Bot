extends SceneTree
## Vérifie les traductions (lancé par `tests/tools/run_tests.sh`) :
## - chaque texte passé à `tr("…")` dans `scripts/` a sa ligne dans `assets/translations/texts.csv` ;
## - chaque ligne du tableau a bien son texte anglais ;
## - en anglais, le jeu traduit vraiment (le tableau est chargé par le projet).
## Usage : Godot --headless --path . -s res://tests/tools/check_translations.gd

const TABLE: String = "res://assets/translations/texts.csv"

var _failures: int = 0


func _init() -> void:
	var keys: Dictionary = _read_table()
	var used: Dictionary = {}
	var regex: RegEx = RegEx.create_from_string("\\btr\\(\"((?:[^\"\\\\]|\\\\.)*)\"\\)")
	for path: String in _scripts("res://scripts"):
		var text: String = FileAccess.get_file_as_string(path)
		for found: RegExMatch in regex.search_all(text):
			var key: String = found.get_string(1).c_unescape()
			used[key] = true
			if not keys.has(key):
				_fail("%s : « %s » absent de %s" % [path, key, TABLE])
	for key: String in keys:
		if (keys[key] as String).strip_edges().is_empty():
			_fail("« %s » n'a pas de texte anglais" % key)
	TranslationServer.set_locale("en")
	if TranslationServer.translate("Joueur %d") != "Player %d":
		_fail("en anglais, « Joueur %d » n'est pas traduit (traductions non chargées par project.godot ?)")
	TranslationServer.set_locale("fr")
	if TranslationServer.translate("Joueur %d") != "Joueur %d":
		_fail("en français, « Joueur %d » a changé")
	print("[test] %s  traductions : %d textes dans le tableau, %d utilisés dans le code" % [
		"OK    " if _failures == 0 else "ÉCHEC ", keys.size(), used.size()])
	quit(1 if _failures > 0 else 0)


## Clé -> texte anglais.
func _read_table() -> Dictionary:
	var out: Dictionary = {}
	var file: FileAccess = FileAccess.open(TABLE, FileAccess.READ)
	var header: PackedStringArray = file.get_csv_line()
	var en: int = header.find("en")
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() <= en or row[0].is_empty():
			continue
		out[row[0]] = row[en]
	return out


func _scripts(dir_path: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for file: String in DirAccess.get_files_at(dir_path):
		if file.ends_with(".gd"):
			out.append(dir_path.path_join(file))
	for sub: String in DirAccess.get_directories_at(dir_path):
		out.append_array(_scripts(dir_path.path_join(sub)))
	return out


func _fail(text: String) -> void:
	_failures += 1
	print("[test] ÉCHEC  " + text)
