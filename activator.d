import core.runtime;
import core.thread;

import std.algorithm.iteration;
import std.algorithm.searching;
import std.array;
import std.conv;
import std.datetime.systime;
import std.file;
import std.json;
import std.net.curl;
import std.path;
import std.stdio : stderr, File;
import std.string;
import std.typecons;

import ae.sys.file;
import ae.sys.net;
import ae.sys.net.cachedcurl;
import ae.utils.digest;
import ae.utils.funopt;
import ae.utils.main;
import ae.utils.regex;
import ae.utils.time;

bool verbose;
CachedCurlNetwork ccnet;

void activateHBProducts()
{
	scope(failure) stderr.writeln("Error extracting Humble Bundle keys array. Make sure you are logged in and your cookies file is up to date.");
	auto hbKeys =
		(cast(string)ccnet.getFile("https://www.humblebundle.com/home/keys"))
		.extractCapture(re!`"gamekeys": (\[[^\]]*\]), `)
		.front
		.to!(string[]);
	stderr.writefln!"Got %d HumbleBundle keys"(hbKeys.length);

	activateHBKeys(hbKeys);
}

struct SteamKey
{
	string key;
	string name;

	string toString() { return name ? format!"%s (%s)"(key, name) : key; }
}

void activateHBKeys(string[] hbKeys)
{
	SteamKey[] steamKeys;
	foreach (n, hbKey; hbKeys)
	{
		stderr.writefln!"[%d/%d] Fetching Steam keys for HB product key: %s"(n+1, hbKeys.length, hbKey);
		auto res = getFile(cast(string)("https://www.humblebundle.com/api/v1/order/" ~ hbKey ~ "?all_tpkds=true"));
		if (verbose) stderr.writeln("\t", cast(string)res);
		auto j = parseJSON(cast(string)res);
		foreach (tpk; j["tpkd_dict"]["all_tpks"].array)
			if (tpk["key_type"].str == "steam" && "redeemed_key_val" in tpk.object)
			{
				auto steamKey = tpk["redeemed_key_val"].str;
				if (!steamKey.canFind("<a href"))
				{
					stderr.writeln("\t", "Found Steam key: ", steamKey);
					steamKeys ~= SteamKey(steamKey, "human_name" in tpk ? tpk["human_name"].str : null);
				}
			}
	}

	activateSteamKeys(steamKeys);
}

void activateSteamKeys(SteamKey[] steamKeys)
{
	auto sessionID =
		(cast(string)getFile("https://store.steampowered.com/account/registerkey"))
		.extractCapture(re!`var g_sessionID = "([^"]*)";`)
		.front;
	stderr.writeln("Got Steam session ID: ", sessionID);

	enum resultFile = "results.txt";
	string[][] results;
	if (resultFile.exists)
		results = resultFile.readText.splitLines.map!(s => s.split("\t")).array;

	foreach (n, key; steamKeys)
	{
		stderr.writefln!"[%d/%d] Activating Steam key: %s"(n+1, steamKeys.length, key);
		auto existingResult = results.find!(result => result[0] == key.key);
		if (!existingResult.empty)
		{
			stderr.writeln("\t", "Already activated (", existingResult.front[1], ")");
			continue;
		}

		ccnet.epoch = 0;
		scope(exit) ccnet.epoch = 0;
		while (true)
		{
			auto res = post("https://store.steampowered.com/account/ajaxregisterkey/", "product_key=" ~ key.key ~ "&sessionid=" ~ sessionID);
			if (verbose) stderr.writeln("\t", cast(string)res);
			auto j = parseJSON(cast(string)res);
			auto code = j["purchase_result_details"].integer;
			switch (code)
			{
				case 0:
					stderr.writeln("\t", "Activated successfully!");
					File(resultFile, "a").writefln!"%s\t%s\t%s"(key.key, "Activated", key.name);
					break;
				case 9:
					stderr.writeln("\t", "Already have this product");
					File(resultFile, "a").writefln!"%s\t%s\t%s"(key.key, "Already owned", key.name);
					break;
				case 24:
					stderr.writeln("\t", "Need another product");
					File(resultFile, "a").writefln!"%s\t%s\t%s"(key.key, "Need another", key.name);
					break;
				case 53:
					stderr.writeln("\t", "Throttled, waiting...");
					Thread.sleep(5.minutes);
					ccnet.epoch = Clock.currStdTime;
					continue;
				default:
					throw new Exception("Unknown code: " ~ text(code));
			}
			break;
		}
	}
}

struct Activator
{
static:
	@(`Activate all Steam keys from your HumbleBundle library`)
	void humbleBundle()
	{
		activateHBProducts();
	}

	@(`Activate Steam keys from HumbleBundle product keys from file`)
	void hbKeys(
		Parameter!(string, "Text file containing HumbleBundle product keys, one per line") fileName
	)
	{
		activateHBKeys(readText(fileName).splitLines);
	}

	@(`Activate Steam keys from file`)
	void steamKeys(
		Parameter!(string, "Text file containing Steam keys, one per line") fileName
	)
	{
		activateSteamKeys(readText(fileName).splitLines.map!(line => SteamKey(line)).array);
	}
}

void usageFun(string usage)
{
	stderr.writeln(usage, funoptDispatchUsage!Activator);
}

void dispatch(
	bool verbose,
	Parameter!(string, "Action to perform (see list below)") action,
	immutable(string)[] actionArguments = null,
)
{
	ccnet = cast(CachedCurlNetwork)net;
	ccnet.http.verbose = verbose;
	ccnet.cookieDir = "cookies";
	ccnet.cookieExt = ".txt";
	funoptDispatch!Activator([thisExePath, action] ~ actionArguments);
}

void run(string[] args)
{
	funopt!(dispatch, FunOptConfig.init, usageFun)(args);
}

mixin main!run;
