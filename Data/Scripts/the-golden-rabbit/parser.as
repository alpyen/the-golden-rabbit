array<TGRLevel@> ParseLevelsFromFile(string path)
{
	array<TGRLevel@> new_levels;
	
	JSON json;
	if (!json.parseFile(path))
	{
		LogError("Could not parse file: " + path);
		return new_levels;
	}
	
	if (json.getRoot().getMemberNames().length() != 1)
	{
		LogError("Root level has more than one element.");
		return new_levels;
	}
	
	if (json.getRoot().getMemberNames()[0] != "levels")
	{
		LogError("Could not find 'levels' element in: " + path);
		return new_levels;
	}
	
	JSONValue levels = json.getRoot()["levels"];
	
	if (!levels.isArray())
	{
		LogError("'levels' element is incorrect. Not an array.");
		return new_levels;
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
		
		for (uint i = 0; i < new_levels.length(); i++)
		{
			if (new_levels[i].level_name == current_level["level_name"].asString())
			{
				level_already_added = true;
				break;
			}
		}
		
		if (level_already_added)
		{
			LogWarning("Level '" + current_level["level_name"].asString() + "' has already been parsed. Skipping Level. [" + path + "]");
			continue;
		}
		
		// Level was not added, so parse it!
		TGRLevel new_level;
		new_level.level_name = current_level["level_name"].asString();
		
		JSONValue positions = current_level["positions"];
		
		bool position_invalid = false;
		
		for (uint position_counter = 0; position_counter < positions.size(); position_counter++)
		{
			JSONValue current_position = positions[position_counter];
			
			if (current_position.getMemberNames().length() != 3)
			{
				LogWarning("Position index " + position_counter + " of the level'" + new_level.level_name + "' has more or less than 3 elements. Skipping Level. [" + path + "]");
				position_invalid = true;
				break;
			}
			else if (current_position.getMemberNames().find("camera") < 0 || current_position.getMemberNames().find("statue") < 0 || current_position.getMemberNames().find("statue_rotation") < 0)
			{
				LogWarning("Could not find element 'camera' or 'statue' at position index " + position_counter + " of the level'" + new_level.level_name + "'. Skipping Level. [" + path + "]");
				position_invalid = true;
				break;
			}
			else if (current_position["camera"].size() != 3 || current_position["statue"].size() != 3)
			{
				LogWarning("Camera or Statue position at position index " + position_counter + " of the level '" + new_level.level_name + "' is invalid. [" + path + "]");
				position_invalid = true;
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
		
		new_levels.insertLast(new_level);
	}
	
	LogSuccess("File was parsed completely! [" + path + "]");
	
	return new_levels;
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