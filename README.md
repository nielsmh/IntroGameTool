This is a game script for OpenTTD, to help making intro games with multiple views.
It works with the sign-based format implemented in [OpenTTD PR #8980](https://github.com/OpenTTD/OpenTTD/pull/8980).

The game script provides some explanation of the format in the story book, as well as four tools.

First, it has the "Eternal Love" logic, that resets the town rating for all companies, to make constructing setups easier.

There is a tool to pick a vehicle and get its ID, to make follow vehicle commands easier to set up.

There is a tool that will parse and list all the commands, to let the user verify things.

There is a tool to rewrite and renumber all the signs, to clean up the commands, and make room for inserting more commands between existing ones.
