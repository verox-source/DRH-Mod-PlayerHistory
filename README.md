# PlayerHisotry-by-verox
# Player History

GPL-3.0 license

A mod for [Dungeon Rampage Haxe](https://github.com/Tutez64/Dungeon-Rampage-Haxe): remembers the players you have met in dungeons and gives you a clean, live board in town. No more trying to remember the name of that person who carried you through a boss floor.

<!-- drh:show -->

## What it does

Every non-local player you meet in a dungeon is remembered: name, hero and level (with the ascension number when they ascended), how many dungeons you played together, the last map, and when. A run counts once, whether you leave for town or go straight to the next dungeon.

In town, a round two-player button on the home screen (under the Ultimate Records one) opens the board. The default key is **H** and it can be changed like the other mods' keys. **Escape** closes the board.

The board has a white-and-ice-blue look, a soft green **LIVE** pip, a gold star for friends, and columns that stay readable. It scales to fit your screen. The open tab refreshes twice a second, so presence and times stay current without flickering the whole board.

<!-- /drh:show -->

## The four tabs

| Tab | What it shows |
| --- | --- |
| RECENT | The players you met most recently. |
| REPEATS | The players you played with the most, highest count first. |
| FRIENDS | Your friends from the history, newest first. |
| MANAGER | Friends only, sorted by Online Tracker activity, for bulk actions. |

## Row actions

Each row has small buttons, where useful:

- **JOIN** — highlighted when that friend is in a dungeon. Works from town, needs a weapon equipped, and enters their dungeon through the game's normal join flow.
- **ADD** — sends a friend request, then shows **SENT** for the rest of the session.
- **BLOCK** — asks first with the game's own confirmation popup. A blocked player shows **BLOCKED**.
- **REMOVE** — press once, then **SURE?** the second time. This removes the player from *your history* only.
- **UNFRIEND** (manager only) — removes the friendship on the server with the game's confirmation popup. The player stays in your history.

A small light beside online/in-dungeon friends shows their presence at a glance.

## Search, counts and live status

The search box matches any part of a name, hero or map. Press **/** while the board is open to focus it.

A strip at the top counts **TOTAL**, **FRIENDS**, **IN DUNGEONS**, **REPEATS** and players seen in the last **24H**. It sits above the rows so it never overlaps the PREV/NEXT buttons. Temporary JOIN messages put the counts back automatically after a couple of seconds.

On the MANAGER tab, the last column is **ONLINE** and shows the last-online date recorded by the **Online Tracker** mod, or `NEVER` if there is no record. The live light is still there.

## Manager and activity sorting

MANAGER is friends-only. By default it sorts by Online Tracker activity, **most active to least active**. Press **LEAST ACTIVE** to flip the order; the button then reads **MOST ACTIVE** to flip it back. Tracker data is re-read every 10 seconds while the manager is open, so it stays current.

Bulk buttons show how many players are currently selected. **SELECT PAGE** selects everyone on the current page. **UNFRIEND** uses the game's own `DRFriendRemove` call and keeps the history entry. **BLOCK** blocks the selected friends.

## Where the data lives

The board keeps up to the last 300 players in:

`%LOCALAPPDATA%\Tutez\DRH Launcher\data\mods\data\player_history\players.json`

(paste that path into the Explorer address bar). Everything is local to this PC. The mod only reads information already visible in the game; friend requests, blocks and unfriends go through the game's own actions when you press the buttons.

## Reading the logs

Where: `%LOCALAPPDATA%\Tutez\DRH Launcher\data\data\logs\game\` (paste it into the Explorer address bar). Each game start makes a new file named by its start time (UTC); the newest one is the current game. Older ones are packed as `.log.zst` (open them with 7-Zip). Open the file in any text editor and search for `player_history`.

Useful lines:

- `mod player_history: joining NAME (ID)` — JOIN was used for that player.
- `mod player_history: removed friends: ...` — UNFRIEND completed for those friends.
- `mod player_history: no online_tracker activity file at ...` — Online Tracker has no data yet, so MANAGER has no activity dates to sort by. Harmless.
- A line with `could not`, `failed` or `unreadable` — something went wrong; send that line and the few lines around it with your report.

## License

GPL-3.0; see `LICENSE`.

## Planned

More small improvements in upcoming versions:

- Optional export/import of `players.json` for moving history between PCs.
- More activity detail from Online Tracker, such as gift and last-seen trends.
- Extra bulk actions for joining and requesting friends.

