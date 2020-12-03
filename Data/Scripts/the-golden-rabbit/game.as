const float STATUE_TOUCHING_DISTANCE = 0.6f;
const float PREVIEW_FADE_DURATION = 0.5f;
const float PREVIEW_DURATION = 2.0f;

float last_pause_timestamp;
float paused_time_in_level;

array<TGRLevel@> tgr_levels;
int level_progress = -1;

TGRLevel@ current_level;

float before_preview_fade_timestamp;
bool preview_fade_mode_switched = false;
float preview_fade_timestamp;

vec3 player_velocity;

bool preview_running = false;
vec3 old_camera_position;
vec3 old_camera_facing;

float preview_timestamp;

enum LevelScriptState
{
	LSS_SETUP = 0,
	LSS_PLAYER_IS_SEARCHING = 1,
	LSS_STATUE_WAS_FOUND = 2,
	LSS_FADE_TO_STATUE = 3,
	LSS_LOOKING_AT_STATUE = 4,
	LSS_FADE_TO_PLAYER = 5,
	LSS_ALL_STATUES_FOUND = 6,
	LSS_DO_NOTHING = 7,
	LSS_EDITING_LEVEL = 8
}

void ResetToPlayerIsSearching()
{
	if (player_id != -1) ReadCharacterID(player_id).static_char = false;
	
	preview_running = false;
	
	preview_fade_image.setVisible(false);
	current_level_state = LSS_PLAYER_IS_SEARCHING;
}

void LssSetup(bool state_changed)
{
	if (state_changed) { }

	tgr_levels = ScanAndParseFiles();
	@current_level = GetCurrentTGRLevel(tgr_levels);

	if (current_level is null)
	{
		Log(fatal, "Level has no TGR data / or data is not valid.");

		current_level_state = LSS_DO_NOTHING;
		Log(fatal, "LSS_SETUP -> LSS_DO_NOTHING");
	}
	else
	{
		MoveRabbitStatue(current_level.positions[0]);
		ShowRabbitStatue();
		
		level_progress = 0;			
		UpdateCounterProgressText();

		current_level_state = LSS_PLAYER_IS_SEARCHING;
		Log(fatal, "LSS_SETUP -> LSS_PLAYER_IS_SEARCHING");
		
		current_counter_state = GCS_SLIDING_IN;
		Log(fatal, "GCS_HIDDEN -> GCS_SLIDING_IN");
	}
}

void LssPlayerIsSearching(bool state_changed)
{
	if (state_changed) { }

	if (player_id == -1) return;

	// Did the player touch the statue?
	if (distance(ReadCharacterID(player_id).position, current_level.positions[level_progress].statue) <= STATUE_TOUCHING_DISTANCE)
	{
		// Statue was touched.
		current_level_state = LSS_STATUE_WAS_FOUND;
		Log(fatal, "LSS_PLAYER_IS_SEARCHING -> LSS_STATUE_WAS_FOUND");
	}
}

void LssStatueWasFound(bool state_changed)
{
	if (state_changed)
	{
		// Show the mist if it was not the last statue, because the last one will have a special color.
		if (level_progress < int(current_level.positions.length()) - 1)
		{
			SpawnRabbitStatueMist(current_level.positions[level_progress].statue, false);					
			PlaySound("Data/Sounds/the-golden-rabbit/collect.wav");
		}

		// Reset the timer when the next state will start (if it wasn't the last statue).
		before_preview_fade_timestamp = GetLevelTime();
		
		level_progress++;
		UpdateCounterProgressText();
		
		// Only slide out if the counter is hidden. If we touch multiple statues
		// the gui will just reset and it looks ugly.
		if (current_counter_state == GCS_HIDDEN) current_counter_state = GCS_SLIDING_IN;
	}

	HideRabbitStatue();
		
	// Was this the last statue or is it something before that?			
	if (level_progress == int(current_level.positions.length()))
	{
		// It was in fact the last. Show the mist and show win animation.
		current_level_state = LSS_ALL_STATUES_FOUND;
		Log(fatal, "LSS_STATUE_WAS_FOUND -> LSS_ALL_STATUES_FOUND");
	}
	else
	{			
		// It was not the last statue. Advance to the next one after one second.
		if (GetLevelTime() - before_preview_fade_timestamp >= 1.0f)
		{
			MoveRabbitStatue(current_level.positions[level_progress]);
			ShowRabbitStatue();
			
			SpawnRabbitStatueMist(current_level.positions[level_progress].statue, false);
		
			// If we are in a dialogue we will not fade to the statue, because that will mess with the camera.
			// This case is only really necessary when a statue was touched and the player resets the level within that 1 second
			// and starts a dialogue (or the auto-dialogue on some levels).
			// EditorModeActive is handled here separately because we need to spawn
			// the statue first.
			if (level.DialogueCameraControl() || EditorModeActive())
			{
				ResetToPlayerIsSearching();
				Log(fatal, "LSS_STATUE_WAS_FOUND [DIALOGUE/EDITOR RUNNING] -> LSS_PLAYER_IS_SEARCHING");
				return;
			}
			else
			{
				current_level_state = LSS_FADE_TO_STATUE;
				Log(fatal, "LSS_STATUE_WAS_FOUND -> LSS_FADE_TO_STATUE");	
			}
		}
	}
}

void LssFadeToStatue(bool state_changed)
{
	if (state_changed)
	{
		preview_fade_timestamp = GetLevelTime();
		
		preview_fade_image.setColor(vec4(0.0f));
		preview_fade_image.setVisible(true);
		
		preview_fade_mode_switched = false;
	}

	// How does the fade work? Fade out - Switch camera position - Fade In

	// We are fading out. Darken image.
	if (GetLevelTime() - preview_fade_timestamp <= PREVIEW_FADE_DURATION / 2.0f)
	{
		float alpha = (GetLevelTime() - preview_fade_timestamp) / (PREVIEW_FADE_DURATION / 2.0f);
		preview_fade_image.setColor(vec4(vec3(0.0f), min(1.0f, alpha)));
		
		if (level.DialogueCameraControl())
		{
			Log(fatal, "LSS_FADE_TO_STATUE [DIALOGUE IS RUNNING] -> LSS_PLAYER_IS_SEARCHING");
			ResetToPlayerIsSearching();			
			return;
		}
	} // We are fading in. Lighten image.
	else if (GetLevelTime() - preview_fade_timestamp > PREVIEW_FADE_DURATION / 2.0f && GetLevelTime() - preview_fade_timestamp < PREVIEW_FADE_DURATION)
	{
		if (!preview_fade_mode_switched)
		{
			preview_fade_mode_switched = true;
			preview_running = true;
			
			old_camera_position = camera.GetPos();
			old_camera_facing = camera.GetFacing();
			
			MovementObject@ player = ReadCharacterID(player_id);
			player_velocity = player.velocity;
			player.static_char = true;
			
		}
		
		UpdateCameraAndListenerToLookAtStatue();
		
		float alpha = 1.0f - ((GetLevelTime() - preview_fade_timestamp) - (PREVIEW_FADE_DURATION / 2.0f)) / (PREVIEW_FADE_DURATION / 2.0f);
		preview_fade_image.setColor(vec4(vec3(0.0f), max(0.0f, alpha)));
	}
	else // Fade was completed.
	{
		preview_fade_image.setVisible(false);

		UpdateCameraAndListenerToLookAtStatue();
		
		current_level_state = LSS_LOOKING_AT_STATUE;
		Log(fatal, "LSS_FADE_TO_STATUE -> LSS_LOOKING_AT_STATUE");
	}
}

void LssLookingAtStatue(bool state_changed)
{
	if (state_changed)
	{
		preview_timestamp = GetLevelTime();
	}

	UpdateCameraAndListenerToLookAtStatue();

	if (GetLevelTime() - preview_timestamp >= PREVIEW_DURATION)
	{
		current_level_state = LSS_FADE_TO_PLAYER;
		Log(fatal, "LSS_LOOKING_AT_STATUE -> LSS_FADE_TO_PLAYER");
	}	
}

void LssFadeToPlayer(bool state_changed)
{
	if (state_changed)
	{
		preview_fade_timestamp = GetLevelTime();
		
		preview_fade_image.setColor(vec4(0.0f));
		preview_fade_image.setVisible(true);
		
		preview_fade_mode_switched = false;
	}

	// Check LSS_FADE_TO_STATUE to see how the fade works.			
	if (GetLevelTime() - preview_fade_timestamp <= PREVIEW_FADE_DURATION / 2.0f)
	{
		UpdateCameraAndListenerToLookAtStatue();

		float alpha = (GetLevelTime() - preview_fade_timestamp) / (PREVIEW_FADE_DURATION / 2.0f);
		preview_fade_image.setColor(vec4(vec3(0.0f), min(1.0f, alpha)));
	}
	else if (GetLevelTime() - preview_fade_timestamp > PREVIEW_FADE_DURATION / 2.0f && GetLevelTime() - preview_fade_timestamp < PREVIEW_FADE_DURATION)
	{
		if (!preview_fade_mode_switched)
		{
			preview_fade_mode_switched = true;
			preview_running = false;
			
			
			MovementObject@ player = ReadCharacterID(player_id);
			player.static_char = false;
			player.velocity = player_velocity;					
		}
		
		float alpha = 1.0f - ((GetLevelTime() - preview_fade_timestamp) - (PREVIEW_FADE_DURATION / 2.0f)) / (PREVIEW_FADE_DURATION / 2.0f);
		preview_fade_image.setColor(vec4(vec3(0.0f), max(0.0f, alpha)));
	}
	else
	{
		preview_fade_image.setVisible(false);
		
		current_level_state = LSS_PLAYER_IS_SEARCHING;
		Log(fatal, "LSS_FADE_TO_PLAYER -> LSS_PLAYER_IS_SEARCHING");
	}		
}

void LssAllStatuesFound(bool state_changed)
{
	if (state_changed)
	{
		// We are using level_progress -1 because the progress jumped further already.
		// And it looks much cleaner than cucurrent_level.positions.length() - 1.
		SpawnRabbitStatueMist(current_level.positions[level_progress - 1].statue, true);
		
		PlaySound("Data/Sounds/the-golden-rabbit/cheer.wav");
	}
}

void UpdateCameraAndListenerToLookAtStatue()
{
	camera.SetPos(current_level.positions[level_progress].camera);
	camera.LookAt(current_level.positions[level_progress].statue);
	
	camera.SetFOV(90);
	camera.SetDistance(0);
	
	UpdateListener(current_level.positions[level_progress].camera, vec3(0.0f), camera.GetFacing(), camera.GetUpVector());
}