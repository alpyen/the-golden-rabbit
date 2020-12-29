void WriteLevelJsonFromTGRData(array<TGRLevel@> tgr_levels, string mod_id)
{
	// We are explicitly not writing `overridable´ in this function because
	// overridable is only designed for the built-in maps.

	JSON json;
	
	json.getRoot()["levels"] = JSONValue(JSONarrayValue);
	
	for (uint level_index = 0; level_index < tgr_levels.length(); level_index++)
	{
		TGRLevel@ current_tgr_level = tgr_levels[level_index];
		
		if (current_tgr_level.positions.length() == 0) continue;
		
		JSONValue current_level(JSONobjectValue);
		
		current_level["level_name"] = JSONValue(current_tgr_level.level_name);	
		current_level["positions"] = JSONValue(JSONarrayValue);
		
		for (uint position_index = 0; position_index < current_tgr_level.positions.length(); position_index++)
		{
			Position@ current_position = current_tgr_level.positions[position_index];
		
			JSONValue position = JSONValue(JSONobjectValue);
			
			JSONValue camera_position = JSONValue(JSONarrayValue);
			camera_position[0] = current_position.camera.x;
			camera_position[1] = current_position.camera.y;
			camera_position[2] = current_position.camera.z;
			
			JSONValue statue_position = JSONValue(JSONarrayValue);
			statue_position[0] = current_position.statue.x;
			statue_position[1] = current_position.statue.y;
			statue_position[2] = current_position.statue.z;
			
			JSONValue statue_rotation = JSONValue(JSONarrayValue);
			statue_rotation[0] = current_position.statue_rotation.x;
			statue_rotation[1] = current_position.statue_rotation.y;
			statue_rotation[2] = current_position.statue_rotation.z;
			statue_rotation[3] = current_position.statue_rotation.w;
						
			position["camera"] = camera_position;
			position["statue"] = statue_position;
			position["statue_rotation"] = statue_rotation;
			
			current_level["positions"].append(position);
		}
				
		json.getRoot()["levels"][level_index] = current_level;
	}
	
	StartWriteFile();
	AddFileString(json.writeString(true));
	WriteFileToWriteDir("Data/Mods/" + mod_id + "/Data/TheGoldenRabbit/" + mod_id + "/custom.tgr");
}

TGRLevel@ GetCurrentTGRLevel(array<TGRLevel@> tgr_levels)
{
	string current_level_name = GetCurrLevelRelPath();
	
	for (uint i = 0; i < tgr_levels.length(); i++)
	{
		if (tgr_levels[i].level_name == current_level_name)
			return tgr_levels[i];
	}
	
	return null;
}

array<TGRLevel@> ScanAndParseFiles()
{
	array<TGRLevel@> levels;
	
	// ParseLevelsFromFile(levels, "Data/TheGoldenRabbit/the-golden-rabbit/custom.tgr");
	
	array<ModID>@ mods = GetActiveModSids();
	
	for (uint i = 0; i < mods.length(); i++)
	{
		// So we save some time scanning files, because the core mods will have no TGR data.
		if (ModIsCore(mods[i])) continue;
				
		string mod_id = ModGetID(mods[i]);
		
		if (FileExists("Data/TheGoldenRabbit/" + mod_id + "/custom.tgr"))
		{
			LogSuccess("Mod '" + ModGetName(mods[i]) + "' has TGR data. Trying to parse.");
			
			ParseLevelsFromFile(levels, "Data/TheGoldenRabbit/" + mod_id + "/custom.tgr");
		}
		else
		{
			LogWarning("Mod '" + ModGetName(mods[i]) + "' has no TGR data.");
		}
	}
	
	return levels;
}

void ParseLevelsFromFile(array<TGRLevel@>& inout new_levels, string path)
{
	JSON json;
	if (!json.parseFile(path))
	{
		LogError("Could not parse file: " + path);
		return;
	}
	
	if (json.getRoot().getMemberNames().length() < 1 || json.getRoot().getMemberNames().length() > 2)
	{
		LogError("Root level has no or more than 2 elements.");
		return;
	}
	
	if (json.getRoot().getMemberNames().length() == 2 && json.getRoot().getMemberNames().find("overridable") < 0)
	{
		LogError("Root level has two elements, but second isn't 'overridable'.");
		return;
	}
	
	if (json.getRoot().getMemberNames().find("levels") < 0)
	{
		LogError("Could not find 'levels' element in: " + path);
		return;
	}
	
	bool overridable = (json.getRoot().getMemberNames().find("overridable") > 0) ? json.getRoot()["overridable"].asBool() : false;
	JSONValue levels = json.getRoot()["levels"];
	
	if (!levels.isArray())
	{
		LogError("'levels' element is incorrect. Not an array.");
		return;
	}
	
	// Iterate over each level
	for (uint level_counter = 0; level_counter < levels.size(); level_counter++)
	{
		JSONValue current_level = levels[level_counter];
		
		if (current_level.getMemberNames().length() != 2)
		{
			LogWarning("Level index " + level_counter + " has more or less than two elements. Skipping Level. [" + path + "]");
			continue;
		}
		
		if (current_level.getMemberNames().find("level_name") < 0)
		{
			LogWarning("Element 'level_name' could not be found at level index " + level_counter + ". Skipping Level. [" + path + "]");
			continue;
		}
		
		if (current_level.getMemberNames().find("positions") < 0)
		{
			LogWarning("Element 'positions' could not be found at level index " + level_counter + ". Skipping Level. [" + path + "]");
			continue;
		}
	
		// Check if we already added that level in this file
		// if so, warn the user and ignore the second instance.
		
		bool level_already_added = false;
		bool override_level = false;
		
		for (uint i = 0; i < new_levels.length(); i++)
		{		
			if (new_levels[i].level_name == current_level["level_name"].asString())
			{
				if (new_levels[i].overridable) override_level = true;
				else level_already_added = true;
				
				break;
			}
		}
		
		if (level_already_added)
		{
			LogWarning("Level '" + current_level["level_name"].asString() + "' has already been parsed.");
			continue;
		}
		
		// Level was not added, so parse it!
		TGRLevel new_level;
		new_level.overridable = overridable;
		new_level.level_name = current_level["level_name"].asString();
		
		JSONValue positions = current_level["positions"];
		
		bool position_invalid = false;
		
		if (positions.size() == 0)
		{
			LogWarning("Positions of level '" + new_level.level_name + "' is 0. Ignoring.");
			continue;
		}
		
		for (uint position_counter = 0; position_counter < positions.size(); position_counter++)
		{
			JSONValue current_position = positions[position_counter];
			
			if (current_position.getMemberNames().length() != 3)
			{
				LogWarning("Position index " + position_counter + " of the level'" + new_level.level_name + "' has more or less than 3 elements.");
				position_invalid = true;
				break;
			}
			else if (current_position.getMemberNames().find("camera") < 0 || current_position.getMemberNames().find("statue") < 0 || current_position.getMemberNames().find("statue_rotation") < 0)
			{
				LogWarning("Could not find element 'camera' or 'statue' at position index " + position_counter + " of the level'" + new_level.level_name + "'");
				position_invalid = true;
				break;
			}
			else if (current_position["camera"].size() != 3 || current_position["statue"].size() != 3)
			{
				LogWarning("Camera or Statue position at position index " + position_counter + " of the level '" + new_level.level_name + "' is invalid.");
				position_invalid = true;
				break;
			}
			
			JSONValue camera = current_position["camera"];
			JSONValue statue = current_position["statue"];
			JSONValue statue_rotation = current_position["statue_rotation"];
			
			Position new_position(
				vec3(camera[0].asFloat(), camera[1].asFloat(), camera[2].asFloat()),
				vec3(statue[0].asFloat(), statue[1].asFloat(), statue[2].asFloat()),
				quaternion(
					statue_rotation[0].asFloat(),
					statue_rotation[1].asFloat(),
					statue_rotation[2].asFloat(),
					statue_rotation[3].asFloat()
				)
			);
			
			new_level.positions.insertLast(new_position);
		}
		
		if (position_invalid)
		{
			continue;
		}
		
		if (override_level)
		{
			LogWarning("Level '" + new_level.level_name + "' was already added and is overridable. Overriding now.");
		
			for (uint i = 0; i < new_levels.length(); i++)
			{
				if (new_levels[i].level_name == new_level.level_name)
				{
					new_levels[i] = new_level;
					break;
				}
			}
		}
		else
		{
			new_levels.insertLast(new_level);
		}
	}
	
	LogSuccess("File was parsed completely! [" + path + "]");
}

void LogError(string message)
{
	Log(fatal, "[TGR - ERROR] " + message);
}

void LogWarning(string message)
{
	Log(fatal, "[TGR - WARNING] " + message);
}

void LogSuccess(string message)
{
	Log(fatal, "[TGR - SUCCESS] " + message);
}