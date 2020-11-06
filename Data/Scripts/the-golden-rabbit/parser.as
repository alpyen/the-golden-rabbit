JSONValue ReadLevelJsonFromMod(string mod_id)
{
	JSONValue level_json;
	
	if (!FileExists("Data/TheGoldenRabbit/" + mod_id + "/custom.tgr"))
		return level_json;
		
	array<TGRLevel@> levels_from_mod;
	ParseLevelsFromFile(levels_from_mod, "Data/TheGoldenRabbit/" + mod_id + "/custom.tgr");
	
	return level_json;
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
					statue_rotation[0].asFloat(), statue_rotation[1].asFloat(),
					statue_rotation[2].asFloat(), statue_rotation[3].asFloat()
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