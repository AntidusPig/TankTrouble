extends Node

const SAVE_PATH := "user://language.cfg"
const FLAGS := {
	"en": preload("res://i18n/flags/us.svg"),
	"zh_CN": preload("res://i18n/flags/cn.svg"),
	"es": preload("res://i18n/flags/es.svg"),
	"ar": preload("res://i18n/flags/sa.svg"),
	"el": preload("res://i18n/flags/gr.svg"),
}
const LANGUAGE_NAMES := {
	"en": "English", "zh_CN": "简体中文", "es": "Español", "ar": "العربية", "el": "Ελληνικά",
}


func _enter_tree() -> void:
	var settings := ConfigFile.new()
	var chosen: String = "en"
	if settings.load(SAVE_PATH) == OK:
		chosen = str(settings.get_value("language", "locale", "en"))
	TranslationServer.set_locale(chosen if FLAGS.has(chosen) else "en")


func select(locale: String) -> void:
	if not FLAGS.has(locale):
		return
	TranslationServer.set_locale(locale)
	var settings := ConfigFile.new()
	settings.set_value("language", "locale", locale)
	var error := settings.save(SAVE_PATH)
	if error != OK:
		push_warning(error_string(error))
