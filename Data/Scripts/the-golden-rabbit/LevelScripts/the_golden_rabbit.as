#include "the-golden-rabbit/tgrlevel.as"
#include "the-golden-rabbit/rabbit_statue.as"

#include "the-golden-rabbit/game.as"
#include "the-golden-rabbit/editor.as"
#include "the-golden-rabbit/gui.as"

#include "the-golden-rabbit/parser.as"

bool editor_mode_active = false;
int player_id = -1;

LevelScriptState current_level_state = LevelScriptState(-1);
LevelScriptState previous_level_state = LevelScriptState(-1);

GuiCounterState current_counter_state = GuiCounterState(-1);
GuiCounterState previous_counter_state = GuiCounterState(-1);

void Init(string level_name)
{
	// If you load a map in the editor then editor will get called twice.
	// Once with no level_name. // Maybe switch to LSS_SETUP again?
	if (level_name == "") return;

	// Log(fatal, GetLevelTime() + " Init(\"" + level_name + "\");");
	
	BuildGUI();	
	CreateRabbitStatue(); // Hidden by default
	
	previous_level_state = LevelScriptState(-1);
	current_level_state = LSS_SETUP;
	// Log(fatal, "-1 -> LSS_SETUP");
	
	previous_counter_state = GuiCounterState(-1);
	current_counter_state = GCS_HIDDEN;
	// Log(fatal, "-1 -> GCS_HIDDEN");
}

void Update(int is_paused)
{
	// Check if game is paused. If so, do not advance any script logic.
	// Removed as of 29-12-2020 because this would enable cheating by
	// pausing the preview while it is running.
	// We are only updating the pause timer so the time taken does not increase
	// while being paused but the script keeps on running.
	// To pause the script you'd need to check with if(UpdatePauseTimer(is_paused)) return;
	// Technically now you can cheat and not let the previews count into the game time
	// because they will keep running due to anti-cheat measures, but that's a minuscule amount.
	UpdatePauseTimer(is_paused);
	
	DetectEditorMode();
	UpdatePlayerID();
	
	bool level_state_changed = false;
	if (previous_level_state != current_level_state)
	{
		previous_level_state = current_level_state;
		level_state_changed = true;
	}
	
	switch (current_level_state)
	{
		// game.as
		case LSS_SETUP:					LssSetup(level_state_changed); break;
		case LSS_PLAYER_IS_SEARCHING: 	LssPlayerIsSearching(level_state_changed); break;	
		case LSS_STATUE_WAS_FOUND: 		LssStatueWasFound(level_state_changed); break;
		case LSS_FADE_TO_STATUE: 		LssFadeToStatue(level_state_changed); break;
		case LSS_LOOKING_AT_STATUE: 	LssLookingAtStatue(level_state_changed); break;
		case LSS_FADE_TO_PLAYER: 		LssFadeToPlayer(level_state_changed); break;
		case LSS_ALL_STATUES_FOUND: 	LssAllStatuesFound(level_state_changed); break;
		
		case LSS_DO_NOTHING: { // Do nothing.
			if (level_state_changed) { }
			
		} break;
		
		// editor.as
		case LSS_EDITING_LEVEL: LssEditingLevel(level_state_changed); break;
	}
	
	bool counter_state_changed = false;
	
	if (previous_counter_state != current_counter_state)
	{
		previous_counter_state = current_counter_state;
		counter_state_changed = true;
	}
	
	switch (current_counter_state)
	{
		// gui.as
		case GCS_HIDDEN: {
			if (counter_state_changed) { }
		} break;
		
		case GCS_SLIDING_IN: GcsSlidingIn(counter_state_changed); break;
		case GCS_SHOWING: GcsShowing(counter_state_changed); break;
		case GCS_SLIDING_OUT: GcsSlidingOut(counter_state_changed); break;
	}
}

void ReceiveMessage(string message)
{
	if (message == "tgr_reset_progress")
	{
		// Don't reset if the level is no tgr level to begin with.
		if (current_level is null) return;
		
		// Set statue to first position and reset progress.
		MoveRabbitStatue(current_level.positions[0]);
		ShowRabbitStatue();

		search_begin_timestamp = GetLevelTime();
		reset_amount = 0;
		
		level_progress = 0;			
		UpdateCounterProgressText();
				
		last_pause_timestamp = 0.0f;
		paused_time_in_level = 0.0f;		
		
		if (player_id != -1) ReadCharacterID(player_id).static_char = false;
		
		current_level_state = LSS_PLAYER_IS_SEARCHING;
		// Log(fatal, "LSS_SETUP -> LSS_PLAYER_IS_SEARCHING");
		
		current_counter_state = GCS_SLIDING_IN;
		// Log(fatal, "GCS_HIDDEN -> GCS_SLIDING_IN");
		
		SetStatisticsVisibility(false);
		preview_running = false;
		
		preview_fade_image.setVisible(false);
		
		//editor.as
		custom_editor_open = false;
		gui_has_unsaved_changes = false;
		mod_levels.resize(0);
		mod_levels_index = -1;

		mod_names.resize(0);
		mod_ids.resize(0);
		selected_mod_name = 0;

		selected_position = -1;
		
	}
	else if (message == "post_reset")
	{
		reset_amount += 1;
	
		// Log(fatal, ImGui_GetTime() + "POST_RESET_WAS_CALLED");
	
		switch (current_level_state)
		{
			case LSS_FADE_TO_PLAYER:
			case LSS_FADE_TO_STATUE:
			case LSS_LOOKING_AT_STATUE: {
			
				// Log(warning, "ITS RESET TIME");
			
				// Player could be in fade, remove the fade and keep on searching.
				preview_fade_image.setVisible(false);
				preview_running = false;
				
				// Log(fatal, "<RESET> -> LSS_PLAYER_IS_SEARCHING");
				current_level_state = LSS_PLAYER_IS_SEARCHING;
			
			} break;
			
			case LSS_ALL_STATUES_FOUND: {
				SetStatisticsVisibility(false);
			
				// Log(fatal, "<RESET FROM ALL STATUES FOUND> -> LSS_DO_NOTHING");
				current_level_state = LSS_DO_NOTHING;
			} break;
			
			// For the other cases we don't have to do anything.
		}
	}
}

void DrawGUI()
{
	// Show normal editor and on unsaved changes popup dialogue.
	if (custom_editor_open || (!custom_editor_open && gui_has_unsaved_changes)) DisplayLevelEditor();

	switch (current_level_state)
	{
		case LSS_ALL_STATUES_FOUND:
		case LSS_FADE_TO_STATUE:
		case LSS_FADE_TO_PLAYER: {
			gui.render();
			return;
		}
	}
	
	switch (current_counter_state)
	{
		case GCS_SLIDING_IN:
		case GCS_SHOWING:
		case GCS_SLIDING_OUT: {
			gui.render();
			return;
		}
	}
}

void Menu()
{
	MenuCustomEditor();
}

void SetWindowDimensions(int width, int height)
{
	ResizeGUIToFullscreen(true);
}

bool DialogueCameraControl()
{
	return preview_running;
}

bool UpdatePauseTimer(int is_paused)
{
	if (is_paused == 1)
	{
		if (last_pause_timestamp == 0.0f)
			last_pause_timestamp = GetLevelTime();
			
		return true;		
	}
	else if (is_paused == 0 && last_pause_timestamp > 0.0f)
	{
		paused_time_in_level += GetLevelTime() - last_pause_timestamp;
		last_pause_timestamp = 0.0f;
	}
	
	return false;
}

// We have to check if we entered the edit mode because if we set the camera
// during previews and enter the editor, the camera will twitch back and forth.
// So if we are in a state that will mess with the camera, we will update it to
// LSS_PLAYER_IS_SEARCHING if the player still has statues.
void DetectEditorMode()
{
	bool editor_now_active = EditorModeActive();

	if (editor_now_active && !editor_mode_active)
	{
		editor_mode_active = true;
		
		switch (current_level_state)
		{
			case LSS_FADE_TO_STATUE:
			case LSS_LOOKING_AT_STATUE:
			case LSS_FADE_TO_PLAYER: {
				ResetToPlayerIsSearching();
				// Log(fatal, "EDITOR DETECTED -> LSS_PLAYER_IS_SEARCHING");
			} break;
		}
	}
	else if (!editor_now_active && editor_mode_active)
	{
		editor_mode_active = false;
	}
}

void UpdatePlayerID()
{
	// Check if the player ID is valid, if not get a new one.
	if (player_id == -1 || !ObjectExists(player_id) || ReadObjectFromID(player_id).GetType() != _movement_object || !ReadCharacterID(player_id).controlled || ReadCharacterID(player_id).controller_id != 0)
	{
		// So we need to check for one criteria if we don't find any.
		player_id = -1;
		
		array<int> characters;
		GetCharacters(characters);
		
		for (uint i = 0; i < characters.length(); i++)
		{
			if (ReadCharacterID(characters[i]).controlled)
			{
				player_id = characters[i];
				break;
			}
		}
	}
}

float GetLevelTime()
{
	return ImGui_GetTime() - paused_time_in_level;
}