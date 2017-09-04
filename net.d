import std.algorithm.comparison;
import std.array;
import std.conv;
import std.file;
import std.net.curl;
import std.path;

import ae.sys.file;
import ae.sys.paths;
import ae.utils.digest;
import ae.utils.time : StdTime;

static HTTP http;
static this() { http = HTTP(); }

/*private*/ void req(string url, HTTP.Method method, const(void)[] data, string target)
{
	http.verbose = true;
	http.method = method;

	http.clearRequestHeaders();
	auto host = url.split("/")[2];
	auto cookiePath = buildPath("cookies", host);
	if (cookiePath.exists)
		http.addRequestHeader("Cookie", cookiePath.readText);

	if (data)
	{
		http.addRequestHeader("Content-Length", data.length.text);
		http.onSend = (void[] buf)
			{
				size_t len = min(buf.length, data.length);
				buf[0..len] = data[0..len];
				data = data[len..$];
				return len;
			};
	}
	else
		http.onSend = null;
	download!HTTP(url, target, http);
}

private ubyte[] cachedReq(string url, HTTP.Method method, in void[] data, StdTime epoch)
{
	auto hash = getDigestString!MD5(url ~ data);
	auto path = buildPath("cache", hash);
	ensurePathExists(path);
	if (path.exists && path.timeLastModified.stdTime < epoch)
		path.remove();
	cached!req(url, method, data, path);
	return cast(ubyte[])read(path);
}

ubyte[] cachedGet(string url, StdTime epoch = 0)
{
	return cachedReq(url, HTTP.Method.get, null, epoch);
}

ubyte[] cachedPost(string url, in void[] data, StdTime epoch = 0)
{
	return cachedReq(url, HTTP.Method.post, data, epoch);
}
