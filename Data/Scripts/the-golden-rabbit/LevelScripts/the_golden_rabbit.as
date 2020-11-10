#include "the-golden-rabbit/tgrlevel.as"
#include "the-golden-rabbit/rabbit_statue.as"

#include "the-golden-rabbit/game.as"
#include "the-golden-rabbit/editor.as"
#include "the-golden-rabbit/gui.as"

#include "the-golden-rabbit/parser.as"

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

	Log(fatal, GetLevelTime() + " Init(\"" + level_name + "\");");
	
	BuildGUI();	
	CreateRabbitStatue(); // Hidden by default
	
	previous_level_state = LevelScriptState(-1);
	current_level_state = LSS_SETUP;
	Log(fatal, "-1 -> LSS_SETUP");
	
	previous_counter_state = GuiCounterState(-1);
	current_counter_state = GCS_HIDDEN;
	Log(fatal, "-1 -> GCS_HIDDEN");
}

void Update(int is_paused)
{
	// Check if game is paused. If so, do not advance any script logic.
	if (UpdatePauseTimer(is_paused)) return;
	
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
		case LSS_SETUP: 				LssSetup(level_state_changed); break;
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
	if (message == "post_reset")
	{
		
	}
	else if (message == "full_reset")
	{
		// Delete and Reset everything ---- NOT THE FINAL SOLUTION
		DeleteRabbitStatue();
		
		last_pause_timestamp = 0.0f;
		paused_time_in_level = 0.0f;
		
		tgr_levels.resize(0);
		level_progress = -1;
		
		@current_level = null;
		
		player_id = -1;
		player_velocity = vec3(0.0f);

		before_preview_fade_timestamp = 0.0f;
		preview_fade_mode_switched = false;
		preview_fade_timestamp = 0.0f;
		
		preview_running = false;
		old_camera_position = vec3(0);
		old_camera_facing = vec3(0);
		
		preview_timestamp = 0.0f;
		
		counter_slide_timestamp = 0.0f;
		counter_timestamp = 0.0f;
		
		@gui = null;
		
		@counter_container = null;
		@counter_background_image = null;
		@preview_fade_image = null;
		@rabbit_statue_image = null;
		@level_progress_text = null;
		
		previous_level_state = LevelScriptState(-1);
		current_level_state = LevelScriptState(-1);		
		
		previous_counter_state = GuiCounterState(-1);
		current_counter_state = GuiCounterState(-1);
		
		//editor.as
		custom_editor_open = false;
		mod_levels.resize(0);
		mod_levels_index = -1;

		mod_names.resize(0);
		mod_ids.resize(0);
		selected_mod_name = 0;

		selected_position = -1;
		
		// Create everything again
		Init("CALLED AFTER FULL_RESET");
	}
}

void DrawGUI()
{
	if (custom_editor_open) DisplayLevelEditor();

	switch (current_level_state)
	{
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