#include "the-golden-rabbit/tgrlevel.as"
#include "the-golden-rabbit/parser.as"
#include "the-golden-rabbit/gui.as"

const float STATUE_SCALE = 0.36f;
const float STATUE_TOUCHING_DISTANCE = 0.6f;
const float PREVIEW_FADE_DURATION = 0.5f;
const float PREVIEW_DURATION = 2.0f;

const float COUNTER_SLIDE_DURATION = 0.5f;
const float COUNTER_DURATION = 5.0f;

array<TGRLevel@> tgr_levels;
int level_index = -1;
int level_progress = -1;

int rabbit_statue_id = -1;
int player_id = -1;

float before_preview_fade_timestamp;
bool preview_fade_mode_switched = false;
float preview_fade_timestamp;

bool preview_running = false;
vec3 old_camera_position;
vec3 old_camera_facing;

float preview_timestamp;

float counter_slide_timestamp;
float counter_timestamp;

LevelScriptState current_script_state = LevelScriptState(-1);
LevelScriptState previous_script_state = LevelScriptState(-1);

CounterState current_counter_state = CS_HIDDEN;
CounterState previous_counter_state = CS_HIDDEN;

enum LevelScriptState
{
	LSS_PLAYER_IS_SEARCHING = 0,
	LSS_STATUE_WAS_FOUND = 1,
	LSS_FADE_TO_STATUE = 2,
	LSS_LOOKING_AT_STATUE = 3,
	LSS_FADE_TO_PLAYER = 4,
	LSS_ALL_STATUES_FOUND = 5,
	LSS_DO_NOTHING = 6
}

enum CounterState
{
	CS_HIDDEN = 0,
	CS_SLIDING_IN = 1,
	CS_SHOWING = 2,
	CS_SLIDING_OUT = 3
}

void PostScriptReload()
{
	Log(fatal, "PostScriptReload();");
	Init("From PostScriptReload();");
}

void Init(string level_name)
{
	// If you load a map in the editor then editor will get called twice.
	// Once with no level_name. // Maybe switch to LSS_INIT again?
	if (level_name == "") return;

	Log(fatal, ImGui_GetTime() + " Init(\"" + level_name + "\");");
	
	if (rabbit_statue_id != -1)
	{
		Log(warning, "Removing old statue [" + rabbit_statue_id + "]");
		
		if (ObjectExists(rabbit_statue_id))
			DeleteObjectID(rabbit_statue_id);
		
		rabbit_statue_id = -1;
	}
	
	level_index = -1;
	player_id = -1;
	
	rabbit_statue_id = -1;
	level_progress = -1;

	before_preview_fade_timestamp = 0.0f;
	preview_fade_mode_switched = false;
	preview_fade_timestamp = 0.0f;
	
	preview_running = false;
	old_camera_position = vec3(0);
	old_camera_facing = vec3(0);
	
	preview_timestamp = 0.0f;
	
	tgr_levels = ParseLevelsFromFile("Data/Scripts/the-golden-rabbit/custom.tgr");
	// Check if the current level has TGR data.		
	
	level_index = -1;
	for (uint i = 0; i < tgr_levels.length(); i++)
	{
		if (tgr_levels[i].level_name == GetCurrLevelRelPath())
		{
			level_index = i;
			break;
		}
	}
	
	if (level_index != -1)
	{	
		// Spawn the rabbit to the first location.
		rabbit_statue_id = CreateObject("Data/Objects/therium/rabbit_statue/rabbit_statue_1.xml", true);
		
		Object@ statue = ReadObjectFromID(rabbit_statue_id);
		statue.SetTranslation(tgr_levels[level_index].positions[0].statue);
		statue.SetScale(vec3(STATUE_SCALE));
		statue.SetTint(vec3(1.0f, 0.621f, 0.0f) * 8.0f);
		
		// Set the level progress to 0.
		level_progress = 0;
	
		previous_script_state = LevelScriptState(-1);
		current_script_state = LSS_PLAYER_IS_SEARCHING;
		Log(fatal, "LSS_INIT -> LSS_PLAYER_IS_SEARCHING");
	}
	else // Level was not found.
	{
		// If the level has no TGR data, jump into a Do Nothing state.
		previous_script_state = LevelScriptState(-1);
		current_script_state = LSS_DO_NOTHING;
		Log(fatal, "LSS_INIT -> LSS_DO_NOTHING");
	}
	
	@counter_container = null;
	@counter_background_image = null;
	@preview_fade_image = null;
	@rabbit_statue_image = null;
	@level_progress_text = null;
	
	
	// Setup everything in void Init(). Why not as a LSS_INIT state?
	// We want some things created before they have a chance to execute.
	// This way we don't need to check every time if the gui !is null in void DrawGui();
	
	BuildGUI();
	
	previous_counter_state = CounterState(-1);
	current_counter_state = CS_SLIDING_IN;
	Log(fatal, "CS_INIT -> CS_SLIDING_IN");
}

void Update(int is_paused)
{
	UpdatePlayerID();
	
	switch (current_script_state)
	{	
		case LSS_PLAYER_IS_SEARCHING: { // Player is searching for the statue.
			if (DidScriptStateChange()) { }
			
			if (player_id == -1) break;
			
			// Did the player touch the statue?
			if (distance(ReadCharacterID(player_id).position, tgr_levels[level_index].positions[level_progress].statue) <= STATUE_TOUCHING_DISTANCE)
			{
				// Statue was touched.
				current_script_state = LSS_STATUE_WAS_FOUND;
				Log(fatal, "LSS_PLAYER_IS_SEARCHING -> LSS_STATUE_WAS_FOUND");
			}
		} break;
		
		
		case LSS_STATUE_WAS_FOUND: { // Statue has been found.
			if (DidScriptStateChange())
			{
				// Show the mist if it was not the last statue, because the last one will have a special color.
				if (level_progress < int(tgr_levels[level_index].positions.length()) - 1)
				{
					MakeParticle(
						"Data/Particles/the-golden-rabbit/statue_mist.xml",
						vec3(tgr_levels[level_index].positions[level_progress].statue),
						vec3(0.0f),
						vec3(1.0f, 0.84f, 0.0f) * 6.0f
					);
				}
			
				// Reset the timer when the next state will start (if it wasn't the last statue).
				before_preview_fade_timestamp = ImGui_GetTime();
				
				level_progress++;
				UpdateCounterProgressText();
				
				// Only slide out if the counter is hidden. If we touch multiple statues
				// the gui will just reset and it looks ugly.
				if (current_counter_state == CS_HIDDEN) current_counter_state = CS_SLIDING_IN;
			}
			
			
			Object@ statue = ReadObjectFromID(rabbit_statue_id);
			statue.SetEnabled(false);
				
			// Was this the last statue or is it something before that?			
			if (level_progress == int(tgr_levels[level_index].positions.length()))
			{
				// It was in fact the last. Show the mist and show win animation.
				// We are using level_progress -1 because the progress jumped further already.
				// And it looks much cleaner than tgr_levels[level_index].positions.length() - 1
				MakeParticle(
					"Data/Particles/the-golden-rabbit/statue_mist.xml",
					vec3(tgr_levels[level_index].positions[level_progress - 1].statue),
					vec3(0.0f),
					vec3(1.0f, 0.0f, 0.0f) * 6.0f
				);
				
				current_script_state = LSS_ALL_STATUES_FOUND;
				Log(fatal, "LSS_STATUE_WAS_FOUND -> LSS_ALL_STATUES_FOUND");
			}
			else
			{
				// It was not the last statue. Advance to the next one after one second.
				if (ImGui_GetTime() - before_preview_fade_timestamp >= 1.0f)
				{
					statue.SetEnabled(true);
					statue.SetTranslation(tgr_levels[level_index].positions[level_progress].statue);
					
					MakeParticle(
						"Data/Particles/the-golden-rabbit/statue_mist.xml",
						vec3(tgr_levels[level_index].positions[level_progress].statue),
						vec3(0.0f),
						vec3(1.0f, 0.84f, 0.0f) * 6.0f
					);
				
					current_script_state = LSS_FADE_TO_STATUE;
					Log(fatal, "LSS_STATUE_WAS_FOUND -> LSS_FADE_TO_STATUE");
				}
			}
		} break;
		
		
		case LSS_FADE_TO_STATUE: { // Fading for the statue preview.
			if (DidScriptStateChange())
			{
				preview_fade_timestamp = ImGui_GetTime();
				
				preview_fade_image.setColor(vec4(0.0f));
				preview_fade_image.setVisible(true);
				
				preview_fade_mode_switched = false;
			}
			
			// How does the fade work? Fade out - Switch camera position - Fade In
			
			// We are fading out. Darken image.
			if (ImGui_GetTime() - preview_fade_timestamp <= PREVIEW_FADE_DURATION / 2.0f)
			{
				float alpha = (ImGui_GetTime() - preview_fade_timestamp) / (PREVIEW_FADE_DURATION / 2.0f);
				preview_fade_image.setColor(vec4(vec3(0.0f), min(1.0f, alpha)));
			} // We are fading in. Lighten image.
			else if (ImGui_GetTime() - preview_fade_timestamp > PREVIEW_FADE_DURATION / 2.0f && ImGui_GetTime() - preview_fade_timestamp < PREVIEW_FADE_DURATION)
			{
				if (!preview_fade_mode_switched)
				{
					preview_fade_mode_switched = true;
					preview_running = true;
					
					old_camera_position = camera.GetPos();
					old_camera_facing = camera.GetFacing();					
				}
				
				UpdateCameraAndListenerToLookAtStatue();
				
				float alpha = 1.0f - ((ImGui_GetTime() - preview_fade_timestamp) - (PREVIEW_FADE_DURATION / 2.0f)) / (PREVIEW_FADE_DURATION / 2.0f);
				preview_fade_image.setColor(vec4(vec3(0.0f), max(0.0f, alpha)));
			}
			else // Fade was completed.
			{
				preview_fade_image.setVisible(false);
			
				UpdateCameraAndListenerToLookAtStatue();
				
				current_script_state = LSS_LOOKING_AT_STATUE;
				Log(fatal, "LSS_FADE_TO_STATUE -> LSS_LOOKING_AT_STATUE");
			}
		} break;
		
		
		case LSS_LOOKING_AT_STATUE: { // Looking at the statue in a preview.
			if (DidScriptStateChange())
			{
				preview_timestamp = ImGui_GetTime();
			}
		
			UpdateCameraAndListenerToLookAtStatue();
		
			if (ImGui_GetTime() - preview_timestamp >= PREVIEW_DURATION)
			{
				current_script_state = LSS_FADE_TO_PLAYER;
				Log(fatal, "LSS_LOOKING_AT_STATUE -> LSS_FADE_TO_PLAYER");
			}		
		} break;
		
		
		case LSS_FADE_TO_PLAYER: { // Fading back to the player.
			if (DidScriptStateChange())
			{
				preview_fade_timestamp = ImGui_GetTime();
				
				preview_fade_image.setColor(vec4(0.0f));
				preview_fade_image.setVisible(true);
				
				preview_fade_mode_switched = false;
			}
			
			// Check LSS_FADE_TO_STATUE to see how the fade works.			
			if (ImGui_GetTime() - preview_fade_timestamp <= PREVIEW_FADE_DURATION / 2.0f)
			{
				UpdateCameraAndListenerToLookAtStatue();
			
				float alpha = (ImGui_GetTime() - preview_fade_timestamp) / (PREVIEW_FADE_DURATION / 2.0f);
				preview_fade_image.setColor(vec4(vec3(0.0f), min(1.0f, alpha)));
			}
			else if (ImGui_GetTime() - preview_fade_timestamp > PREVIEW_FADE_DURATION / 2.0f && ImGui_GetTime() - preview_fade_timestamp < PREVIEW_FADE_DURATION)
			{
				if (!preview_fade_mode_switched)
				{
					preview_fade_mode_switched = true;
					preview_running = false;
				}
				
				float alpha = 1.0f - ((ImGui_GetTime() - preview_fade_timestamp) - (PREVIEW_FADE_DURATION / 2.0f)) / (PREVIEW_FADE_DURATION / 2.0f);
				preview_fade_image.setColor(vec4(vec3(0.0f), max(0.0f, alpha)));
			}
			else
			{
				preview_fade_image.setVisible(false);
				
				current_script_state = LSS_PLAYER_IS_SEARCHING;
				Log(fatal, "LSS_FADE_TO_PLAYER -> LSS_PLAYER_IS_SEARCHING");
			}		
		} break;
		
		
		case LSS_ALL_STATUES_FOUND: { // All statues have just been found. Win.
			if (DidScriptStateChange()) { }
		
		} break;	
	}
	
	switch (current_counter_state)
	{
		case CS_HIDDEN: {
			if (DidCounterStateChange()) { }
		} break;
		
		
		case CS_SLIDING_IN: {
			if (DidCounterStateChange())
			{
				counter_slide_timestamp = ImGui_GetTime();
				
				counter_container.setVisible(true);
				for (uint i = 0; i < counter_container.getFloatingContents().length(); i++)
					counter_container.getFloatingContents()[i].setVisible(true);
			}
		
			RefreshRabbitStatueAnimation();
		
			if (ImGui_GetTime() - counter_slide_timestamp <= COUNTER_SLIDE_DURATION)
			{
				float percentage = (ImGui_GetTime() - counter_slide_timestamp) / COUNTER_SLIDE_DURATION;
			
				gui.getMain().moveElement(
					counter_container.getName(),
					vec2(
						gui.getMain().getSizeX() - (counter_container.getSizeX() - COUNTER_GUI_DISTANCE_FROM_RIGHT) * percentage,
						gui.getMain().getSizeY() - counter_container.getSizeY() - COUNTER_GUI_DISTANCE_FROM_BOTTOM
					)
				);
			}
			else
			{
				current_counter_state = CS_SHOWING;
				Log(fatal, "CS_SLIDING_IN -> CS_SHOWING");
			}
		} break;
		
		
		case CS_SHOWING: {
			if (DidCounterStateChange())
			{
				counter_timestamp = ImGui_GetTime();
			}
			
			RefreshRabbitStatueAnimation();
			
			if (ImGui_GetTime() - counter_timestamp >= COUNTER_DURATION)
			{
				current_counter_state = CS_SLIDING_OUT;
				Log(fatal, "CS_SHOWING -> CS_SLIDING_OUT");
			}
			
		} break;
		
		
		case CS_SLIDING_OUT: {
			if (DidCounterStateChange())
			{
				counter_slide_timestamp = ImGui_GetTime();
			}
			
			RefreshRabbitStatueAnimation();
			
			if (ImGui_GetTime() - counter_slide_timestamp <= COUNTER_SLIDE_DURATION)
			{
				float percentage = (ImGui_GetTime() - counter_slide_timestamp) / COUNTER_SLIDE_DURATION;
				
				gui.getMain().moveElement(
					counter_container.getName(),
					vec2(
						gui.getMain().getSizeX() - (counter_container.getSizeX() - COUNTER_GUI_DISTANCE_FROM_RIGHT) * (1.0f - percentage),
						gui.getMain().getSizeY() - counter_container.getSizeY() - COUNTER_GUI_DISTANCE_FROM_BOTTOM
					)
				);
			}
			else
			{
				counter_container.setVisible(false);
				for (uint i = 0; i < counter_container.getFloatingContents().length(); i++)
					counter_container.getFloatingContents()[i].setVisible(false);
			
				current_counter_state = CS_HIDDEN;
				Log(fatal, "CS_SLIDING_OUT -> CS_HIDDEN");
			}
			
		} break;
	}
}

void ReceiveMessage(string message)
{
	if (message == "reset")
	{
		Log(fatal, "void ReceiveMessage(\"reset\");");
		PostScriptReload();
	}
}

void DrawGUI()
{
	if (level_index != -1) gui.render();
}

bool HasFocus()
{
	return false;
}

void SetWindowDimensions(int width, int height)
{
	ResizeGUIToFullscreen(true);
	
	gui.getMain().moveElement(
		counter_container.getName(),
		vec2(
			gui.getMain().getSizeX() - counter_container.getSizeX() - COUNTER_GUI_DISTANCE_FROM_RIGHT,
			gui.getMain().getSizeY() - counter_container.getSizeY() - COUNTER_GUI_DISTANCE_FROM_BOTTOM
		)
	);
}

bool DialogueCameraControl()
{
	return preview_running;
}

void UpdateCameraAndListenerToLookAtStatue()
{
	camera.SetPos(tgr_levels[level_index].positions[level_progress].camera);
	camera.LookAt(tgr_levels[level_index].positions[level_progress].statue);
	UpdateListener(tgr_levels[level_index].positions[level_progress].camera, vec3(0.0f), camera.GetFacing(), camera.GetUpVector());
}

// Since we have no code that executes if we come from a specific state we simply
// set the previous state to the next one rather than in each state individually.
bool DidScriptStateChange()
{
	bool changed = previous_script_state != current_script_state;
	previous_script_state = current_script_state;
	return changed;
}


bool DidCounterStateChange()
{
	bool changed = previous_counter_state != current_counter_state;
	previous_counter_state = current_counter_state;
	return changed;
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