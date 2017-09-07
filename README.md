Steam Key Activator
===================

Activates your Steam keys from HumbleBundle on Steam.

## Usage

```
Usage: activator [--verbose] [ACTION] [ACTION-ARGUMENTS]...

Options:
  ACTION  Action to perform (see list below)

Actions:
  humble-bundle  Activate all Steam keys from your HumbleBundle library
  hb-keys        Activate Steam keys from HumbleBundle product keys from file
  steam-keys     Activate Steam keys from file
```

## Building

1. Install [DMD](https://dlang.org/download.html) and [Dub](http://code.dlang.org/download):

   - Windows: Download and run the [installer](https://dlang.org/download.html)

   - macOS:

         brew install dmd dub

   - Arch Linux:

         pacaur -S dmd dub

   - Anything else:

         curl -fsS https://dlang.org/install.sh | bash -s dmd

2. Run `dub build`.

## Configuration

To allow the program to access your Steam and HumbleBundle accounts, you must export your cookies from said websites from your web browser.

Instructions:

1. Visit https://store.steampowered.com/ in your web browser of choice.
2. Ensure that you are logged in. If you aren't, log in now.
3. Open the Developer Console or equivalent (usually done by pressing <kbd>F12</kbd>).
4. Open the "Network" tab in the Developer Console (or equivalent).
5. Reload the page.
6. Click on the very first request added to the request list, which should be for the https://store.steampowered.com/ page.
7. Find the "Request headers" pane in the Developer Console or equivalent.
8. Find the "Cookie" header within.
9. Copy the value of the cookie header.
10. Create the text file `cookies/store.steampowered.com.txt` under this project's directory.
11. Paste the value of the cookie header.
12. Repeat the above steps substituting `store.steampowered.com` with `www.humblebundle.com`.

Log in sessions may expire after a few days, so you may need to repeat the above steps should the program stop working.

## Cache

To prevent redoing previous work, this program will aggressively cache all requests to Steam and HumbleBundle. Delete the `cache/` directory to force the program to re-check for new keys.

In addition to the cache, the program will save a report of key activations to the file `results.txt`, and will skip over keys listed in that file.

## Notes

* Steam's key activation is severely throttled. After 10 unsuccessful key activations, no keys can be activated for an hour. This program will keep retrying until the cooldown expires, however activating a lot of keys may take up to several days.

* This program will not redeem unredeemed Steam keys from your HumbleBundle library. If you wish to redeem all Steam keys, you must first go through https://www.humblebundle.com/home/keys and click on all "Activate on Steam" buttons yourself. This must be done manually because this action is not undoable, and precludes gifting the game key using HumbleBundle's website to someone else.

## Troubleshooting

* Run the program with the `--verbose` switch to enable verbose mode. This will show details for all HTTP requests.

* Cached responses may contain additional information. The program will print URLs and file names their responses are cached to in verbose mode.
