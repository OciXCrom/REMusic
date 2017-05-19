#include <amxmodx>
#include <amxmisc>
#include <nvault>

#define PLUGIN_VERSION "2.3a"

#if defined client_disconnected
	#define client_disconnect client_disconnected
#endif

new const g_szPrefix[] = "!g[REMusic]!n"

new Array:g_aSounds,
	g_iMaxSounds,
	g_iVault,
	g_iSound,
	g_pRandom,
	g_iSayText
	
new bool:g_bBlocked[33]

enum
{
	TYPE_INVALID = 0,
	TYPE_WAV,
	TYPE_MP3
}

enum
{
	VAULT_READ = 0,
	VAULT_WRITE
}

public plugin_init()
{
	register_plugin("Round End Music", PLUGIN_VERSION, "OciXCrom")
	register_cvar("CRXReMusic", PLUGIN_VERSION, FCVAR_SERVER|FCVAR_SPONLY|FCVAR_UNLOGGED)
	register_dictionary("REMusic.txt")
	
	register_event("SendAudio", "OnRoundEnd", "a", "2=%!MRAD_terwin", "2=%!MRAD_ctwin", "2=%!MRAD_rounddraw")
	register_clcmd("say /ers", "cmdMute")
	register_clcmd("say_team /ers", "cmdMute")
	
	g_pRandom = register_cvar("remusic_random", "1")
	g_iSayText = get_user_msgid("SayText")
	g_iVault = nvault_open("REMusic")
}

public plugin_precache()
{
	g_aSounds = ArrayCreate(32, 1)
	ReadFile()
}

public plugin_end()
	ArrayDestroy(g_aSounds)

public client_putinserver(id)
{
	g_bBlocked[id] = false
	UseVault(id, VAULT_READ)
}

public client_disconnect(id)
	UseVault(id, VAULT_WRITE)

UseVault(id, iType)
{
	if(!IsValidSteam(id))
		return
	
	new szAuthId[35], szData[2]
	get_user_authid(id, szAuthId, charsmax(szAuthId))
	
	switch(iType)
	{
		case VAULT_WRITE:
		{
			num_to_str(g_bBlocked[id], szData, charsmax(szData))
			nvault_set(g_iVault, szAuthId, szData)
		}
		case VAULT_READ:
		{
			nvault_get(g_iVault, szAuthId, szData, charsmax(szData))
			g_bBlocked[id] = str_to_num(szData) == 1 ? true : false
		}
	}
}
	
public OnRoundEnd()
{
	new szSound[32], iPlayers[32], iPnum, blRandom = get_pcvar_num(g_pRandom) == 1
	ArrayGetString(g_aSounds, blRandom ? random(g_iMaxSounds) : g_iSound, szSound, charsmax(szSound))
	get_players(iPlayers, iPnum)
	
	new iType = get_sound_type(szSound)
	
	for(new i, iPlayer; i < iPnum; i++)
	{
		iPlayer = iPlayers[i]
		
		if(!g_bBlocked[iPlayer])
			client_cmd(iPlayer, "%s %s", iType == TYPE_WAV ? "spk" : "mp3 play", szSound)
	}
	
	if(!blRandom)
		g_iSound = (g_iSound == g_iMaxSounds - 1) ? 0 : (g_iSound + 1)
}

public cmdMute(id)
{
	g_bBlocked[id] = g_bBlocked[id] ? false : true
	ColorChat(id, "%L", id, g_bBlocked[id] ? "REMUSIC_OFF" : "REMUSIC_ON")
	return PLUGIN_HANDLED
}

ReadFile()
{
	new szConfigsName[256], szFilename[256]
	get_configsdir(szConfigsName, charsmax(szConfigsName))
	formatex(szFilename, charsmax(szFilename), "%s/REMusic.ini", szConfigsName)
	new iFilePointer = fopen(szFilename, "rt")
	
	if(iFilePointer)
	{
		new szData[128]
		
		while(!feof(iFilePointer))
		{
			fgets(iFilePointer, szData, charsmax(szData))
			trim(szData)
			
			switch(szData[0])
			{
				case EOS, ';': continue
				default:
				{
					switch(get_sound_type(szData))
					{
						case TYPE_WAV: precache_sound(szData)
						case TYPE_MP3:
						{
							format(szData, charsmax(szData), "sound/%s", szData)
							precache_generic(szData)
						}
						case TYPE_INVALID: continue
					}
					
					ArrayPushString(g_aSounds, szData)
					g_iMaxSounds++
				}
			}
		}
		
		fclose(iFilePointer)
		
		if(!g_iMaxSounds)
			set_fail_state("No music files were added in the configuration file.")
	}
}

bool:IsValidSteam(id)
{
    new szAuthId[35]
    get_user_authid(id, szAuthId, charsmax(szAuthId))
    
    if(!equali(szAuthId, "STEAM_", 6) || equal(szAuthId, "STEAM_ID_LAN") || equal(szAuthId, "STEAM_ID_PENDING"))
        return false
    
    return true
}

get_sound_type(szSound[])
{
	switch(szSound[strlen(szSound) - 1])
	{
		case 'v', 'V': return TYPE_WAV
		case '3': return TYPE_MP3
	}
	
	return TYPE_INVALID
}

ColorChat(const id, const szInput[], any:...)
{
	new iPlayers[32], iCount = 1
	static szMessage[191]
	vformat(szMessage, charsmax(szMessage), szInput, 3)
	format(szMessage[0], charsmax(szMessage), "%s %s", g_szPrefix, szMessage)
	
	replace_all(szMessage, charsmax(szMessage), "!g", "^4")
	replace_all(szMessage, charsmax(szMessage), "!n", "^1")
	replace_all(szMessage, charsmax(szMessage), "!t", "^3")
	
	if(id)
		iPlayers[0] = id
	else
		get_players(iPlayers, iCount, "ch")
	
	for(new i, iPlayer; i < iCount; i++)
	{
		iPlayer = iPlayers[i]
		
		if(is_user_connected(iPlayer))
		{
			message_begin(MSG_ONE_UNRELIABLE, g_iSayText, _, iPlayer)
			write_byte(iPlayer)
			write_string(szMessage)
			message_end()
		}
	}
}