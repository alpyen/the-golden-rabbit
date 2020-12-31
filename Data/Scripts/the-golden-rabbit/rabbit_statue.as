// Just some wrapper functions so we don't have to write double the code
// in the level script.

const float STATUE_SCALE = 0.36f;
const vec3 STATUE_TINT = vec3(1.0f, 0.621f, 0.0f) * 8.0f;

const vec3 MIST_NORMAL = vec3(1.0f, 0.84f, 0.0f) * 6.0f;
const vec3 MIST_FINISH = vec3(1.0f, 0.0f, 0.0f) * 6.0f;

int rabbit_statue_id = -1;

void CreateRabbitStatue()
{
	rabbit_statue_id = CreateObject("Data/Objects/the-golden-rabbit/rabbit_statue.xml", true);
	
	Object@ statue = ReadObjectFromID(rabbit_statue_id);	
	statue.SetSelectable(true);
	statue.SetTranslatable(true);
	statue.SetRotatable(true);
	
	statue.SetEnabled(false);
	statue.SetScale(STATUE_SCALE);
	statue.SetTint(STATUE_TINT);
}

void DeleteRabbitStatue()
{
	if (rabbit_statue_id != -1)
	{
		// Log(warning, "Removing old statue [" + rabbit_statue_id + "]");
		
		if (ObjectExists(rabbit_statue_id)) DeleteObjectID(rabbit_statue_id);
		
		rabbit_statue_id = -1;
	}
}

void MoveRabbitStatue(Position@ position)
{
	Object@ statue = ReadObjectFromID(rabbit_statue_id);
	statue.SetTranslation(position.statue);
	statue.SetRotation(position.statue_rotation);
}

void HideRabbitStatue()
{
	ReadObjectFromID(rabbit_statue_id).SetEnabled(false);
}

void ShowRabbitStatue()
{
	ReadObjectFromID(rabbit_statue_id).SetEnabled(true);
}

vec3 GetRabbitStatuePosition()
{
	return ReadObjectFromID(rabbit_statue_id).GetTranslation();
}

quaternion GetRabbitStatueRotation()
{
	return ReadObjectFromID(rabbit_statue_id).GetRotation();
}

void SpawnRabbitStatueMist(vec3 position, bool last_statue = false)
{
	MakeParticle(
		"Data/Particles/the-golden-rabbit/statue_mist.xml",
		vec3(position),
		vec3(0.0f),
		last_statue ? MIST_FINISH : MIST_NORMAL
	);
}