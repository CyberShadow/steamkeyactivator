import core.thread;

import std.algorithm.searching;
import std.array;
import std.conv;
import std.datetime.systime;
import std.file;
import std.json;
import std.net.curl;
import std.path;
import std.stdio;
import std.string;

import ae.sys.file;
import ae.utils.digest;
import ae.utils.funopt;
import ae.utils.main;
import ae.utils.regex;
import ae.utils.time;

import net;

void activateHBKeys(string[] hbKeys)
{
	string[] steamKeys;
	foreach (hbKey; hbKeys)
	{
		writeln(hbKey);
		auto res = cachedGet(cast(string)("https://www.humblebundle.com/api/v1/order/" ~ hbKey ~ "?all_tpkds=true"));
		auto j = parseJSON(cast(string)res);
		foreach (tpk; j["tpkd_dict"]["all_tpks"].array)
			if (tpk["key_type"].str == "steam" && "redeemed_key_val" in tpk.object)
			{
				auto steamKey = tpk["redeemed_key_val"].str;
				if (!steamKey.canFind("<a href"))
					steamKeys ~= steamKey;
			}
	}

	activateSteamKeys(steamKeys);
}

void activateSteamKeys(string[] steamKeys)
{
	auto sessionID =
		(cast(string)cachedGet("https://store.steampowered.com/account/registerkey"))
		.extractCapture(re!`var g_sessionID = "([^"]*)";`)
		.front;
	writeln("Got Steam session ID: ", sessionID);

	foreach (key; steamKeys)
	{
		writeln(key);
		StdTime epoch = 0;
		while (true)
		{
			auto res = cachedPost("https://store.steampowered.com/account/ajaxregisterkey/", "product_key=" ~ key ~ "&sessionid=" ~ sessionID, epoch);
			writeln("\t", cast(string)res);
			auto j = parseJSON(cast(string)res);
			auto code = j["purchase_result_details"].integer;
			switch (code)
			{
				case 0:
					writeln("\t", "Activated successfully!");
					break;
				case 9:
					writeln("\t", "Already have this product");
					break;
				case 53:
					writeln("\t", "Throttled, waiting...");
					Thread.sleep(5.minutes);
					epoch = Clock.currStdTime;
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
	@(`Activate Steam keys from HumbleBundle product keys from file`)
	void hbKeys(string fileName)
	{
		activateHBKeys(readText(fileName).splitLines);
	}

	@(`Activate Steam keys from file`)
	void steamKeys(string fileName)
	{
		activateSteamKeys(readText(fileName).splitLines);
	}
}

mixin main!(funoptDispatch!Activator);
