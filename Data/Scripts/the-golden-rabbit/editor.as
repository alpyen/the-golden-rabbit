const TextureAssetRef TEXTURE_ADD = LoadTexture("Data/Textures/the-golden-rabbit/UI/add.png");
const TextureAssetRef TEXTURE_DELETE = LoadTexture("Data/Textures/the-golden-rabbit/UI/delete.png");
const TextureAssetRef TEXTURE_UP = LoadTexture("Data/Textures/the-golden-rabbit/UI/up.png");
const TextureAssetRef TEXTURE_DOWN = LoadTexture("Data/Textures/the-golden-rabbit/UI/down.png");
const TextureAssetRef TEXTURE_REFRESH = LoadTexture("Data/Textures/the-golden-rabbit/UI/refresh.png");
const TextureAssetRef TEXTURE_SAVE = LoadTexture("Data/Textures/the-golden-rabbit/UI/save.png");

bool custom_editor_open = false;

array<TGRLevel@> mod_levels;
int mod_levels_index = 0; // WARNING; CHANGE LATER BACK TO -1 JUST FOR DEBUG

array<string> mod_names;
array<string> mod_ids;
int selected_mod_name = 0;

int selected_position = -1;

int editor_statue_id = -1;

void LssEditingLevel()
{
	if (DidScriptStateChange())
	{
		DeleteLevelStatue();

		// Spawn the editor statue.
		editor_statue_id = CreateObject("Data/Objects/therium/rabbit_statue/rabbit_statue_1.xml", true);
				
		Object@ statue = ReadObjectFromID(editor_statue_id);
		statue.SetSelectable(true);
		// statue.SetTranslatable(true);
		// statue.SetRotatable(true);
		// statue.SetScalable(true);
		statue.SetScale(vec3(STATUE_SCALE));
		statue.SetTint(vec3(1.0f, 0.621f, 0.0f) * 8.0f);
	}
	
	Log(fatal, "preview="+preview_running);
		
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

void DeleteEditorStatue()
{
	if (editor_statue_id != -1)
	{
		if (ObjectExists(editor_statue_id)) DeleteObjectID(editor_statue_id);
		editor_statue_id = -1;
	}
}

void MoveCameraAndStatueToTargetLocation()
{	
	if (!EditorModeActive())
	{
		Position@ preview_position = mod_levels[mod_levels_index].positions[selected_position];

		camera.SetPos(preview_position.camera);
		camera.LookAt(preview_position.statue);
		
	}
	
}

void OpenCustomEditor()
{
	if (custom_editor_open) return;

	mod_names.resize(0);
	mod_ids.resize(0);
	
	mod_levels.resize(0);
	
	array<ModID>@ mods = GetActiveModSids();
	
	for (uint i = 0; i < mods.length(); i++)
	{
		if (ModIsCore(mods[i]) || ModGetID(mods[i]) == "the-golden-rabbit") continue;
		
		mod_names.insertLast(ModGetName(mods[i]) + " [" + ModGetID(mods[i]) + "]");
		mod_ids.insertLast(ModGetID(mods[i]));
	}
	
	if (mods.length() == 0)
	{
		Log(error, "The Golden Rabbit: No usable mod found modifying .tgr files.");
		return;
	}
	
	custom_editor_open = true;
	
	current_script_state = LSS_EDITING_LEVEL;
	current_counter_state = GCS_HIDDEN;
	Log(fatal, "ScriptState -> " + LSS_EDITING_LEVEL + ", CounterState -> " + GCS_HIDDEN);
	
	SetModInLevelEditorGUI();
}

void CloseCustomEditor()
{
	selected_position = -1;
	
	current_script_state = LSS_INIT;
	current_counter_state = GCS_HIDDEN;
}

void SetModInLevelEditorGUI()
{
	selected_position = -1;
	mod_levels_index = -1;
	
	ParseLevelsFromFile(mod_levels, "Data/TheGoldenRabbit/" + mod_ids[selected_mod_name] + "/custom.tgr");
	
	for (uint i = 0; i < mod_levels.length(); i++)
	{
		if (mod_levels[i].level_name == GetCurrLevelRelPath())
		{
			mod_levels_index = i;
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
	}
}

array<string> GetListBoxStringArrayFromPositions()
{
	array<string> items;
	
	array<Position@> positions = mod_levels[mod_levels_index].positions;
	
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

void DisplayLevelEditor()
{
	const vec2 GUI_SIZE(500.0f, 234.0f);

	ImGui_SetNextWindowSize(GUI_SIZE, ImGuiSetCond_Always);
	ImGui_SetNextWindowPos((screenMetrics.screenSize - GUI_SIZE) / 2.0f, ImGuiSetCond_FirstUseEver);
	
	if (ImGui_Begin("The Golden Rabbit - Level Editor", custom_editor_open, ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoCollapse) && !custom_editor_open)
	{
		CloseCustomEditor();
	}
		
	ImGui_AlignTextToFramePadding();
	
	ImGui_Text("Save To Mod:");
	ImGui_SameLine();
	
	ImGui_PushItemWidth(359.0f); int old_selected_mod_name = selected_mod_name;
	if (ImGui_Combo("", selected_mod_name, mod_names) && selected_mod_name != old_selected_mod_name)
	{
		SetModInLevelEditorGUI();
	}
	ImGui_PopItemWidth();
	
	ImGui_PushItemWidth(450.0f); int old_selected_position = selected_position;
	if (ImGui_ListBox(" ", selected_position, GetListBoxStringArrayFromPositions(), 10))
	{
		if (selected_position == old_selected_position)
		{
			// Deselect incase it was the same
			selected_position = -1;		
		}
		else
		{
			Position@ preview_position = mod_levels[mod_levels_index].positions[selected_position];
			
			Object@ statue = ReadObjectFromID(editor_statue_id);
			statue.SetTranslation(preview_position.statue);
			statue.SetRotation(preview_position.statue_rotation);
		}
	}
	ImGui_PopItemWidth();
	
	ImGui_SetCursorPos(vec2(468.0f, 27.0f));
	ImGui_ImageButton(TEXTURE_SAVE, vec2(16));
	
	ImGui_SetCursorPos(vec2(468.0f, 77.0f));
	ImGui_ImageButton(TEXTURE_ADD, vec2(16));
	
	ImGui_SetCursorPos(vec2(468.0f, 102.0f));
	ImGui_ImageButton(TEXTURE_DELETE, vec2(16));
	
	ImGui_SetCursorPos(vec2(468.0f, 127.0f));
	if (ImGui_ImageButton(TEXTURE_REFRESH, vec2(16)))
	{
		if (selected_position != -1)
		{
			Position new_position(camera.GetPos(), vec3(0), quaternion(0));
			
			@mod_levels[mod_levels_index].positions[selected_position] = new_position;
		}
	}
	
	ImGui_SetCursorPos(vec2(468.0f, 177.0f));
	ImGui_ImageButton(TEXTURE_UP, vec2(16));
	
	ImGui_SetCursorPos(vec2(468.0f, 202.0f));
	ImGui_ImageButton(TEXTURE_DOWN, vec2(16));
	
	ImGui_End();
}