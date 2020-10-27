#include "the-golden-rabbit/tgrlevel.as"
#include "the-golden-rabbit/parser.as"

array<TGRLevel@> tgr_levels;

void Init(string level_name)
{
	Log(fatal, "Init(\"" + level_name + "\");");
}

void PostScriptReload()
{
	Log(fatal, "PostScriptReload();");
	
	tgr_levels = ParseLevelsFromFile("Data/Scripts/the-golden-rabbit/custom.tgr");
	
	for (uint i = 0; i < tgr_levels.length(); i++)
	{
		Log(fatal, "level name: " + tgr_levels[i].level_name);
	}
}

void Update(int is_paused)
{
	
}

void ReceiveMessage(string message)
{
	
}

void HotspotExit(string str, MovementObject @mo)
{
	
}

void HotspotEnter(string str, MovementObject @mo)
{
	
}

void DrawGUI()
{
	
}

bool HasFocus()
{
	return false;
}

void SetWindowDimensions(int width, int height)
{
	
}

void SaveHistoryState(SavedChunk@ chunk)
{
	
}

void ReadChunk(SavedChunk@ chunk)
{
	
}

void IncomingTCPData(uint socket, array<uint8>@ data)
{
	
}

void DrawGUI2()
{
	
}

void DrawGUI3()
{
	
}

bool DialogueCameraControl()
{
	return false;
}
