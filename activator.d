import core.runtime;
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

void activateHBProducts()
{
	auto hbKeys =
		(cast(string)cachedGet("https://www.humblebundle.com/home/keys"))
		.extractCapture(re!`var gamekeys =  (\[[^\]]*\]);`)
		.front
		.to!(string[]);
	writefln("Got %d HumbleBundle keys", hbKeys.length);

	activateHBKeys(hbKeys);
}

void activateHBKeys(string[] hbKeys)
{
	string[] steamKeys;
	foreach (hbKey; hbKeys)
	{
		writeln("Fetching Steam keys for HB product key: ", hbKey);
		auto res = cachedGet(cast(string)("https://www.humblebundle.com/api/v1/order/" ~ hbKey ~ "?all_tpkds=true"));
		if (verbose) writeln("\t", cast(string)res);
		auto j = parseJSON(cast(string)res);
		foreach (tpk; j["tpkd_dict"]["all_tpks"].array)
			if (tpk["key_type"].str == "steam" && "redeemed_key_val" in tpk.object)
			{
				auto steamKey = tpk["redeemed_key_val"].str;
				if (!steamKey.canFind("<a href"))
				{
					writeln("\t", "Found Steam key: ", steamKey);
					steamKeys ~= steamKey;
				}
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
		writeln("Activating Steam key: ", key);
		StdTime epoch = 0;
		while (true)
		{
			auto res = cachedPost("https://store.steampowered.com/account/ajaxregisterkey/", "product_key=" ~ key ~ "&sessionid=" ~ sessionID, epoch);
			if (verbose) writeln("\t", cast(string)res);
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
		activateSteamKeys(readText(fileName).splitLines);
	}
}

void activator(
	bool verbose,
	Parameter!(string, "Action to perform (see list below)") action = null,
	immutable(string)[] actionArguments = null,
)
{
	net.verbose = verbose;

	static void usageFun(string usage)
	{
		if (usage.canFind("ACTION [ACTION-ARGUMENTS]"))
		{
			stderr.writefln!"%-(%s\n%)\n"(
				getUsageFormatString!activator.format(Runtime.args[0]).splitLines() ~
				usage.splitLines()[1..$]
			);
		}
		else
			stderr.writeln(usage);
	}

	return funoptDispatch!(Activator, FunOptConfig.init, usageFun)([thisExePath] ~ (action ? [action.value] ~ actionArguments : []));
}

mixin main!(funopt!activator);
