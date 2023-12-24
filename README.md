# Server-sided Networked Ballistics with Ping Compensation
This is a SWAT 4 mod that works completely on the server-side. This is for server owners only and players are not required and should **not** download this mod.

[Video demo here](https://www.youtube.com/watch?v=1gFx_9Vhm1U)

The mod employs a sophisticated ping compensation system to eliminate the impact of network latency on player interactions. By adjusting player positions based on network conditions, the mod aims to provide a smoother and more responsive experience.

The mod also overhauls the ballistics system and overrides the skeletal region information of player pawns to custom configurable values.

Programmers and modders should read the source code to understand the technicalities of how this mod works in depth but to sum it up:

- We create a series of data points saving up the location coordinates of a player in memory
- We discard the older data points, keeping only the recent ones based on the maximum allowed ping compensation time
- We check if any player has fired their weapon
- If someone has fired, we trace their weapon starting from the firing point (the gun) into the distance, all the while evaluating the saved data points which provides a history of other players' locations from x ms ago
- During the evaluation process, to compensate for the shooter's ping, the server temporarily changes the net position of the players who are in the shooter's field of view back, to where they were x ms ago
- If we find someone who should be hit, we *very* accurately apply damage to them exactly where they should be hit such as on the head, torso, arms or legs
- The server reverts the position of the hit player back to their original position
- The changes in position of the players by the server are not seen by the players because the whole process finishes within the same tick, so the clients do not even realize what happened behind the scenes on the server

> x is the calculated ping of the shooter

This system completely disregards the original logic behind ballistics, tracing and damage and uses a server-side approach to accomplish it all and fairly do damage to the players when applicable.

## Installation
Download the .u compiled package from the [Releases Section](https://github.com/tenshi-code/ping-compensation/releases/download/v1.0.2/PingCompensation.u) or download the [Source Code](https://github.com/tenshi-code/ping-compensation/tree/main/Classes) and compile it yourself.

Once you have the .u package, place it in Content/System (or ContentExpansion/System for SWAT 4: TSS) folder of your SWAT 4 installation.

Open up Swat4DedicatedServer.ini (or Swat4XDedicatedServer.ini) with any text editor. Scroll down until you find the `[Engine.GameEngine]` section and add a new entry into it: `ServerActors=PingCompensation.Compensator`

Now scroll down to the bottom of the file and add a new section with the following configuration:

```
[PingCompensation.Compensator]
Enabled=True
MaxPingCompensationTimeMilliseconds=300
EnableCustomSkeletalRegionInfo=True
PlayersAreAlwaysRelevant=True
HeadDamageModifierMin=11.0
HeadDamageModifierMax=15.0
HeadLimpModifierMin=0.0
HeadLimpModifierMax=0.0
HeadAimErrorPenaltyMin=2.0
HeadAimErrorPenaltyMax=2.0
TorsoDamageModifierMin=3.2
TorsoDamageModifierMax=3.5
TorsoLimpModifierMin=0.0
TorsoLimpModifierMax=0.0
TorsoAimErrorPenaltyMin=0.5
TorsoAimErrorPenaltyMax=0.5
LeftArmDamageModifierMin=1.4
LeftArmDamageModifierMax=1.7
LeftArmLimpModifierMin=0.0
LeftArmLimpModifierMax=0.0
LeftArmAimErrorPenaltyMin=1.0
LeftArmAimErrorPenaltyMax=1.0
RightArmDamageModifierMin=1.4
RightArmDamageModifierMax=1.7
RightArmLimpModifierMin=0.0
RightArmLimpModifierMax=0.0
RightArmAimErrorPenaltyMin=2.0
RightArmAimErrorPenaltyMax=2.0
LeftLegDamageModifierMin=1.1
LeftLegDamageModifierMax=1.3
LeftLegLimpModifierMin=0.9
LeftLegLimpModifierMax=1.1
LeftLegAimErrorPenaltyMin=3.0
LeftLegAimErrorPenaltyMax=3.5
RightLegDamageModifierMin=1.1
RightLegDamageModifierMax=1.3
RightLegLimpModifierMin=0.9
RightLegLimpModifierMax=1.1
RightLegAimErrorPenaltyMin=3.0
RightLegAimErrorPenaltyMax=3.5
NoHelmetHeadHitDamageMultiplier=2.0
GlobalDamageMultiplier=1.0
```

The configuration provided is the recommended default but you are free to customize any options as you see fit. You will learn more about what each of the setting does in the [Configurable Options](#configuration-options) section below.

## Compatibility
Tested in v1.0 but should work fine in v1.1 and TSS, also works great alongside server administration mods such as admin mod or the Julia framework by sergeii.

## Chat Commands
This mod makes some chat commands available to the players.

The commands can be sent in chat or team chat.

There are alternative commands available which can be used to invoke the same command.

| Command | Alternatives | Description |
| ----------- | ----------- | ----------- |
| !PingHitFeedback | !PingHitF |  Toggle feedback on or off for damage dealt during ping-compensated encounters, providing information on successful hits and their impact on opponents  |
| !RealPing | !ActualPing   !TruePing   !ExactPing |  Get your actual ping to the server, the ping shown on the scoreboard is inaccurate!  |

## Configuration Options
Property is the name of the variable you can configure, type is the data type, description provides information and condition is dependency on another property for a given property to work.

| Property | Type | Description | Condition |
| ----------- | ----------- | ----------- | ----------- |
| Enabled | Boolean (True or False) |  Decides whether the mod is enabled or not  |
| MaxPingCompensationTimeMilliseconds | Integer (Whole Number) |  Maximum time in milliseconds to compensate the players for. For example setting this to 250 means the players with ping below 250 can take full advantage of this mod but players with ping higher than 250 ms will only be partially compensated up to 250 ms  | Enabled must be true
| EnableCustomSkeletalRegionInfo | Boolean (True or False) |  If enabled, custom damage and limp modifiers as well as aim error penalty will be applied to the players. I recommend using this for a much more realistic experience on your server.  |   Enabled must be true   |
| PlayersAreAlwaysRelevant | Boolean (True or False) |  If true, it makes all actors always relevant to the network. This implies that the actor's updates will be replicated to all clients, irrespective of their proximity or visibility to the actor. |   Enabled must be true   |
| HeadDamageModifierMin | Float (Floating-Point Number) |  Minimum and maximum head damage modifier will be applied as a multiplier randomly between a range of min and max to the final damage dealt on the head of a player  |   EnableCustomSkeletalRegionInfo must be true   |
| HeadDamageModifierMax | Float (Floating-Point Number) |  Minimum and maximum head damage modifier will be applied as a multiplier randomly between a range of min and max to the final damage dealt on the head of a player  |   EnableCustomSkeletalRegionInfo must be true   |
| HeadLimpModifierMin | Float (Floating-Point Number) |  Minimum and maximum head limp modifier will be applied randomly between a range of min and max to the currently accumulated limp of a player. When a certain threshold is met, the player starts walking slower, also known as limping  |   EnableCustomSkeletalRegionInfo must be true   |
| HeadLimpModifierMax | Float (Floating-Point Number) |  Minimum and maximum head limp modifier will be added randomly between a range of min and max to the currently accumulated limp of a player. When a certain threshold is met, the player starts walking slower, also known as limping  |   EnableCustomSkeletalRegionInfo must be true   |
| HeadAimErrorPenaltyMin | Float (Floating-Point Number) |  Minimum and maximum head aim error penalty which will be added randomly between a range of min and max to the current aim error penalty, causing the player's crosshair to widen and making it harder to connect the shots |   EnableCustomSkeletalRegionInfo must be true   |
| HeadAimErrorPenaltyMax | Float (Floating-Point Number) |  Minimum and maximum head aim error penalty which will be added randomly between a range of min and max to the current aim error penalty, causing the player's crosshair to widen and making it harder to connect the shots  |   EnableCustomSkeletalRegionInfo must be true   |
| TorsoDamageModifierMin | Float (Floating-Point Number) |  Minimum and maximum torso damage modifier will be applied as a multiplier randomly between a range of min and max to the final damage dealt on the torso of a player  |   EnableCustomSkeletalRegionInfo must be true   |
| TorsoDamageModifierMax | Float (Floating-Point Number) |  Minimum and maximum torso damage modifier will be applied as a multiplier randomly between a range of min and max to the final damage dealt on the torso of a player  |   EnableCustomSkeletalRegionInfo must be true   |
| TorsoLimpModifierMin | Float (Floating-Point Number) |  Minimum and maximum torso limp modifier will be applied randomly between a range of min and max to the currently accumulated limp of a player. When a certain threshold is met, the player starts walking slower, also known as limping  |   EnableCustomSkeletalRegionInfo must be true   |
| TorsoLimpModifierMax | Float (Floating-Point Number) |  Minimum and maximum torso limp modifier will be applied randomly between a range of min and max to the currently accumulated limp of a player. When a certain threshold is met, the player starts walking slower, also known as limping  |   EnableCustomSkeletalRegionInfo must be true   |
| TorsoAimErrorPenaltyMin | Float (Floating-Point Number) |  Minimum and maximum torso aim error penalty which will be added randomly between a range of min and max to the current aim error penalty, causing the player's crosshair to widen and making it harder to connect the shots  |   EnableCustomSkeletalRegionInfo must be true   |
| TorsoAimErrorPenaltyMax | Float (Floating-Point Number) |  Minimum and maximum torso aim error penalty which will be added randomly between a range of min and max to the current aim error penalty, causing the player's crosshair to widen and making it harder to connect the shots  |   EnableCustomSkeletalRegionInfo must be true   |
| LeftArmDamageModifierMin | Float (Floating-Point Number) |  Minimum and maximum left arm damage modifier will be applied as a multiplier randomly between a range of min and max to the final damage dealt on the left arm of a player  |   EnableCustomSkeletalRegionInfo must be true   |
| LeftArmDamageModifierMax | Float (Floating-Point Number) |  Minimum and maximum left arm damage modifier will be applied as a multiplier randomly between a range of min and max to the final damage dealt on the left arm of a player  |   EnableCustomSkeletalRegionInfo must be true   |
| LeftArmLimpModifierMin | Float (Floating-Point Number) |  Minimum and maximum left arm limp modifier will be applied randomly between a range of min and max to the currently accumulated limp of a player. When a certain threshold is met, the player starts walking slower, also known as limping  |   EnableCustomSkeletalRegionInfo must be true   |
| LeftArmLimpModifierMax | Float (Floating-Point Number) |  Minimum and maximum left arm limp modifier will be applied randomly between a range of min and max to the currently accumulated limp of a player. When a certain threshold is met, the player starts walking slower, also known as limping  |   EnableCustomSkeletalRegionInfo must be true   |
| LeftArmAimErrorPenaltyMin | Float (Floating-Point Number) |  Minimum and maximum left arm aim error penalty which will be added randomly between a range of min and max to the current aim error penalty, causing the player's crosshair to widen and making it harder to connect the shots  |   EnableCustomSkeletalRegionInfo must be true   |
| LeftArmAimErrorPenaltyMax | Float (Floating-Point Number) |  Minimum and maximum left arm aim error penalty which will be added randomly between a range of min and max to the current aim error penalty, causing the player's crosshair to widen and making it harder to connect the shots  |   EnableCustomSkeletalRegionInfo must be true   |
| RightArmDamageModifierMin | Float (Floating-Point Number) |  Minimum and maximum right arm damage modifier will be applied as a multiplier randomly between a range of min and max to the final damage dealt on the right arm of a player  |   EnableCustomSkeletalRegionInfo must be true   |
| RightArmDamageModifierMax | Float (Floating-Point Number) |  Minimum and maximum right arm damage modifier will be applied as a multiplier randomly between a range of min and max to the final damage dealt on the right arm of a player  |   EnableCustomSkeletalRegionInfo must be true   |
| RightArmLimpModifierMin | Float (Floating-Point Number) |  Minimum and maximum right arm limp modifier will be applied randomly between a range of min and max to the currently accumulated limp of a player. When a certain threshold is met, the player starts walking slower, also known as limping  |   EnableCustomSkeletalRegionInfo must be true   |
| RightArmLimpModifierMax | Float (Floating-Point Number) |  Minimum and maximum right arm limp modifier will be applied randomly between a range of min and max to the currently accumulated limp of a player. When a certain threshold is met, the player starts walking slower, also known as limping  |   EnableCustomSkeletalRegionInfo must be true   |
| RightArmAimErrorPenaltyMin | Float (Floating-Point Number) |  Minimum and maximum right arm aim error penalty which will be added randomly between a range of min and max to the current aim error penalty, causing the player's crosshair to widen and making it harder to connect the shots  |   EnableCustomSkeletalRegionInfo must be true   |
| RightArmAimErrorPenaltyMax | Float (Floating-Point Number) |  Minimum and maximum right arm aim error penalty which will be added randomly between a range of min and max to the current aim error penalty, causing the player's crosshair to widen and making it harder to connect the shots  |   EnableCustomSkeletalRegionInfo must be true   |
| LeftLegDamageModifierMin | Float (Floating-Point Number) |  Minimum and maximum left leg damage modifier will be applied as a multiplier randomly between a range of min and max to the final damage dealt on the left leg of a player  |   EnableCustomSkeletalRegionInfo must be true   |
| LeftLegDamageModifierMax | Float (Floating-Point Number) |  Minimum and maximum left leg damage modifier will be applied as a multiplier randomly between a range of min and max to the final damage dealt on the left leg of a player  |   EnableCustomSkeletalRegionInfo must be true   |
| LeftLegLimpModifierMin | Float (Floating-Point Number) |  Minimum and maximum left leg limp modifier will be applied randomly between a range of min and max to the currently accumulated limp of a player. When a certain threshold is met, the player starts walking slower, also known as limping  |   EnableCustomSkeletalRegionInfo must be true   |
| LeftLegLimpModifierMax | Float (Floating-Point Number) |  Minimum and maximum left leg limp modifier will be applied randomly between a range of min and max to the currently accumulated limp of a player. When a certain threshold is met, the player starts walking slower, also known as limping  |   EnableCustomSkeletalRegionInfo must be true   |
| LeftLegAimErrorPenaltyMin | Float (Floating-Point Number) |  Minimum and maximum left leg aim error penalty which will be added randomly between a range of min and max to the current aim error penalty, causing the player's crosshair to widen and making it harder to connect the shots  |   EnableCustomSkeletalRegionInfo must be true   |
| LeftLegAimErrorPenaltyMax | Float (Floating-Point Number) |  Minimum and maximum left leg aim error penalty which will be added randomly between a range of min and max to the current aim error penalty, causing the player's crosshair to widen and making it harder to connect the shots  |   EnableCustomSkeletalRegionInfo must be true   |
| RightLegDamageModifierMin | Float (Floating-Point Number) |  Minimum and maximum right leg damage modifier will be applied as a multiplier randomly between a range of min and max to the final damage dealt on the right leg of a player  |   EnableCustomSkeletalRegionInfo must be true   |
| RightLegDamageModifierMax | Float (Floating-Point Number) |  Minimum and maximum right leg damage modifier will be applied as a multiplier randomly between a range of min and max to the final damage dealt on the right leg of a player  |   EnableCustomSkeletalRegionInfo must be true   |
| RightLegLimpModifierMin | Float (Floating-Point Number) |  Minimum and maximum right leg limp modifier will be applied randomly between a range of min and max to the currently accumulated limp of a player. When a certain threshold is met, the player starts walking slower, also known as limping  |   EnableCustomSkeletalRegionInfo must be true   |
| RightLegLimpModifierMax | Float (Floating-Point Number) |  Minimum and maximum right leg limp modifier will be applied randomly between a range of min and max to the currently accumulated limp of a player. When a certain threshold is met, the player starts walking slower, also known as limping  |   EnableCustomSkeletalRegionInfo must be true   |
| RightLegAimErrorPenaltyMin | Float (Floating-Point Number) |  Minimum and maximum right leg aim error penalty which will be added randomly between a range of min and max to the current aim error penalty, causing the player's crosshair to widen and making it harder to connect the shots  |   EnableCustomSkeletalRegionInfo must be true   |
| RightLegAimErrorPenaltyMax | Float (Floating-Point Number) |  Minimum and maximum right leg aim error penalty which will be added randomly between a range of min and max to the current aim error penalty, causing the player's crosshair to widen and making it harder to connect the shots  |   EnableCustomSkeletalRegionInfo must be true   |
| NoHelmetHeadHitDamageMultiplier | Float (Floating-Point Number) |  This is a damage multiplier which will apply to a player only when the player is shot in the head and the player is not wearing a helmet (such as wearing gas mask or no head gear at all for some reason). In this case you can have extra damage dealt to a player as a penalty for not wearing a helmet for stronger protection on the head  |  Enabled must be true  |
| GlobalDamageMultiplier | Float (Floating-Point Number) |  This is a damage multiplier which applies globally to the overall damage. Suppose that you shoot a player and deal 30 damage, with this multiplier at a value of 2.0 you will now deal 60 damage   |  Enabled must be true  |

## Limitations
There is no ping compensation for leaning, compensation applies to movement only.

Compensation also does not apply to the following equipment items: Taser Stun Gun, Cobra Stun Gun, Less Lethal Shotgun, Pepper Spray, Pepper-ball Gun and 40mm Grenade Launcher.
