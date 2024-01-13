
This Openplanet Plugin converts all the Trackmania2020 blocks to items automatically

⚠️ **Warning** ⚠️

This script moves the mouse & clicks when running, do not alt+tab of the game while it is exporting blocks

It is also recommended to not export everything at once, you can export different block types by browsing down the tree

I recommend exporting batch of few hundreds of blocks at a time, which can take a few minutes in which your computer will be unusable for other tasks

![Exporting RoadTech blocks](https://i.imgur.com/0xEQKCO.png)

## How to use

Clone this repository in the Openplanet folder located at C:\Users\[User]\OpenplanetNext\Plugins\tm-convert-blocks-to-items

The script needs the game to be fullscreen, and you will need to edit the code of the [ClickPos() function](https://github.com/tm-dojo/tm-convert-blocks-to-items/blob/master/src/BlockExporter/BlockExportMethods.as#L53) to match your screen resolution

Go in map editor, create a new map (advanced, keyboard)

⚠️**Warning**⚠️: The script will move the mouse in the center of the screen and hover each block in order to export it
Make sure there is nothing blocking the mouse from hovering the blocks, including the plugin window itself
![mouse area](https://i.imgur.com/q8nRUdl.jpeg)

This script is not signed, so make sure to enter the "Developer" signature mode in the Openplanet settings, else, this plugin will not show up in the Openplanet plugin list

Block are exported to C:\Users\[User]\Documents\Trackmania\Items\BlockToItemExports