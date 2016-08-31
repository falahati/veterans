# Veterans Only
"Veterans Only" (or simply "veterans") is a Plugin for SourceMod and written with SourcePawn to restrict access of players based on their playtime in a specific game

## PHP Hosting
It is possible to host the PHP part of the project on your website. To do so, proceed the following steps:

1. Locate a public folder on a website capable of hosting PHP files and with "php_curl" extension enabled.
2. Upload the "queryPlaytime.php" file from the "web" directory to that folder.
3. (Optional, but highly recommended) Create a folder named "WebCache" and give PHP write access to it. (chmod 755 or 777 for Linux)
4. Edit the plugin configuration file and change the "sm_veterans_url" cvar to the address of the newly uploaded PHP file.

## License
This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.