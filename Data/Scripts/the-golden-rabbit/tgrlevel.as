class TGRLevel
{
	string level_name;
	array<Position@> positions;
}

class Position
{
	vec3 camera;
	vec3 statue;
	
	Position(vec3 camera, vec3 statue)
	{
		this.camera = camera;
		this.statue = statue;
	}
}
