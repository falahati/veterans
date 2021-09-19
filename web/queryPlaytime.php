<?php
error_reporting(E_ALL);
ini_set("display_errors", 0);
ini_set("log_errors", 1);
ini_set("error_log", "php-error.log");

function Handle()
{
	if (!isset($_GET['key']) || !isset($_GET['steamId']) || !isset($_GET['gameId']))
	{
		header('X-PHP-Response-Code: 406', true, 406);
		goto returnFinally;
	}

	$key = trim(strtoupper($_GET['key']));
	$steamId = trim(strtoupper($_GET['steamId']));
	$gameId = intval($_GET['gameId']);
	$communityId = GetFriendId($steamId);

	if (!$key || !$gameId || !$communityId)
	{
		header('X-PHP-Response-Code: 406', true, 406);
		goto returnFinally;
	}

	$cacheFile = __DIR__ . DIRECTORY_SEPARATOR . "WebCache" . DIRECTORY_SEPARATOR . "$communityId.$gameId";
	if (IsCacheAvailable($cacheFile, 60))
	{
		$cachedResult = @file_get_contents($cacheFile);
		if ($cachedResult)
		{
			return $cachedResult;
		}
	}

	// --------------- Query play time ---------------
	// encoded json: {"steamid":xxxxxxxxxxxxxxxxx,"appids_filter":[xxx]}
	$playtime_query =
		"http://api.steampowered.com/IPlayerService/GetOwnedGames/v1/?key="
		. $key . "&format=json&input_json=%7B%22steamid%22%3A"
		. $communityId . "%2C%22appids_filter%22%3A%5B"
		. $gameId . "%5D%7D";

	$playtime_json = @file_get_contents($playtime_query);

	$playtime_struct = json_decode($playtime_json);
	$totalTime = $playtime_struct->response->games[0]->playtime_forever ?? 0;
	$recentTime = $playtime_struct->response->games[0]->playtime_2weeks ?? 0;

	// --------------- Query membership (optional) ---------------
	if (isset($_GET['groupId']))
	{
		$groupId = trim($_GET['groupId']);

		$groups_query =
			"http://api.steampowered.com/ISteamUser/GetUserGroupList/v1/?key="
			. $key . "&format=json&steamid="
			. $communityId;

		$groups_json = @file_get_contents($groups_query);

		// Failed to reach
		if ($groups_json === false)
		{
			goto returnFinally;
		}

		if (strpos($groups_json, $groupId) !== false)
		{
			$isGroupMember = 1;
		}
	}

	returnFinally:
	$result = sprintf("|%d|%d|%d|",
		$totalTime ?? 0, $recentTime ?? 0, $isGroupMember ?? 0);
	if (strcmp($result, "|0|0|0|") !== 0) // Cache only if the result is valid
	{
		@file_put_contents($cacheFile, $result);
	}

	return $result;
}

function GetFriendId($steamId)
{
	$authServer = 0;
	$clientId = '';
	$steamId = str_replace('STEAM_', '', $steamId);

	$parts = explode(':', $steamId);
	if (count($parts) != 3)
	{
		return false;
	}
	
	$authServer = intval($parts[1]);
	$clientId = intval($parts[2]);
	if (!$clientId || $authServer > 1 || $authServer < 0)
	{
		return false;
	}
	
	return 76561197960265728 + (2 * $clientId) + $authServer;
}

function IsCacheAvailable($file, $mins = 60)
{
	$current_time = time(); 
	$expire_time = $mins * 60; 
	return @file_exists($file) && ($current_time - $expire_time < @filemtime($file));
}

echo Handle();
die;