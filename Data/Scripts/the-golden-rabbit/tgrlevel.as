class TGRLevel
{
	bool overridable = false;
	string level_name;
	array<Position@> positions;
}

class Position
{
	vec3 camera;
	vec3 statue;
	quaternion statue_rotation;
	
	Position(vec3 camera, vec3 statue, quaternion statue_rotation)
	{
		this.camera = camera;
		this.statue = statue;
		this.statue_rotation = statue_rotation;
	}
}
