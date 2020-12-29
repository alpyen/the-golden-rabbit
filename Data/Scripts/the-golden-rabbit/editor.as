const TextureAssetRef TEXTURE_ADD = LoadTexture("Data/Textures/the-golden-rabbit/UI/add.png");
const TextureAssetRef TEXTURE_DELETE = LoadTexture("Data/Textures/the-golden-rabbit/UI/delete.png");
const TextureAssetRef TEXTURE_UP = LoadTexture("Data/Textures/the-golden-rabbit/UI/up.png");
const TextureAssetRef TEXTURE_DOWN = LoadTexture("Data/Textures/the-golden-rabbit/UI/down.png");
const TextureAssetRef TEXTURE_APPLY = LoadTexture("Data/Textures/the-golden-rabbit/UI/apply.png");
const TextureAssetRef TEXTURE_SAVE = LoadTexture("Data/Textures/the-golden-rabbit/UI/save.png");

bool custom_editor_open = false;
bool gui_has_unsaved_changes = false;

array<TGRLevel@> mod_levels;
int mod_levels_index = -1;

TGRLevel@ mod_level;

array<string> mod_names;
array<string> mod_ids;
int selected_mod_name = 0;

int selected_position = -1;

void LssEditingLevel(bool state_changed)
{
	// The state-change code is in OpenCustomEditor because we only have one state for the editor anyway.
	
	if (selected_position != -1)
	{
		// preview_running has to be set even when EditorMode is active, although the camera isn't positioned,
		// because otherwise the game will twitch rapidly between both positions.
		// This only happens if preview_running is executed after EditorModeActive and after setting the camera position.
		// However, this only happens once. On the next preview this does not happen anymore.
		preview_running = true;
		
		MoveCameraAndStatueToTargetLocation();
	}
	else
	{
		preview_running = false;
	}
}

void MoveCameraAndStatueToTargetLocation()
{	
	if (!EditorModeActive())
	{
		Position@ preview_position = mod_level.positions[selected_position];

		camera.SetPos(preview_position.camera);
		camera.LookAt(preview_position.statue);
		camera.SetFOV(90.0f);
	}	
}

void MenuCustomEditor()
{
	if (ImGui_BeginMenu("The Golden Rabbit"))
	{
		ImGui_AlignTextToFramePadding();
		ImGui_TextColored(HexColor("#FFD700"), "The Golden Rabbit Editor");
		
		ImGui_TextColored(HexColor("#FF6200"), "Warning!\nOpening the editor will reset\nyour current TGR level progress.\n\nNormal game data is not affected.");
		
		if (ImGui_Button("Open TGR Level Editor")) OpenCustomEditor();
		
		ImGui_EndMenu();
	}
}

void OpenCustomEditor()
{
	if (custom_editor_open) return;

	mod_names.resize(0);
	mod_ids.resize(0);
	
	array<ModID>@ mods = GetActiveModSids();
	
	for (uint i = 0; i < mods.length(); i++)
	{
		if (ModIsCore(mods[i]) || IsWorkshopMod(mods[i]) || ModGetID(mods[i]) == "the-golden-rabbit") continue;
		
		mod_names.insertLast(ModGetName(mods[i]) + " [" + ModGetID(mods[i]) + "]");
		mod_ids.insertLast(ModGetID(mods[i]));
	}
	
	// mod_names contains valid mods that we can use, mods held all the possible candidates.
	if (mod_names.length() == 0)
	{
		Log(error, "The Golden Rabbit: No usable mod found modifying .tgr files.");
		return;
	}
		
	custom_editor_open = true;
	gui_has_unsaved_changes = false;
	
	HideRabbitStatue();	
	SetModInLevelEditorGUI();
	
	current_level_state = LSS_EDITING_LEVEL;
	current_counter_state = GCS_HIDDEN;
	Log(fatal, "ScriptState -> " + LSS_EDITING_LEVEL + ", CounterState -> " + GCS_HIDDEN);
}

void CloseCustomEditor()
{
	gui_has_unsaved_changes = false;
	selected_position = -1;
	
	HideRabbitStatue();
	
	current_level_state = LSS_SETUP;
	current_counter_state = GCS_HIDDEN;
	
	preview_running = false;
}

void SetModInLevelEditorGUI()
{
	selected_position = -1;
	mod_levels_index = -1;
	HideRabbitStatue();
	DeselectAll();
	
	@mod_level = null;	
	mod_levels.resize(0);
	
	Log(fatal, "Loading from mod: " + mod_ids[selected_mod_name]);
	
	ParseLevelsFromFile(mod_levels, "Data/TheGoldenRabbit/" + mod_ids[selected_mod_name] + "/custom.tgr");
	
	for (uint i = 0; i < mod_levels.length(); i++)
	{
		if (mod_levels[i].level_name == GetCurrLevelRelPath())
		{
			mod_levels_index = i;
			@mod_level = mod_levels[i];
			break;
		}
	}
	
	// Check if this level is already included in the mod, if not, add a placeholder.
	if (mod_levels_index == -1)
	{
		TGRLevel add_level;
		add_level.level_name = GetCurrLevelRelPath();
		
		mod_levels.insertLast(add_level);
		mod_levels_index = mod_levels.length() - 1;
		
		@mod_level = mod_levels[mod_levels_index];
	}
}

array<string> GetListBoxStringArrayFromPositions()
{
	array<string> items;
	
	array<Position@> positions = mod_level.positions;
	
	for (uint i = 0; i < positions.length(); i++)
	{
		Position@ pos = positions[i];
	
		string entry = (i + 1)
		+ " ["
			+ formatFloat(pos.camera.x, "l", 0, 1) + ", "
			+ formatFloat(pos.camera.y, "l", 0, 1) + ", "
			+ formatFloat(pos.camera.z, "l", 0, 1)
		+ "] ["
			+ formatFloat(pos.statue.x, "l", 0, 1) + ", "
			+ formatFloat(pos.statue.y, "l", 0, 1) + ", "
			+ formatFloat(pos.statue.z, "l", 0, 1)
		+ "] ["
			+ formatFloat(pos.statue_rotation.x, "l", 0, 1) + ", "
			+ formatFloat(pos.statue_rotation.y, "l", 0, 1) + ", "
			+ formatFloat(pos.statue_rotation.z, "l", 0, 1) + ", "
			+ formatFloat(pos.statue_rotation.w, "l", 0, 1)
		+ "]";
		
		items.insertLast(entry);
	}
		
	return items;
}

void LevelEditorSave()
{
	gui_has_unsaved_changes = false;
	WriteLevelJsonFromTGRData(mod_levels, mod_ids[selected_mod_name]);
}

void LevelEditorAddPosition()
{
	gui_has_unsaved_changes = true;

	Position new_position(
		camera.GetPos(),
		camera.GetPos() + camera.GetFacing(), 
		quaternion(0.0f)
	);
	
	mod_level.positions.insertLast(new_position);
	
	selected_position = mod_level.positions.length() - 1;
	
	MoveRabbitStatue(new_position);
	ShowRabbitStatue();
	SpawnRabbitStatueMist(new_position.statue);
}

void LevelEditorDeletePosition()
{
	if (selected_position != -1)
	{
		HideRabbitStatue();
		mod_level.positions.removeAt(selected_position);
		
		selected_position = -1;
		DeselectAll();
		gui_has_unsaved_changes = true;
	}
}

void LevelEditorApplyPosition()
{
	if (selected_position != -1)
	{
		Position new_position(
			camera.GetPos(),
			GetRabbitStatuePosition(),
			GetRabbitStatueRotation()
		);		
		@mod_level.positions[selected_position] = new_position;
		gui_has_unsaved_changes = true;
	}
}

void LevelEditorMoveUp()
{
	gui_has_unsaved_changes = true;

	if (selected_position > 0)
	{
		Position@ tmp = mod_level.positions[selected_position - 1];
		@mod_level.positions[selected_position - 1] = mod_level.positions[selected_position];
		@mod_level.positions[selected_position] = tmp;
		
		selected_position--;
	}
}

void LevelEditorMoveDown()
{
	if (selected_position != -1 && selected_position < int(mod_level.positions.length() - 1))
	{
		Position@ tmp = mod_level.positions[selected_position + 1];
		@mod_level.positions[selected_position + 1] = mod_level.positions[selected_position];
		@mod_level.positions[selected_position] = tmp;
		
		selected_position++;
		gui_has_unsaved_changes = true;
	}
}

void LevelEditorPositionListClicked(bool same_position_clicked)
{
	if (same_position_clicked)
	{
		// Deselect incase it was the same
		selected_position = -1;
		HideRabbitStatue();
		DeselectAll();
	}
	else
	{			
		MoveRabbitStatue(mod_level.positions[selected_position]);
		ShowRabbitStatue();
		SpawnRabbitStatueMist(mod_level.positions[selected_position].statue);
	}
}

void DisplayLevelEditor()
{
	const vec2 EDITOR_GUI_SIZE(500.0f, 267.0f);
	const vec2 SAVE_GUI_SIZE(300, 100.0f);
	
	if (!custom_editor_open && gui_has_unsaved_changes)
	{
		ImGui_SetNextWindowSize(SAVE_GUI_SIZE, ImGuiSetCond_Always);
		ImGui_SetNextWindowPos((screenMetrics.screenSize - SAVE_GUI_SIZE) / 2.0f, ImGuiSetCond_Always);
		
		ImGui_Begin("The Golden Rabbit - Level Editor - Unsaved Changes", gui_has_unsaved_changes, ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoCollapse);
		
		ImGui_Text("Level has unsaved changes in TGR data.\n\n");
		ImGui_Text("Save them?");
		
		if (ImGui_Button("Yes")) { LevelEditorSave(); CloseCustomEditor(); }
		ImGui_SameLine();
		
		if (ImGui_Button("No")) CloseCustomEditor();
		ImGui_SameLine();
		
		if (ImGui_Button("Cancel")) custom_editor_open = true;
		
		ImGui_End();
		
		return; // Do not run the normal editor code while the popup is being displayed!
	}
	
	ImGui_SetNextWindowSize(EDITOR_GUI_SIZE, ImGuiSetCond_Always);
	ImGui_SetNextWindowPos((screenMetrics.screenSize - EDITOR_GUI_SIZE) / 2.0f, ImGuiSetCond_FirstUseEver);
	
	if (ImGui_Begin("The Golden Rabbit - Level Editor", custom_editor_open, ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoCollapse) && !custom_editor_open && !gui_has_unsaved_changes)
	{
		CloseCustomEditor();
	}
		
	ImGui_AlignTextToFramePadding();
	
	ImGui_Text(" Local Mod: ");
	ImGui_SameLine();
	
	ImGui_PushItemWidth(359.0f); int old_selected_mod_name = selected_mod_name;
	if (ImGui_Combo("", selected_mod_name, mod_names) && selected_mod_name != old_selected_mod_name)
	{
		gui_has_unsaved_changes = false;
		SetModInLevelEditorGUI();
	}
	ImGui_PopItemWidth();
	
	ImGui_PushItemWidth(450.0f); int old_selected_position = selected_position;
	if (ImGui_ListBox(" ", selected_position, GetListBoxStringArrayFromPositions(), 10))
		LevelEditorPositionListClicked(old_selected_position == selected_position);
	ImGui_PopItemWidth();
	
	ImGui_SetCursorPos(vec2(468.0f, 27.0f));
	if (ImGui_ImageButton(TEXTURE_SAVE, vec2(16))) LevelEditorSave();
	
	ImGui_SetCursorPos(vec2(468.0f, 77.0f));
	if (ImGui_ImageButton(TEXTURE_ADD, vec2(16))) LevelEditorAddPosition();
	
	ImGui_SetCursorPos(vec2(468.0f, 102.0f));
	if (ImGui_ImageButton(TEXTURE_DELETE, vec2(16))) LevelEditorDeletePosition();
	
	ImGui_SetCursorPos(vec2(468.0f, 127.0f));
	if (ImGui_ImageButton(TEXTURE_APPLY, vec2(16))) LevelEditorApplyPosition();
	
	ImGui_SetCursorPos(vec2(468.0f, 177.0f));
	if (ImGui_ImageButton(TEXTURE_UP, vec2(16))) LevelEditorMoveUp();
	
	ImGui_SetCursorPos(vec2(468.0f, 202.0f));
	if (ImGui_ImageButton(TEXTURE_DOWN, vec2(16))) LevelEditorMoveDown();
	
	ImGui_TextColored(HexColor("#DEDBEF"), "Preview outside the editor is active when a position is selected.");
	ImGui_TextColored(HexColor("#DEDBEF"), "The FOV will be fixed to 90 degrees during the statue previews.");
	
	ImGui_End();
}