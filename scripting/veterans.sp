#pragma semicolon 1
#pragma dynamic 645221
#define AUTOLOAD_EXTENSIONS
#define REQUIRE_EXTENSIONS
#define PLUGIN_VERSION "1.4"
#define MAX_FLOAT 99999999.0

#include <SteamWorks>

new String:CacheFile[PLATFORM_MAX_PATH];
new String:ExcludeFile[PLATFORM_MAX_PATH];
new bool:isBlocked = false;

new Handle:cvar_url;
new Handle:cvar_enable;
new Handle:cvar_minPlaytime;
new Handle:cvar_minPlaytimeExcludingLast2Weeks;
new Handle:cvar_cacheTime;
new Handle:cvar_connectionTimeout;
new Handle:cvar_kickWhenFailure;
new Handle:cvar_kickWhenPrivate;
new Handle:cvar_excludeReservedSlots;
new Handle:cvar_excludePrivileged;
new Handle:cvar_excludePrimes;
new Handle:cvar_kickF2P;
new Handle:cvar_banTime;
new Handle:cvar_gameId;

// --------------------------------- PLUGIN DETAILS ---------------------------------
public Plugin:myinfo = 
{
	name = "VeteransOnly",
	author = "Soroush Falahati",
	description = "Kicks the players without enough playtime in the game",
	version = PLUGIN_VERSION,
	url = "https://falahati.net/"
}

// --------------------------------- PLUGIN LOGIC ---------------------------------
public OnPluginStart()
{	
	AddServerTag2("Veterans");
	LoadTranslations("veterans.phrases");	
	CreateConVar("sm_veterans_version", PLUGIN_VERSION, "Veterans Only Version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	
	cvar_url = CreateConVar(
		"sm_veterans_url",
		"http://falahati.net/steamapi/queryPlaytime.php",
		"Address of the PHP file responsible for getting user played time.",
		FCVAR_PROTECTED
	);
	cvar_enable = CreateConVar(
		"sm_veterans_enable",
		"1",
		"Is VeteransOnly plugin enable?", 
		FCVAR_NONE, true, 0.0, true, 1.0
	);
	cvar_gameId = CreateConVar(
		"sm_veterans_gameid",
		"730",
		"Steam's store id of the game you want to check the player time of.",
		FCVAR_NONE, true, 0.0, true, MAX_FLOAT
	);
	cvar_kickWhenFailure = CreateConVar(
		"sm_veterans_kickfailure",
		"0",
		"Should we punish players when a communication failure happens?",
		FCVAR_NONE, true, 0.0, true, 1.0
	);
	cvar_kickWhenPrivate = CreateConVar(
		"sm_veterans_kickprivate",
		"0",
		"Should we punish players that have a private or friend only profile?",
		FCVAR_NONE, true, 0.0, true, 1.0
	);
	cvar_excludeReservedSlots = CreateConVar(
		"sm_veterans_excludereservedslots",
		"1",
		"Should we exclude players that have a reserved slot from punishment?",
		FCVAR_NONE, true, 0.0, true, 1.0
	);
	cvar_excludePrivileged = CreateConVar(
		"sm_veterans_excludeprivileged",
		"0",
		"Should we exclude privileged players from punishment?",
		FCVAR_NONE, true, 0.0, true, 1.0
	);
	cvar_connectionTimeout = CreateConVar(
		"sm_veterans_timeout",
		"10",
		"Maximum number of seconds till we consider the requesting connection timed out?",
		FCVAR_NONE, true, 0.0, true, 300.0
	);
	cvar_banTime = CreateConVar(
		"sm_veterans_bantime",
		"0",
		"Should me ban the player instead of kicking and if we should, for how long (in minutes)?",
		FCVAR_NONE, true, 0.0, true, MAX_FLOAT
	);
	cvar_minPlaytime = CreateConVar(
		"sm_veterans_mintotal",
		"6000",
		"Minimum total playtime amount that player needs to have (in minutes)?",
		FCVAR_NONE, true, 0.0, true, MAX_FLOAT
	);
	cvar_minPlaytimeExcludingLast2Weeks = CreateConVar(
		"sm_veterans_mintotalminuslastweeks",
		"3000",
		"Minimum total playtime amount (excluding last 2 weeks) that player needs to have (in minutes)?",
		FCVAR_NONE, true, 0.0, true, MAX_FLOAT
	);
	cvar_cacheTime = CreateConVar(
		"sm_veterans_cachetime",
		"86400",
		"Amount of time in seconds that we should not send a delicate request for the same query.",
		FCVAR_NONE, true, 0.0, true, MAX_FLOAT
	);
	cvar_excludePrimes = CreateConVar(
		"sm_veterans_excludeprimes",
		"0",
		"Should we exclude players that have a prime status from punishment?",
		FCVAR_NONE, true, 0.0, true, 1.0
	);
	cvar_kickF2P = CreateConVar(
		"sm_veterans_kickf2p",
		"0",
		"Should we punish players that are using free 2 play version of the game?",
		FCVAR_NONE, true, 0.0, true, 1.0
	);

	RegAdminCmd("sm_veterans_exclude", AddToWhitelist, ADMFLAG_GENERIC, "Exludes a user from veterans plugin", "", 0);
	RegAdminCmd("sm_veterans_include", RemoveFromWhitelist, ADMFLAG_GENERIC, "Includes an already excluded user from veterans plugin", "", 0);
	RegAdminCmd("sm_veterans_clear", ClearPlaytimeCache, ADMFLAG_GENERIC, "Clear cache", "", 0);

	AutoExecConfig(true, "veterans");
	new iPort = GetConVarInt(FindConVar("hostport"));
	BuildPath(Path_SM, CacheFile, sizeof(CacheFile), "data/veterans_cache_%d.txt", iPort);
	BuildPath(Path_SM, ExcludeFile, sizeof(ExcludeFile), "data/veterans_exclude.txt");
}

public OnPluginEnd()
{
	RemoveServerTag2("Veterans");
}

public OnMapStart()
{
	CleanupPlaytimeCache(false);

	// Disable plugin if it is used in a TF2 server, advertising Quickplay
	if (GetEngineVersion() == Engine_TF2){
		ConVar tf2QuickPlayDisable = FindConVar("tf_server_identity_disable_quickplay");
		if(tf2QuickPlayDisable != INVALID_HANDLE)
		{
			isBlocked = GetConVarInt(tf2QuickPlayDisable) == 0;
			return;
		} 
	}
	
	isBlocked = false;
}

public OnClientAuthorized(client, const String:steamId[])
{
	if (isBlocked || !GetConVarBool(cvar_enable))
	{
		return;
	}

	// Exclude bots
	if (StrEqual(steamId, "BOT", false)) {
		return;
	}

	new adminId = GetUserAdmin(client);

	if (adminId != INVALID_ADMIN_ID) {
		// Exclude privileged
		if (GetConVarBool(cvar_excludePrivileged)) {
			return;
		}
		
		// Exclude reserved slots
		if (GetConVarBool(cvar_excludeReservedSlots) && GetAdminFlag(adminId, ADMFLAG_RESERVATION)) {
			return;
		}

		// Exclude admins
		if (GetAdminFlag(adminId, ADMFLAG_GENERIC) || GetAdminFlag(adminId, ADMFLAG_ROOT)) {
			return;
		}
	}

	// Exclude whitelisted
	if (IsWhitelisted(steamId)) {
		return;
	}
	
	EngineVersion engine = GetEngineVersion();
	if (engine == Engine_CSGO || engine == Engine_TF2) {
		new isPrime = engine == Engine_CSGO ?
			SteamWorks_HasLicenseForApp(client, 624820) == k_EUserHasLicenseResultHasLicense :
			SteamWorks_HasLicenseForApp(client, 459) == k_EUserHasLicenseResultHasLicense;

		if (GetConVarBool(cvar_excludePrimes) && isPrime) {
			return;
		}

		if (GetConVarBool(cvar_kickF2P) && !isPrime) {
			decl String:formated[128];
			Format(formated, sizeof(formated), "%T", "PRIMENEEDED", client);
			ThrowPlayerOut(client, formated);
		}
	}

	if (engine == Engine_TF2) {

	}

	new totalTime, last2WeeksTime;
	if (QueryCachedPlayTime(SteamIdToInt(steamId), totalTime, last2WeeksTime))
	{
		PrintToServer("VeteransOnly: New client, playtime loaded from cache for SteamId %s", steamId);
		CheckUserPlaytime(client, totalTime, last2WeeksTime);
	} else {
		PrintToServer("VeteransOnly: New client, requesting playtime for SteamId %s", steamId);
		RequestUserInfo(client, steamId);
	}
}

// --------------------------------- PLAYER TIME DECISION ---------------------------------
CheckUserPlaytime(client, totalTime, last2WeeksTime)
{
	if (HasEnoughPlaytime(totalTime, last2WeeksTime))
	{
		return;
	}

	float minPlaytime = GetConVarFloat(cvar_minPlaytime) / 60;
	float minPlaytimeExcludingLast2Weeks = GetConVarFloat(cvar_minPlaytimeExcludingLast2Weeks) / 60;
	decl String:formated[256];
	Format(
		formated, 
		sizeof (formated),
		"%T", 
		"REJECTED", 
		client, 
		minPlaytime, 
		minPlaytimeExcludingLast2Weeks
	);
	ThrowPlayerOut(client, formated);	
}

bool:HasEnoughPlaytime(int totalTime, int last2WeeksTime)
{
	PrintToServer("VeteransOnly: Deciding for Total of %d minutes, last two weeks %d minutes", totalTime, last2WeeksTime);

	float minPlaytime = GetConVarFloat(cvar_minPlaytime);
	float minPlaytimeExcludingLast2Weeks = GetConVarFloat(cvar_minPlaytimeExcludingLast2Weeks);
	int playtimeExcludingLast2Weeks = totalTime > last2WeeksTime ? totalTime - last2WeeksTime : 0;

	return totalTime >= minPlaytime && playtimeExcludingLast2Weeks >= minPlaytimeExcludingLast2Weeks;
}

// --------------------------------- PLAYER EXCEPTIONS ---------------------------------
public Action:AddToWhitelist(int client, int args)
{
	if (args < 1) {
		ReplyToCommand(client, "Usage: !sm_veterans_exclude <steamid1> <steamid2> ...");
		return Plugin_Handled;
	}

	new Handle:kv = CreateKeyValues("VeteranExcludedPlayers");
	FileToKeyValues(kv, ExcludeFile);

	do
	{
		decl String:steamId[32];
		if (GetCmdArg(args, steamId, strlen(steamId)) == 18) {
			KvJumpToKey(kv, steamId, true);
			KvSetNum(kv, "Excluded", 1);
			KvRewind(kv);

			decl String:formated[256];
			Format(
				formated,
				sizeof(formated),
				"%T",
				"EXCLUDED", 
				client,
				steamId
			);
			ReplyToCommand(client, formated);
		}
		args--;
	} while (args > 0);

	KeyValuesToFile(kv, ExcludeFile);
	CloseHandle(kv);
	return Plugin_Handled;
} 

public Action:RemoveFromWhitelist(int client, int args)
{
	if (args < 1) {
		ReplyToCommand(client, "Usage: !sm_veterans_include <steamid1> <steamid2> ...");
		return Plugin_Handled;
	}

	new Handle:kv = CreateKeyValues("VeteranExcludedPlayers");
	FileToKeyValues(kv, ExcludeFile);

	do
	{
		decl String:steamId[32];
		if (GetCmdArg(args, steamId, strlen(steamId)) == 18) {
			if (KvJumpToKey(kv, steamId, false)) {
				KvSetNum(kv, "Excluded", 0);
				KvDeleteThis(kv);
				KvRewind(kv);
			}
			decl String:formated[256];
			Format(
				formated,
				sizeof(formated),
				"%T",
				"INCLUDED", 
				client,
				steamId
			);
			ReplyToCommand(client, formated);
		}
		args--;
	} while (args > 0);

	KeyValuesToFile(kv, ExcludeFile);
	CloseHandle(kv);
	return Plugin_Handled;
}

bool:IsWhitelisted(const String:steamId[]) 
{
	new Handle:kv = CreateKeyValues("VeteranExcludedPlayers");
	FileToKeyValues(kv, ExcludeFile);

	if (!KvJumpToKey(kv, steamId)) {
		CloseHandle(kv);
		return false;
	}

	if (KvGetNum(kv, "Excluded") > 0) {
		CloseHandle(kv);
		return true;
	} else {
		CloseHandle(kv);
		return false;
	}
}

// --------------------------------- WEB COMMUNICATION ---------------------------------
RequestUserInfo(client, const String:steamId[])
{
	decl String:gameId[16];
	IntToString(GetConVarInt(cvar_gameId), gameId, sizeof gameId);
	decl String:maxTotal[16];
	IntToString(GetConVarInt(cvar_minPlaytime), maxTotal, sizeof maxTotal);
	decl String:maxTotalNo2Weeks[16];
	IntToString(GetConVarInt(cvar_minPlaytimeExcludingLast2Weeks), maxTotalNo2Weeks, sizeof maxTotalNo2Weeks);
	
	decl String:url[256];
	GetConVarString(cvar_url, url, sizeof url);
	new Handle:hRequest = SteamWorks_CreateHTTPRequest(EHTTPMethod:k_EHTTPMethodGET, url);
	
	SteamWorks_SetHTTPRequestNetworkActivityTimeout(hRequest, GetConVarInt(cvar_connectionTimeout));
	
	SteamWorks_SetHTTPRequestGetOrPostParameter(hRequest, "gameId", gameId);
	SteamWorks_SetHTTPRequestGetOrPostParameter(hRequest, "steamId", steamId);
	SteamWorks_SetHTTPRequestGetOrPostParameter(hRequest, "maxTotal", maxTotal);
	SteamWorks_SetHTTPRequestGetOrPostParameter(hRequest, "maxTotalNo2Weeks", maxTotalNo2Weeks);

	SteamWorks_SetHTTPCallbacks(hRequest, UserInfoRetrieved);
	SteamWorks_SetHTTPRequestContextValue(hRequest, SteamIdToInt(steamId), GetClientUserId(client));
	
	SteamWorks_SendHTTPRequest(hRequest);
}

public UserInfoRetrieved(Handle:HTTPRequest, bool:bFailure, bool:bRequestSuccessful, EHTTPStatusCode:eStatusCode, any:steamIntId, any:userId)
{
	new client = GetClientOfUserId(userId);
	if(!client)
	{
		CloseHandle(HTTPRequest);
		return;
	}

	if(!bRequestSuccessful || eStatusCode != EHTTPStatusCode:k_EHTTPStatusCode200OK)
	{
		if(bRequestSuccessful)
		{
			CloseHandle(HTTPRequest);
		}

		if (GetConVarBool(cvar_kickWhenFailure))
		{	
			decl String:formated[128];
			Format(formated, sizeof(formated), "%T", "ERROR", client);
			ThrowPlayerOut(client, formated);
		}

		LogError("VeteransOnly: Failed to retrieve user's playtime (HTTP status: %d)", eStatusCode);
		return;
	}
	
	new totalTime, last2WeeksTime;

	new iBodySize;
	if (SteamWorks_GetHTTPResponseBodySize(HTTPRequest, iBodySize))
	{
		decl String:sBody[iBodySize + 1];
		SteamWorks_GetHTTPResponseBodyData(HTTPRequest, sBody, iBodySize);
		if (iBodySize <= 4 || StrEqual(sBody, "||"))
		{
			if (GetConVarBool(cvar_kickWhenPrivate))
			{
				decl String:formated[128];
				Format(formated, sizeof(formated), "%T", "PRIVATEPROFILE", client);
				ThrowPlayerOut(client, formated);
			}
			return;
		} else if (StrContains(sBody, "|") >= 0) {
			decl String:times[4][10];
			ExplodeString(sBody, "|", times, sizeof times, sizeof times[]);
			totalTime = StringToInt(times[1]);
			last2WeeksTime = StringToInt(times[2]);
			CachePlaytime(steamIntId, totalTime, last2WeeksTime);
			CheckUserPlaytime(client, totalTime, last2WeeksTime);
			return;
		}
	}

	if (GetConVarBool(cvar_kickWhenFailure))
	{
		decl String:formated[128];
		Format(formated, sizeof(formated), "%T", "ERROR", client);
		ThrowPlayerOut(client, formated);
	}
}

// --------------------------------- PLAYER TIME CACHE ---------------------------------
public Action:ClearPlaytimeCache(client, int args)
{
	CleanupPlaytimeCache(true);
}

CleanupPlaytimeCache(bool:clearAll)
{
	new Handle:kv = CreateKeyValues("VeteranPlayersCache");
	FileToKeyValues(kv, CacheFile);
 	if (!KvGotoFirstSubKey(kv))
	{
		return;
	}

	new lastUpdate, totalTime, last2WeeksTime, maxTime, currentTime;
	maxTime = GetConVarInt(cvar_cacheTime);
	currentTime = GetTime();
	do
	{
		lastUpdate =		KvGetNum(kv, "LastUpdate");
		totalTime =			KvGetNum(kv, "TotalTime");
		last2WeeksTime =	KvGetNum(kv, "Last2WeeksTime");
		if ((clearAll || lastUpdate + maxTime < currentTime) && !HasEnoughPlaytime(totalTime, last2WeeksTime))
		{
			KvDeleteThis(kv);
		}
	} while (KvGotoNextKey(kv));
	KvRewind(kv);
	KeyValuesToFile(kv, CacheFile);
	CloseHandle(kv);
}

CachePlaytime(int steamIntId, int totalTime, int last2WeeksTime)
{
	decl String:steamId[32];
	IntToString(steamIntId, steamId, sizeof steamId);

	new Handle:kv = CreateKeyValues("VeteranPlayersCache");
	FileToKeyValues(kv, CacheFile);
	KvJumpToKey(kv, steamId, true);
	KvSetNum(kv, "LastUpdate", GetTime());
	KvSetNum(kv, "TotalTime", totalTime);
	KvSetNum(kv, "Last2WeeksTime", last2WeeksTime);
	KvRewind(kv);
	KeyValuesToFile(kv, CacheFile);
	CloseHandle(kv);
}

bool:QueryCachedPlayTime(int steamIntId, int &totalTime, int &last2WeeksTime)
{
	decl String:steamId[32];
	IntToString(steamIntId, steamId, sizeof steamId);

	totalTime = 0;
	last2WeeksTime = 0;
	new Handle:kv = CreateKeyValues("VeteranPlayersCache");
	FileToKeyValues(kv, CacheFile);
	if (!KvJumpToKey(kv, steamId))
	{
		CloseHandle(kv);
		return false;
	}
	totalTime =			KvGetNum(kv, "TotalTime");
	last2WeeksTime =	KvGetNum(kv, "Last2WeeksTime");
	CloseHandle(kv);
	return true;
}

// --------------------------------- HELPER FUNCTIONS ---------------------------------
int SteamIdToInt(const String:steamId[])
{
    decl String:subinfo[3][16];
    ExplodeString(steamId, ":", subinfo, sizeof subinfo, sizeof subinfo[]);
    return (StringToInt(subinfo[2]) * 2) + StringToInt(subinfo[1]);
}

ThrowPlayerOut(client, const String:reason[])
{
	int banTime = GetConVarInt(cvar_banTime);
	if (banTime > 0)
	{
		BanClient(client, banTime, BANFLAG_AUTHID, reason, reason);
	}
	else
	{
		KickClient(client, reason);
	}
}

// --------------------------------- SERVER TAGS ---------------------------------
stock AddServerTag2(const String:tag[])
{
    new Handle:hTags = INVALID_HANDLE;
    hTags = FindConVar("sv_tags");
    if(hTags != INVALID_HANDLE)
    {
        new String:tags[256];
        GetConVarString(hTags, tags, sizeof(tags));
        if(StrContains(tags, tag, true) > 0) return;
        if(strlen(tags) == 0)
        {
            Format(tags, sizeof(tags), tag);
        }
        else
        {
            Format(tags, sizeof(tags), "%s,%s", tags, tag);
        }
        SetConVarString(hTags, tags, true);
    }
}

stock RemoveServerTag2(const String:tag[])
{
    new Handle:hTags = INVALID_HANDLE;
    hTags = FindConVar("sv_tags");
    if(hTags != INVALID_HANDLE)
    {
        decl String:tags[50]; //max size of sv_tags cvar
        GetConVarString(hTags, tags, sizeof(tags));
        if(StrEqual(tags, tag, true))
        {
            Format(tags, sizeof(tags), "");
            SetConVarString(hTags, tags, true);
            return;
        }
        new pos = StrContains(tags, tag, true);
        new len = strlen(tags);
        if(len > 0 && pos > -1)
        {
            new bool:found;
            decl String:taglist[50][50];
            ExplodeString(tags, ",", taglist, sizeof(taglist[]), sizeof(taglist));
            for(new i;i < sizeof(taglist[]);i++)
            {
                if(StrEqual(taglist[i], tag, true))
                {
                    Format(taglist[i], sizeof(taglist), "");
                    found = true;
                    break;
                }
            }    
            if(!found) return;
            ImplodeStrings(taglist, sizeof(taglist[]), ",", tags, sizeof(tags));
            if(pos == 0)
            {
                tags[0] = 0x20;
            }    
            else if(pos == len-1)
            {
                Format(tags[strlen(tags)-1], sizeof(tags), "");
            }    
            else
            {
                ReplaceString(tags, sizeof(tags), ",,", ",");
            }    
            SetConVarString(hTags, tags, true);
        }
    }    
}  