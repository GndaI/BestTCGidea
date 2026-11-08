extends "res://src/scenes/controllers/start_screen_controller.gd"

func open_account() -> void:
	start_page = "account"
	account_notice = ""
	render()

func render_account() -> void:
	_render_in_screen(AccountScreenScene, _render_account_content)

func _render_account_content() -> void:
	screen_header_at("계정", back_to_main_menu)
	var body := HBoxContainer.new()
	body.name = "AccountScreen"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 22)
	root.add_child(body)

	var summary_panel := PanelContainer.new()
	summary_panel.custom_minimum_size.x = 400
	summary_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	summary_panel.add_theme_stylebox_override("panel", box(Color("101b2e"), Color("3b5472")))
	body.add_child(summary_panel)
	var summary := VBoxContainer.new()
	summary.alignment = BoxContainer.ALIGNMENT_CENTER
	summary.add_theme_constant_override("separation", 15)
	summary_panel.add_child(summary)
	var avatar := label_at(summary, "●", 92, Color("8fa7c3"))
	avatar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var account_title := label_at(summary, "최고의TCGidea 계정", MENU_FONT_SIZE, GOLD)
	account_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emphasize_label(account_title, 0.35)
	var account_subtitle := label_at(summary, "하나의 계정으로 언제 어디서나\n플레이를 이어가세요.", 20, MUTED)
	account_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_account_benefit(summary, "☁", "덱을 어디서나 불러오기", "PC가 바뀌어도 저장한 덱을 불러옵니다.")
	_account_benefit(summary, "▥", "전적 저장", "대전 결과와 승패 기록을 계정에 저장합니다.")
	_account_benefit(summary, "●", "닉네임으로 플레이", "이메일 대신 닉네임이 다른 플레이어에게 표시됩니다.")

	var auth_panel := PanelContainer.new()
	auth_panel.custom_minimum_size.x = 460
	auth_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	auth_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	auth_panel.add_theme_stylebox_override("panel", box(Color("101b2e"), Color("3b5472")))
	body.add_child(auth_panel)
	var auth := VBoxContainer.new()
	auth.add_theme_constant_override("separation", 13)
	auth_panel.add_child(auth)
	if account_auth != null and account_auth.is_signed_in():
		_render_signed_in_account(auth)
	else:
		_render_account_form(auth)

func _account_benefit(parent: Node, icon_text: String, title_text: String, detail_text: String) -> void:
	var shell := PanelContainer.new()
	shell.custom_minimum_size.y = 88
	shell.add_theme_stylebox_override("panel", box(Color("14243b"), Color("2f4664")))
	parent.add_child(shell)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	shell.add_child(row)
	var icon := label_at(row, icon_text, 30, GOLD)
	icon.custom_minimum_size.x = 44
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var copy := VBoxContainer.new()
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(copy)
	var title := label_at(copy, title_text, 18, Color("f3f6fc"))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var detail := label_at(copy, detail_text, 14, MUTED)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _render_account_form(parent: VBoxContainer) -> void:
	var tabs := row_at(parent)
	var login_tab := button_at(tabs, "로그인", set_account_mode.bind("login"), account_mode == "login")
	login_tab.name = "AccountLoginTab"
	login_tab.custom_minimum_size = Vector2(0, 58)
	login_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var signup_tab := button_at(tabs, "회원가입", set_account_mode.bind("signup"), account_mode == "signup")
	signup_tab.name = "AccountSignupTab"
	signup_tab.custom_minimum_size = Vector2(0, 58)
	signup_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if account_auth != null and not account_auth.is_configured():
		var setup := label_at(parent, "Supabase 프로젝트 연결 전입니다.\nProject URL과 Publishable key를 설정하면 실제 이메일 인증이 활성화됩니다.", 16, Color("ffbd84"))
		setup.name = "AccountSetupNotice"
		setup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var email := _account_line_edit(parent, "이메일", "이메일 주소", account_email_text, false)
	email.name = "AccountEmailEdit"
	email.text_changed.connect(func(value): account_email_text = value)
	if account_mode == "signup":
		var nickname := _account_line_edit(parent, "닉네임", "게임에 표시할 이름", account_nickname_text, false)
		nickname.name = "AccountNicknameEdit"
		nickname.max_length = 16
		nickname.text_changed.connect(func(value): account_nickname_text = value)
	var password := _account_line_edit(parent, "비밀번호", "8자 이상", account_password_text, true)
	password.name = "AccountPasswordEdit"
	password.text_changed.connect(func(value): account_password_text = value)
	password.text_submitted.connect(func(_value): submit_account_form())
	if account_mode == "signup":
		var confirm := _account_line_edit(parent, "비밀번호 확인", "비밀번호 다시 입력", account_password_confirm_text, true)
		confirm.name = "AccountPasswordConfirmEdit"
		confirm.text_changed.connect(func(value): account_password_confirm_text = value)
		confirm.text_submitted.connect(func(_value): submit_account_form())
	else:
		var remember := CheckButton.new()
		remember.name = "AccountRememberCheck"
		remember.text = "자동 로그인"
		remember.button_pressed = account_remember
		remember.toggled.connect(func(value): account_remember = value)
		parent.add_child(remember)
	var submit_text := "회원가입" if account_mode == "signup" else "로그인"
	var submit := button_at(parent, submit_text, submit_account_form, account_busy)
	submit.name = "AccountSubmitButton"
	submit.custom_minimum_size.y = 66
	submit.add_theme_font_size_override("font_size", 23)
	submit.add_theme_stylebox_override("normal", box(Color("3d3426"), GOLD.darkened(0.2)))
	if account_mode == "login":
		var recover := button_at(parent, "비밀번호를 잊으셨나요?", request_account_password_reset, account_busy)
		recover.name = "AccountPasswordResetButton"
	if not account_notice.is_empty():
		var notice := label_at(parent, account_notice, 16, Color("ffbd84"))
		notice.name = "AccountNotice"
		notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var safety := label_at(parent, "계정은 덱과 전적을 안전하게 저장합니다.", 15, GREEN)
	safety.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _account_line_edit(parent: VBoxContainer, title_text: String, placeholder: String, value: String, secret: bool) -> LineEdit:
	label_at(parent, title_text, 17, Color("e8eef8"))
	var edit := LineEdit.new()
	edit.text = value
	edit.placeholder_text = placeholder
	edit.secret = secret
	edit.custom_minimum_size.y = 52
	parent.add_child(edit)
	return edit

func _render_signed_in_account(parent: VBoxContainer) -> void:
	var signed_title := label_at(parent, "로그인됨", MENU_FONT_SIZE, GREEN)
	signed_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var nickname: String = str(account_auth.user_nickname())
	if nickname.is_empty():
		nickname = "닉네임 미설정"
	var name_label := label_at(parent, nickname, 30, GOLD)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var email_label := label_at(parent, account_auth.user_email(), 19, MUTED)
	email_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_account_benefit(parent, "▣", "저장된 덱", "%d개의 사용자 덱이 이 기기에 있습니다." % saved_decks.size())
	_account_benefit(parent, "↻", "클라우드 동기화", cloud_deck_notice)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(spacer)
	var logout := button_at(parent, "로그아웃", request_account_sign_out, account_busy)
	logout.name = "AccountLogoutButton"
	logout.custom_minimum_size.y = 58
	if not account_notice.is_empty():
		var notice := label_at(parent, account_notice, 16, Color("ffbd84"))
		notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func set_account_mode(mode: String) -> void:
	if mode not in ["login", "signup"]:
		return
	account_mode = mode
	account_notice = ""
	render()

func submit_account_form() -> void:
	if account_busy:
		return
	var email := account_email_text.strip_edges()
	var password := account_password_text
	if "@" not in email or "." not in email.get_slice("@", 1):
		account_notice = "올바른 이메일 주소를 입력해주세요."
		render()
		return
	if password.length() < 8:
		account_notice = "비밀번호는 8자 이상이어야 합니다."
		render()
		return
	if account_mode == "signup":
		var nickname := account_nickname_text.strip_edges()
		if nickname.length() < 2:
			account_notice = "닉네임은 2자 이상이어야 합니다."
			render()
			return
		if password != account_password_confirm_text:
			account_notice = "비밀번호 확인이 일치하지 않습니다."
			render()
			return
	account_busy = true
	account_notice = "계정 서버에 요청하는 중…"
	if account_mode == "signup":
		account_auth.sign_up(email, password, account_nickname_text.strip_edges())
	else:
		account_auth.sign_in(email, password, account_remember)
	render()

func request_account_password_reset() -> void:
	if account_busy:
		return
	var email := account_email_text.strip_edges()
	if "@" not in email:
		account_notice = "비밀번호 재설정 메일을 받을 이메일을 입력해주세요."
		render()
		return
	account_busy = true
	account_notice = "재설정 메일을 요청하는 중…"
	account_auth.send_password_reset(email)
	render()

func request_account_sign_out() -> void:
	if account_busy:
		return
	account_busy = true
	account_auth.sign_out()

func _on_account_auth_finished(action: String, ok: bool, _payload: Dictionary, message: String) -> void:
	account_busy = false
	if not ok:
		account_notice = message
	elif action == "signup":
		if account_auth.is_signed_in():
			account_notice = "회원가입과 로그인이 완료되었습니다. 덱을 동기화합니다."
			_sync_account_decks()
		else:
			account_mode = "login"
			account_password_text = ""
			account_password_confirm_text = ""
			account_notice = "인증 메일을 보냈습니다. 이메일 인증 후 로그인해주세요."
	elif action in ["signin", "refresh"]:
		account_notice = "로그인했습니다. 덱을 동기화합니다."
		_sync_account_decks()
	elif action == "recover":
		account_notice = "비밀번호 재설정 메일을 보냈습니다."
	elif action == "signout":
		account_notice = "로그아웃했습니다."
		cloud_decks.cancel()
		cloud_deck_syncing = false
		cloud_deck_notice = "로그인하면 클라우드 덱을 불러옵니다."
	if start_screen and start_page == "account":
		render()

func _sync_account_decks() -> void:
	if account_auth == null or cloud_decks == null or not account_auth.is_signed_in():
		return
	cloud_deck_syncing = true
	cloud_deck_notice = "클라우드 덱을 확인하는 중…"
	cloud_decks.sync(saved_decks, account_auth.access_token(), account_auth.user_id())

func _on_cloud_deck_sync_finished(ok: bool, decks_value: Array, message: String) -> void:
	cloud_deck_syncing = false
	if ok:
		var valid_decks: Array = []
		for entry in decks_value:
			if valid_decks.size() >= MAX_CUSTOM_DECKS:
				break
			if entry is Dictionary and _valid_saved_deck_structure(entry.get("cards", [])):
				valid_decks.append({"name": str(entry.get("name", "이름 없는 덱")), "cards": entry.cards.duplicate(true)})
		saved_decks = valid_decks
		_write_saved_decks(false)
		cloud_deck_notice = message
		account_notice = message
	else:
		cloud_deck_notice = "%s 로컬 덱은 그대로 유지됩니다." % message
		account_notice = cloud_deck_notice
	if start_screen and start_page in ["account", "decks"]:
		render()

func _on_cloud_deck_save_finished(ok: bool, message: String) -> void:
	cloud_deck_notice = message if ok else "%s 로컬에는 저장되었습니다." % message
	if start_screen and start_page == "account":
		render()

