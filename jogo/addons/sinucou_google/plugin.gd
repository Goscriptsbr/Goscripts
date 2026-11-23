@tool
extends EditorPlugin
# Liga o AAR do login Google no build Android (Gradle). Só é ativado no build da Play Store (CI).

var exp: EditorExportPlugin


func _enter_tree() -> void:
	exp = SGExport.new()
	add_export_plugin(exp)


func _exit_tree() -> void:
	remove_export_plugin(exp)
	exp = null


class SGExport extends EditorExportPlugin:
	func _get_name() -> String:
		return "SinucouGoogle"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		return PackedStringArray(["sinucou_google/bin/sinucou-google.aar"])

	func _get_android_dependencies(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		return PackedStringArray([
			"androidx.credentials:credentials:1.3.0",
			"androidx.credentials:credentials-play-services-auth:1.3.0",
			"com.google.android.libraries.identity.googleid:googleid:1.1.1",
		])
