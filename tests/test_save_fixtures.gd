extends RefCounted

# Archived saves stay at their original paths. Rebuilt saves use an explicit root.
static func directory(name: String) -> String:
	var base: String = "res://.godot/"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--fixture-root="):
			base = argument.trim_prefix("--fixture-root=")
	return base.path_join(name) + "/"

static func available(paths: Array[String]) -> bool:
	var missing: Array[String] = []
	for path: String in paths:
		if not FileAccess.file_exists(path):
			missing.append(path)
	if missing.is_empty():
		return true
	print("UNVERIFIED: required campaign saves are missing (exit 77):")
	for path: String in missing:
		print("  " + path)
	return false
