<?php
error_reporting(E_ALL);
ini_set("display_errors", 0);
ini_set("log_errors", 1);
ini_set("error_log", "php-error.log");

function Handle()
{
	if (!isset($_GET['steamId']) || !isset($_GET['gameId']))
	{
		header('X-PHP-Response-Code: 406', true, 406);
		return "";
	}

	$steamId = trim(strtoupper($_GET['steamId']));
	$gameId = intval($_GET['gameId']);
	$communityId = GetFriendId($steamId);

	if (!$gameId || !$communityId)
	{
		header('X-PHP-Response-Code: 406', true, 406);
		return "";
	}
	
	$url = "http://steamcommunity.com/profiles/" . $communityId . "/games/?tab=all&xml=1";
	$cacheFile = __DIR__ . DIRECTORY_SEPARATOR . "WebCache" . DIRECTORY_SEPARATOR . "$communityId.$gameId";
	if (IsCacheAvailable($cacheFile, 60))
	{
		$content = @file_get_contents($cacheFile);
		if ($content)
		{
			return $content;
		}
	}
	
	$endUrl = $url;
	$content = DownloadWithCurl($url, $endUrl);
	if ($content === false)
	{
		header('X-PHP-Response-Code: 502', true, 502);
		return "";
	}
	
	if (
		!$content || 
		strpos(strtolower($endUrl), "/games") === false || 
		strpos(strtolower($endUrl), "tab=all") === false || 
		strpos(strtolower($content), "<error>") !== false || 
		!($result = ParseXML($content, $gameId))
	)
	{
		return "";
	}
	
	// Cache only if the result is valid
	if ($result != "0|0") {
		@file_put_contents($cacheFile, $result);
	}
	
	return $result;
}

function ParseXML($xml, $gameId)
{
	$data = new SimpleXMLElement($xml);
	if (!$data)
	{
		return false;
	}
	
	$result = $data->xpath('(//gamesList/games/game[appID = "' . $gameId . '"])[1]');
	if (count($result) != 1)
	{
		return "0|0";
	}
	
	$result = $result[0];
	$hoursOnRecord = isset($result->hoursOnRecord) ? ParseAsMinutes($result->hoursOnRecord) : 0;
	$hoursLast2Weeks = isset($result->hoursLast2Weeks) ? ParseAsMinutes($result->hoursLast2Weeks) : 0;
	return sprintf("%d|%d", $hoursOnRecord, $hoursLast2Weeks);
}

function GetFriendId($steamId)
{
	$gameType = 0;
	$authServer = 0;
	$clientId = '';
	$steamId = str_replace('STEAM_', '', $steamId);

	$parts = explode(':', $steamId);
	if (count($parts) != 3)
	{
		return false;
	}
	
	$gameType = intval($parts[0]);
	$authServer = intval($parts[1]);
	$clientId = intval($parts[2]);
	if (!$clientId || $authServer > 1 || $authServer < 0)
	{
		return false;
	}
	return 76561197960265728 + (2 * $clientId) + $authServer;
	return($result);
}

function ParseAsMinutes($str)
{
	$str = filter_var($str, FILTER_SANITIZE_NUMBER_FLOAT, FILTER_FLAG_ALLOW_FRACTION);
	if ($str = floatval($str))
	{
		return (int)($str * 60);
	}
	return 0;
}

function IsCacheAvailable($file, $mins = 60)
{
	$current_time = time(); 
	$expire_time = $mins * 60; 
	return @file_exists($file) && ($current_time - $expire_time < @filemtime($file));
}

function DownloadWithCurl($url, &$endUrl)
{
	$ch = curl_init();
	curl_setopt($ch, CURLOPT_URL, $url);
	curl_setopt($ch, CURLOPT_HEADER, false);
	curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
	curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
	$a = curl_exec($ch);
	$endUrl = curl_getinfo($ch, CURLINFO_EFFECTIVE_URL);
	curl_close($ch);
	return $a;
}

echo "|" . Handle() . "|";
die;