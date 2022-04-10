# ClaimBar

Claimed mobs HP bar addon for Ashita v3

Shows HP bars of monsters claimed by party and alliance. The bar will always show  without the player needing to target them.

By default, 2 bars will be shown. This can be change in the `claimbar_settings.json` or in game command `/cb bars x`

![img](https://i.imgur.com/MLp4Bz2.png)


## Commands

`/cb bars` - set the number of bars to display. Default = 2

`/cb scale` - set the scale of the bars. Default = 1.\
 Can use decimal numbers `/cb scale 0.8`

 `/cb anim` - set bar drain animation length in seconds. Default = 0.5

 `/cb theme` - set theme. Default = 1 (Darksouls theme)

 Available options:

 `/cb theme 1` - Darksouls\
![img](https://i.imgur.com/723b2Xa.png)

 `/cb theme 2` - CustomHud\
![img](https://i.imgur.com/wpDbR8M.png)

## Limitations

Since there is no way to query for claimed monster, each entity needed to the scanned in order of their memory location. Their position in the bar can change and fluctuate. 

For example. If max bar is set to 2 and there are 3 crabs in memory. Your party claimed crabs #2 and #3

Crab #1\
Crab #2 --> Bar 1\
Crab #3 --> Bar 2

If your party claimed Crab #1, it will take Bar 1's place, pushing #2 downwards and removing #3.

Crab #1 --> Bar 1\
Crab #2 --> Bar 2\
Crab #3
