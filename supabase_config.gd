class_name SupabaseConfig
extends RefCounted

# These two values are public client configuration. Fill them from the
# Supabase project's Connect dialog. Never put an sb_secret or service_role
# key in this file or in a shipped game build.
const PROJECT_URL := "https://ifywjgbwelicgxihrmxa.supabase.co"
const PUBLISHABLE_KEY := "sb_publishable_YJuVuSu6UAxAsTXDe7OMkQ_szcKRQ9N"

static func is_configured() -> bool:
	return PROJECT_URL.begins_with("https://") and PUBLISHABLE_KEY.begins_with("sb_publishable_")
