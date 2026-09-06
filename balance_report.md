# Combat balance report

400 fights and 300 trips per cell, seed 12345. Potion below 35% HP, trip ends under 25% HP. Statuses ignored.

## Model: live  (damage = attack x 8/(8+defence); enemy attack x1.0; potion 8, Heal 10 for 5 MP)

Profiles: L1 leather (HP 20, ATK 12, DEF 3), L3 frost (HP 28, ATK 18, DEF 5), L5 ironwood (HP 36, ATK 24, DEF 7), L8 ember (HP 48, ATK 32, DEF 9), L12 bog-iron (HP 64, ATK 42, DEF 11), L5 ironwood +set (HP 36, ATK 24, DEF 13)

| profile | arena | win % | HP lost / fight | potions / fight | fights / trip | fights / trip, no potions |
|---|---|---|---|---|---|---|
| L1 leather | Dungeon | 98 | 22% | 0.23 | 6.7 | 5.5 |
| L1 leather | Frostpeak | 76 | 60% | 1.21 | 1.2 | 1.0 |
| L1 leather | Verdantwood | 64 | 70% | 0.93 | 0.8 | 0.8 |
| L1 leather | Badlands | 20 | 93% | 0.91 | 0.2 | 0.2 |
| L1 leather | Gloomfen | 0 | 100% | 0.50 | 0.0 | 0.1 |
| L3 frost | Dungeon | 100 | 10% | 0.01 | 15.9 | 12.5 |
| L3 frost | Frostpeak | 91 | 35% | 0.51 | 3.1 | 2.9 |
| L3 frost | Verdantwood | 88 | 40% | 0.72 | 2.3 | 2.2 |
| L3 frost | Badlands | 63 | 67% | 1.29 | 0.9 | 0.9 |
| L3 frost | Gloomfen | 59 | 73% | 0.78 | 0.7 | 0.8 |
| L5 ironwood | Dungeon | 100 | 5% | 0.00 | 35.7 | 28.8 |
| L5 ironwood | Frostpeak | 100 | 13% | 0.04 | 10.1 | 8.8 |
| L5 ironwood | Verdantwood | 95 | 27% | 0.23 | 4.4 | 4.3 |
| L5 ironwood | Badlands | 88 | 46% | 0.88 | 2.0 | 1.7 |
| L5 ironwood | Gloomfen | 85 | 46% | 0.89 | 2.1 | 2.1 |
| L8 ember | Dungeon | 100 | 3% | 0.00 | 48.5 | 45.5 |
| L8 ember | Frostpeak | 100 | 8% | 0.00 | 17.7 | 15.2 |
| L8 ember | Verdantwood | 100 | 8% | 0.00 | 15.8 | 15.2 |
| L8 ember | Badlands | 97 | 23% | 0.19 | 5.0 | 4.8 |
| L8 ember | Gloomfen | 90 | 32% | 0.33 | 3.3 | 3.3 |
| L12 bog-iron | Dungeon | 100 | 2% | 0.00 | 50.0 | 50.0 |
| L12 bog-iron | Frostpeak | 100 | 3% | 0.00 | 42.9 | 40.1 |
| L12 bog-iron | Verdantwood | 100 | 3% | 0.00 | 38.4 | 36.0 |
| L12 bog-iron | Badlands | 100 | 10% | 0.00 | 12.8 | 12.4 |
| L12 bog-iron | Gloomfen | 100 | 12% | 0.01 | 9.7 | 9.6 |
| L5 ironwood +set | Dungeon | 100 | 3% | 0.00 | 47.4 | 40.4 |
| L5 ironwood +set | Frostpeak | 100 | 9% | 0.01 | 17.6 | 14.8 |
| L5 ironwood +set | Verdantwood | 100 | 20% | 0.16 | 7.2 | 6.2 |
| L5 ironwood +set | Badlands | 94 | 35% | 0.43 | 2.6 | 2.7 |
| L5 ironwood +set | Gloomfen | 92 | 34% | 0.32 | 2.9 | 2.8 |

### Bosses (win % with the profile's 3 potions / with none)

| profile | Bone Lord | Royal Wraith | Glacial Revenant | Elder Bramblewood | Thornback Warden | Cinderjaw | The Bogmaw | The Barrow Warden | The Ancient Warden |
|---|---|---|---|---|---|---|---|---|---|
| L1 leather | 37 / 0 | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 | 100 / 100 | 0 / 0 |
| L3 frost | 100 / 100 | 0 / 0 | 41 / 8 | 0 / 0 | 100 / 100 | 0 / 0 | 0 / 0 | 100 / 100 | 0 / 0 |
| L5 ironwood | 100 / 100 | 0 / 0 | 100 / 100 | 100 / 88 | 100 / 100 | 0 / 0 | 0 / 0 | 100 / 100 | 0 / 0 |
| L8 ember | 100 / 100 | 61 / 59 | 100 / 100 | 100 / 100 | 100 / 100 | 92 / 93 | 1 / 1 | 100 / 100 | 0 / 0 |
| L12 bog-iron | 100 / 100 | 100 / 100 | 100 / 100 | 100 / 100 | 100 / 100 | 100 / 100 | 98 / 100 | 100 / 100 | 1 / 2 |
| L5 ironwood +set | 100 / 100 | 7 / 0 | 100 / 100 | 100 / 100 | 100 / 100 | 28 / 9 | 0 / 0 | 100 / 100 | 0 / 0 |

## Model: old_subtract  (damage = attack - defence, min 1; potion 15, Heal 15 for 4 MP)

Profiles: L1 leather (HP 20, ATK 12, DEF 3), L3 frost (HP 28, ATK 18, DEF 5), L5 ironwood (HP 36, ATK 24, DEF 7), L8 ember (HP 48, ATK 32, DEF 9), L12 bog-iron (HP 64, ATK 42, DEF 11), L5 ironwood +set (HP 36, ATK 24, DEF 13)

| profile | arena | win % | HP lost / fight | potions / fight | fights / trip | fights / trip, no potions |
|---|---|---|---|---|---|---|
| L1 leather | Dungeon | 100 | 14% | 0.03 | 23.4 | 13.0 |
| L1 leather | Frostpeak | 89 | 42% | 0.85 | 2.4 | 1.8 |
| L1 leather | Verdantwood | 67 | 61% | 0.70 | 1.5 | 1.1 |
| L1 leather | Badlands | 20 | 89% | 0.65 | 0.2 | 0.2 |
| L1 leather | Gloomfen | 10 | 96% | 0.40 | 0.1 | 0.1 |
| L3 frost | Dungeon | 100 | 3% | 0.00 | 50.0 | 50.0 |
| L3 frost | Frostpeak | 100 | 21% | 0.07 | 14.9 | 9.3 |
| L3 frost | Verdantwood | 97 | 28% | 0.39 | 6.2 | 4.4 |
| L3 frost | Badlands | 70 | 59% | 0.79 | 1.7 | 1.5 |
| L3 frost | Gloomfen | 73 | 63% | 0.90 | 1.2 | 1.1 |
| L5 ironwood | Dungeon | 100 | 2% | 0.00 | 50.0 | 50.0 |
| L5 ironwood | Frostpeak | 100 | 3% | 0.00 | 50.0 | 50.0 |
| L5 ironwood | Verdantwood | 100 | 12% | 0.03 | 21.4 | 15.0 |
| L5 ironwood | Badlands | 93 | 36% | 0.53 | 3.6 | 3.1 |
| L5 ironwood | Gloomfen | 90 | 38% | 0.61 | 3.4 | 3.0 |
| L8 ember | Dungeon | 100 | 1% | 0.00 | 50.0 | 50.0 |
| L8 ember | Frostpeak | 100 | 2% | 0.00 | 50.0 | 50.0 |
| L8 ember | Verdantwood | 100 | 2% | 0.00 | 50.0 | 50.0 |
| L8 ember | Badlands | 100 | 13% | 0.01 | 16.6 | 13.5 |
| L8 ember | Gloomfen | 100 | 18% | 0.08 | 8.9 | 7.1 |
| L12 bog-iron | Dungeon | 100 | 1% | 0.00 | 50.0 | 50.0 |
| L12 bog-iron | Frostpeak | 100 | 1% | 0.00 | 50.0 | 50.0 |
| L12 bog-iron | Verdantwood | 100 | 1% | 0.00 | 50.0 | 50.0 |
| L12 bog-iron | Badlands | 100 | 3% | 0.00 | 50.0 | 49.3 |
| L12 bog-iron | Gloomfen | 100 | 4% | 0.00 | 47.9 | 43.9 |
| L5 ironwood +set | Dungeon | 100 | 1% | 0.00 | 50.0 | 50.0 |
| L5 ironwood +set | Frostpeak | 100 | 3% | 0.00 | 50.0 | 50.0 |
| L5 ironwood +set | Verdantwood | 100 | 4% | 0.00 | 50.0 | 47.1 |
| L5 ironwood +set | Badlands | 100 | 12% | 0.01 | 24.9 | 17.1 |
| L5 ironwood +set | Gloomfen | 100 | 14% | 0.01 | 23.9 | 16.3 |

### Bosses (win % with the profile's 3 potions / with none)

| profile | Bone Lord | Royal Wraith | Glacial Revenant | Elder Bramblewood | Thornback Warden | Cinderjaw | The Bogmaw | The Barrow Warden | The Ancient Warden |
|---|---|---|---|---|---|---|---|---|---|
| L1 leather | 100 / 100 | 0 / 0 | 0 / 0 | 0 / 0 | 40 / 0 | 0 / 0 | 0 / 0 | 100 / 100 | 0 / 0 |
| L3 frost | 100 / 100 | 0 / 0 | 100 / 100 | 100 / 27 | 100 / 100 | 0 / 0 | 0 / 0 | 100 / 100 | 0 / 0 |
| L5 ironwood | 100 / 100 | 17 / 1 | 100 / 100 | 100 / 100 | 100 / 100 | 22 / 3 | 0 / 0 | 100 / 100 | 0 / 0 |
| L8 ember | 100 / 100 | 100 / 100 | 100 / 100 | 100 / 100 | 100 / 100 | 100 / 100 | 45 / 21 | 100 / 100 | 0 / 0 |
| L12 bog-iron | 100 / 100 | 100 / 100 | 100 / 100 | 100 / 100 | 100 / 100 | 100 / 100 | 100 / 100 | 100 / 100 | 30 / 23 |
| L5 ironwood +set | 100 / 100 | 100 / 100 | 100 / 100 | 100 / 100 | 100 / 100 | 100 / 100 | 46 / 2 | 100 / 100 | 0 / 0 |
