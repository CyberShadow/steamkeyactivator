import core.thread;

import std.algorithm.searching;
import std.array;
import std.datetime.systime;
import std.file;
import std.json;
import std.net.curl;
import std.path;
import std.stdio;

import ae.sys.file;
import ae.utils.digest;
import ae.utils.time;

import net;

void main()
{
	string[] steamKeys;
	foreach (hbKey; File("hbkeys.txt").byLine)
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

	auto sessionID = readText("sessionid.txt");

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
				case 9:
					writeln("\t", "Already activated");
					break;
				case 53:
					writeln("\t", "Throttled, waiting...");
					Thread.sleep(1.minutes);
					epoch = Clock.currStdTime;
					continue;
				default:
					writeln("\t", "Unknown code: ", code);
					break;
			}
			break;
		}
	}
}
