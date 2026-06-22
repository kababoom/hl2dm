#include <sourcemod>
#include <sdktools>

public Plugin myinfo =
{
    name = "Hitsound Precache",
    author = "HagenIT",
    description = "Precache + download-table the custom loud hitsound",
    version = "1.0",
    url = ""
};

public void OnMapStart()
{
    PrecacheSound("quake/buttons/hit.wav", true);
    AddFileToDownloadsTable("sound/quake/buttons/hit.wav");
}
