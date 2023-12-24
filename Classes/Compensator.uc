class Compensator extends SwatGame.SwatMutator
    implements IInterested_GameEvent_MissionStarted;

var PingBroadcastHandler BroadcastHandler;

var private bool wasEnabled;
var private bool MsgShown;

var config int MaxPingCompensationTimeMilliseconds;
var config bool Enabled;
var config bool EnableCustomSkeletalRegionInfo;
var config bool PlayersAreAlwaysRelevant;

var config float HeadDamageModifierMin;
var config float HeadDamageModifierMax;
var config float HeadLimpModifierMin;
var config float HeadLimpModifierMax;
var config float HeadAimErrorPenaltyMin;
var config float HeadAimErrorPenaltyMax;

var config float TorsoDamageModifierMin;
var config float TorsoDamageModifierMax;
var config float TorsoLimpModifierMin;
var config float TorsoLimpModifierMax;
var config float TorsoAimErrorPenaltyMin;
var config float TorsoAimErrorPenaltyMax;

var config float LeftArmDamageModifierMin;
var config float LeftArmDamageModifierMax;
var config float LeftArmLimpModifierMin;
var config float LeftArmLimpModifierMax;
var config float LeftArmAimErrorPenaltyMin;
var config float LeftArmAimErrorPenaltyMax;

var config float RightArmDamageModifierMin;
var config float RightArmDamageModifierMax;
var config float RightArmLimpModifierMin;
var config float RightArmLimpModifierMax;
var config float RightArmAimErrorPenaltyMin;
var config float RightArmAimErrorPenaltyMax;

var config float LeftLegDamageModifierMin;
var config float LeftLegDamageModifierMax;
var config float LeftLegLimpModifierMin;
var config float LeftLegLimpModifierMax;
var config float LeftLegAimErrorPenaltyMin;
var config float LeftLegAimErrorPenaltyMax;

var config float RightLegDamageModifierMin;
var config float RightLegDamageModifierMax;
var config float RightLegLimpModifierMin;
var config float RightLegLimpModifierMax;
var config float RightLegAimErrorPenaltyMin;
var config float RightLegAimErrorPenaltyMax;

var config float NoHelmetHeadHitDamageMultiplier;
var config float GlobalDamageMultiplier;

// WeaponsOptedOut should only be weapons which do not deal damage: Taser, Stingray, LessLethalSG, PepperSpray, CSBallLauncher and HK69GrenadeLauncher.
// Why do they need to be excluded from this mod? Suppose that someone fires a taser, we can't take back the already fired shot unlike the weapons that deals damage where we can just disable their innate damage and apply damage manually in this mod.
// So in the example of the taser, first the taser would fire its shot from the native class in the game and then fire another shot with this mod, that's one too many shots, they can possibly hit two players at the same time. The same goes for LL Shotgun, Pepper Spray and the rest.

// Previously WeaponsOptedOut was made as a config variable but after some consideration I have decided there is no reason for anyone to change this...
// ...unless you're adapting this mod for use in non-vanilla swat 4, in which case you should modify the code directly and include any weapons which should be opted out of this mod.
var protected array<name> WeaponsOptedOut;

var Timer MsgShownResetTimer;

const MomentumToDamageConversionFactor = 0.031;

// BeginPlay function registers Compensator for the MissionStarted game event.

function BeginPlay()
{
    local SwatGameInfo GameInfo;

    GameInfo = SwatGameInfo(Level.Game);
    
    if(GameInfo != none && GameInfo.GameEvents != none)
    {
        GameInfo.GameEvents.MissionStarted.Register(self);
    }

    WeaponsOptedOut[0] = 'Taser';
    WeaponsOptedOut[1] = 'Stingray';
    WeaponsOptedOut[2] = 'LessLethalSG';
    WeaponsOptedOut[3] = 'PepperSpray';
    WeaponsOptedOut[4] = 'CSBallLauncher';
    WeaponsOptedOut[5] = 'HK69GrenadeLauncher';
}

// PostBeginPlay initializes PingBroadcastHandler if Enabled.

function PostBeginPlay()
{
	Super.PostBeginPlay();

    if (Enabled)
        InstantiatePingBroadcastHandler();
}

// InstantiatePingBroadcastHandler creates an instance of PingBroadcastHandler.

function InstantiatePingBroadcastHandler()
{
    if (BroadcastHandler == None)
    {
        BroadcastHandler = Spawn(class'PingBroadcastHandler');
        BroadcastHandler.OriginalHandler = Level.Game.BroadcastHandler;
        Level.Game.BroadcastHandler = BroadcastHandler;
    }
}

// Tick function handles main logic for each player.

function Tick(float Delta)
{
    local PlayerController PC;
    local Controller C;
    local CompensatedPlayer C_P;

    if(Enabled)
    {
        // Loop through player controllers and handle compensation logic.

        for (C = Level.ControllerList; C != none; C = C.nextController)
        {
            PC = PlayerController(C);

            // Skip non-player controllers and controllers without a valid player.

            if (PC == None)
                continue;

            if (SwatGamePlayerController(PC) == None)
                continue;

            if (SwatGamePlayerController(PC).SwatRepoPlayerItem == None)
                continue;

            // Skip non-local players if they don't have a net connection.

            if (NetConnection(PC.Player) == None && PC != Level.GetLocalPlayerController())
                continue;

            // Skip dead or incapacitated players.
            if (PC.Pawn == None || PC.Pawn.IsDead() || PC.Pawn.IsIncapacitated())
                continue;

            // Check if this player already has a CompensatedPlayer class, spawn it if not.
            if (!IsThisPlayerCompensatedFor(PC, C_P))
            {
                C_P = Spawn(class'CompensatedPlayer');
                C_P.PC = PC;
            }

            // Perform logic related to skeletal region information.
            if (EnableCustomSkeletalRegionInfo)
                CustomSkeletalRegionInfo(C_P.PC.Pawn);

            // What setting an actor (pawn in this case) to bAlwaysRelevant does is that it makes it always be relevant to the network.

            // From now on I will be mentioning actors and clients.
            // What actor means is a pawn in the game. On the other hand, a client is a controller of the pawn, so basically you as a player.

            // If this boolean flag is set to false, the server does not replicate an actor to a client unless the actor is in the client's field of view or the distance between them is not too great.
            // This works on a client to client basis, for example if a client sees an actor, the server now replicates the actor to the client but at the same time another client who has not got the actor in their field of view or proximity may not be able to see the actor since the server will not be replicating that actor to the other client.

            // This is used for optimizing network bandwidth by reducing the amount of data sent to clients about distant and out of view actors.

            // However, I believe we are no longer living in 2005 when network bandwidth used to be an issue, so now setting bAlwaysRelevant to false only has drawbacks and no benefits.
            // One of the gamebreaking drawbacks is that you do not hear the other players approaching you at all since they were not being replicated to you while they were out of view or out of range, the server only starts replicating them to you once they are already in the same room as you.
            // Not only can you not hear them approaching but also it's like one moment you look and nobody is there and the next moment suddenly there is a player standing there, already firing at you. I like to call this "teleporting players".

            // Now let's see what happens when bAlwaysRelevant is set to true. When it's set to true, it means that the actor is always relevant to the network. This implies that the actor's updates will be replicated to all clients, irrespective of their proximity or visibility to the actor. This ensures that the server will always keep you updated about the position of all actors present in the game, thus there will be no "teleporting players".
            if (PlayersAreAlwaysRelevant)
                C_P.PC.Pawn.bAlwaysRelevant = true;

            // Perform additional logic related to net position and weapon firing.
            SaveNetPosition(C_P);
            CheckIfWeaponHasFired(C_P);
        }
    }

    // Handle changes in the Enabled state. This allows seamlessly enabling or disabling the mod on the fly.
    if (wasEnabled != Enabled)
    {
        if (wasEnabled == true)
        {
            if (BroadcastHandler != None)
                BroadcastHandler.Destroy();
        }
        else
        {
            if (BroadcastHandler == None)
                InstantiatePingBroadcastHandler();
        }
    }

    wasEnabled = Enabled;
}

// Boolean function for finding out if a player already has a CompensatedPlayer class associated with them or not.

function bool IsThisPlayerCompensatedFor(PlayerController PC, out CompensatedPlayer C_P)
{
    foreach DynamicActors(class'CompensatedPlayer', C_P)
    {
        if (PC == C_P.PC)
        {
            return true;
        }
    }

    return false;
}

// Custom skeletal region information allowing for full control over damage modifier, limp modifier (this is when the player gets injured and starts walking slower, also known as limping) and aim error penalty for each part of the body.

function CustomSkeletalRegionInfo(Pawn Pawn)
{
    // Head
    Pawn.SkeletalRegionInformation[1].DamageModifier.Min = HeadDamageModifierMin;
    Pawn.SkeletalRegionInformation[1].DamageModifier.Max = HeadDamageModifierMax;
    Pawn.SkeletalRegionInformation[1].LimpModifier.Min = HeadLimpModifierMin;
    Pawn.SkeletalRegionInformation[1].LimpModifier.Max = HeadLimpModifierMax;
    Pawn.SkeletalRegionInformation[1].AimErrorPenalty.Min = HeadAimErrorPenaltyMin;
    Pawn.SkeletalRegionInformation[1].AimErrorPenalty.Max = HeadAimErrorPenaltyMax;

    // Torso
    Pawn.SkeletalRegionInformation[2].DamageModifier.Min = TorsoDamageModifierMin;
    Pawn.SkeletalRegionInformation[2].DamageModifier.Max = TorsoDamageModifierMax;
    Pawn.SkeletalRegionInformation[2].LimpModifier.Min = TorsoLimpModifierMin;
    Pawn.SkeletalRegionInformation[2].LimpModifier.Max = TorsoLimpModifierMax;
    Pawn.SkeletalRegionInformation[2].AimErrorPenalty.Min = TorsoAimErrorPenaltyMin;
    Pawn.SkeletalRegionInformation[2].AimErrorPenalty.Max = TorsoAimErrorPenaltyMax;

    // Left Arm
    Pawn.SkeletalRegionInformation[3].DamageModifier.Min = LeftArmDamageModifierMin;
    Pawn.SkeletalRegionInformation[3].DamageModifier.Max = LeftArmDamageModifierMax;
    Pawn.SkeletalRegionInformation[3].LimpModifier.Min = LeftArmLimpModifierMin;
    Pawn.SkeletalRegionInformation[3].LimpModifier.Max = LeftArmLimpModifierMax;
    Pawn.SkeletalRegionInformation[3].AimErrorPenalty.Min = LeftArmAimErrorPenaltyMin;
    Pawn.SkeletalRegionInformation[3].AimErrorPenalty.Max = LeftArmAimErrorPenaltyMax;

    // Right Arm
    Pawn.SkeletalRegionInformation[4].DamageModifier.Min = RightArmDamageModifierMin;
    Pawn.SkeletalRegionInformation[4].DamageModifier.Max = RightArmDamageModifierMax;
    Pawn.SkeletalRegionInformation[4].LimpModifier.Min = RightArmLimpModifierMin;
    Pawn.SkeletalRegionInformation[4].LimpModifier.Max = RightArmLimpModifierMax;
    Pawn.SkeletalRegionInformation[4].AimErrorPenalty.Min = RightArmAimErrorPenaltyMin;
    Pawn.SkeletalRegionInformation[4].AimErrorPenalty.Max = RightArmAimErrorPenaltyMax;

    // Left Leg
    Pawn.SkeletalRegionInformation[5].DamageModifier.Min = LeftLegDamageModifierMin;
    Pawn.SkeletalRegionInformation[5].DamageModifier.Max = LeftLegDamageModifierMax;
    Pawn.SkeletalRegionInformation[5].LimpModifier.Min = LeftLegLimpModifierMin;
    Pawn.SkeletalRegionInformation[5].LimpModifier.Max = LeftLegLimpModifierMax;
    Pawn.SkeletalRegionInformation[5].AimErrorPenalty.Min = LeftLegAimErrorPenaltyMin;
    Pawn.SkeletalRegionInformation[5].AimErrorPenalty.Max = LeftLegAimErrorPenaltyMax;

    // Right Leg
    Pawn.SkeletalRegionInformation[6].DamageModifier.Min = RightLegDamageModifierMin;
    Pawn.SkeletalRegionInformation[6].DamageModifier.Max = RightLegDamageModifierMax;
    Pawn.SkeletalRegionInformation[6].LimpModifier.Min = RightLegLimpModifierMin;
    Pawn.SkeletalRegionInformation[6].LimpModifier.Max = RightLegLimpModifierMax;
    Pawn.SkeletalRegionInformation[6].AimErrorPenalty.Min = RightLegAimErrorPenaltyMin;
    Pawn.SkeletalRegionInformation[6].AimErrorPenalty.Max = RightLegAimErrorPenaltyMax;
}

// SaveNetPosition function is responsible for updating the net position of the player,
// considering ping compensation adjustments.

function SaveNetPosition(CompensatedPlayer C_P)
{
    local int i;

    // Check if the net position has already been updated in the current frame.
    // If so, return to avoid redundant updates.
    if(C_P.PingCompensation.LastLocationUpdateTime == Level.TimeSeconds)
    {
        return;
    }

    // Mark the current frame as the last time the net position was updated.
    C_P.PingCompensation.LastLocationUpdateTime = Level.TimeSeconds;

    // Trim outdated ping compensation data points based on the maximum allowed
    // ping compensation time, removing points that are older than the specified threshold.
    While(C_P.PingCompensation.LocX.Points.Length > 1 && C_P.PingCompensation.LocX.Points[1].InVal < C_P.PingCompensation.LastLocationUpdateTime - (MaxPingCompensationTimeMilliseconds / 1000))
    {
        C_P.PingCompensation.LocX.Points.Remove(0, 1);
        C_P.PingCompensation.LocY.Points.Remove(0, 1);
        C_P.PingCompensation.LocZ.Points.Remove(0, 1);
    }

    // Get the current length of the ping compensation data points.
    i = C_P.PingCompensation.LocX.Points.Length;

    // Increment the length of ping compensation data points and update the new point.
    C_P.PingCompensation.LocX.Points.Length = i + 1;
    C_P.PingCompensation.LocX.Points[i].InVal = C_P.PingCompensation.LastLocationUpdateTime;
    C_P.PingCompensation.LocX.Points[i].OutVal = C_P.PC.Pawn.Location.X;

    C_P.PingCompensation.LocY.Points.Length = i + 1;
    C_P.PingCompensation.LocY.Points[i].InVal = C_P.PingCompensation.LastLocationUpdateTime;
    C_P.PingCompensation.LocY.Points[i].OutVal = C_P.PC.Pawn.Location.Y;

    C_P.PingCompensation.LocZ.Points.Length = i + 1;
    C_P.PingCompensation.LocZ.Points[i].InVal = C_P.PingCompensation.LastLocationUpdateTime;
    C_P.PingCompensation.LocZ.Points[i].OutVal = C_P.PC.Pawn.Location.Z;
}

// CheckIfWeaponHasFired function is responsible for determining if the player's weapon has fired,
// and updates relevant ping compensation information accordingly.

function CheckIfWeaponHasFired(CompensatedPlayer C_P)
{
    local FiredWeapon CurrentWeapon;
    local int i;

    // Check if the player is being arrested, already arrested, or is non-lethaled.
    // If true, return without further processing.
    if(NetPlayer(C_P.PC.Pawn).IsBeingArrestedNow() || NetPlayer(C_P.PC.Pawn).IsArrested() || NetPlayer(C_P.PC.Pawn).IsNonLethaled())
    {
        return;
    }

    // Get the currently equipped weapon of the player.
    CurrentWeapon = FiredWeapon(C_P.PC.Pawn.GetActiveItem());

    // If no weapon is equipped, reset ping compensation ammo and weapon slot and return.
    if(CurrentWeapon == none)
    {
        C_P.PingCompensation.Ammo = 0;
        C_P.PingCompensation.WeaponSlot = Slot_Invalid;
        return;
    }

    // Check if the weapon is opted out for ping compensation.
    // If opted out, return without further processing.
    for (i = 0; i < WeaponsOptedOut.Length; i++)
    {
        if (CurrentWeapon.IsA(WeaponsOptedOut[i]))
            return;
    }

    // Check if the weapon is being reloaded. If true, reset ping compensation ammo and return.
    if(CurrentWeapon.IsBeingReloaded())
    {
        C_P.PingCompensation.Ammo = 0;
        return;
    }

    // Adjust the muzzle velocity of the weapon to zero if it's currently default.
    // This is done so that the native code of the game no longer damages any player when they are shot, instead we handle all of the logic behind dealing damage manually in this mod, allowing us to decide if the player should be hurt or not.
    if (CurrentWeapon.MuzzleVelocity == CurrentWeapon.Default.MuzzleVelocity)
        CurrentWeapon.MuzzleVelocity *= 0.0;

    // Check if there is a change in ammo or weapon slot since the last update.
    // If true, update the ping compensation information.
    if(C_P.PingCompensation.Ammo != 0 && C_P.PingCompensation.Ammo > CurrentWeapon.Ammo.RoundsRemainingBeforeReload() && C_P.PingCompensation.WeaponSlot == CurrentWeapon.GetSlot())
    {
        // If conditions met, trace the firing of the weapon.
        TraceFire(CurrentWeapon, C_P);
    }

    // Update ping compensation information with the current ammo and weapon slot.
    if(C_P.PingCompensation.Ammo != CurrentWeapon.Ammo.RoundsRemainingBeforeReload() || C_P.PingCompensation.WeaponSlot != CurrentWeapon.GetSlot())
    {
        C_P.PingCompensation.Ammo = CurrentWeapon.Ammo.RoundsRemainingBeforeReload();
        C_P.PingCompensation.WeaponSlot = CurrentWeapon.GetSlot();
    }
}

// TraceFire function is responsible for simulating the firing of a weapon by tracing projectile paths
// and invoking the BallisticFire function to handle ballistic impacts.

function TraceFire(FiredWeapon CurrentWeapon, CompensatedPlayer C_P)
{
    local vector PerfectStartLocation, StartLocation;
    local rotator PerfectStartDirection, StartDirection;
	local vector StartTrace, EndTrace;
    local int Shot;

    // Get the perfect starting location and direction for firing the weapon.

    CurrentWeapon.GetPerfectFireStart(PerfectStartLocation, PerfectStartDirection);

    // Iterate through each shot in the weapon's firing sequence.
    for (Shot = 0; Shot < CurrentWeapon.Ammo.ShotsPerRound; ++Shot)
    {
        // Initialize start location and direction with perfect values.
        StartLocation = PerfectStartLocation;
        StartDirection = PerfectStartDirection;

        // Apply aim error to the firing direction.
        CurrentWeapon.ApplyAimError(StartDirection);

        // Calculate the start and end traces based on the adjusted direction and weapon range.
        StartTrace = StartLocation;
        EndTrace = StartLocation + vector(StartDirection) * CurrentWeapon.Range;
        
        // Invoke BallisticFire function to handle ballistic impacts for the traced projectile path.
        BallisticFire(StartTrace, EndTrace, CurrentWeapon, C_P);
    }
}

// BallisticFire function simulates the ballistic firing of a projectile from StartTrace to EndTrace
// using a trace line, and handles ballistic impacts with other actors in the environment.

function BallisticFire(vector StartTrace, vector EndTrace, FiredWeapon CurrentWeapon, CompensatedPlayer C_P)
{
	local vector HitLocation, HitNormal, ExitLocation, ExitNormal;
	local Actor Victim;
    local Material HitMaterial, ExitMaterial;
    local float Momentum, TotalMomentum;
    local ESkeletalRegion HitRegion;
    local CompensatedPlayer Other;

    // Iterate through all CompensatedPlayer actors in the scene to compensate for their ping.
    foreach DynamicActors(class'CompensatedPlayer', Other)
    {
        // Skip if the other CompensatedPlayer actor is the shooter.
        if (Other == C_P)
            continue;

        // Skip dead or incapacitated players.
        if (Other.PC.Pawn == None || Other.PC.Pawn.IsDead() || Other.PC.Pawn.IsIncapacitated())
        {
            continue;
        }

        // Compensate for the player's ping in projectile calculations.
        CompensatePlayerForPing(Other, C_P);
    }

    // Calculate Momentum based on the weapon's muzzle velocity and ammo mass.
    if(CurrentWeapon.Ammo.IsA('JacketedHollowPoint'))
    {
        // Multiply JHP ammo mass by 2 to balance it with FMJ ammo.

        // Note that we are not using 'InternalDamage' of JHP ammo, that makes JHP ammo's damage unbalanced and it's quite unnecessary to have it. Instead we focus on appropriately applying JHP and FMJ ammo's damages to armored and unarmored targets later in the code.
        Momentum = (CurrentWeapon.default.MuzzleVelocity * GlobalDamageMultiplier) * (CurrentWeapon.Ammo.Mass * 2);
    }
    else
    {
        Momentum = (CurrentWeapon.default.MuzzleVelocity * GlobalDamageMultiplier) * CurrentWeapon.Ammo.Mass;
    }

    // Initialize TotalMomentum with the calculated Momentum.
    TotalMomentum = Momentum;

    // Iterate through all actors hit by the trace line.
    foreach TraceActors(
        class'Actor', 
        Victim, 
        HitLocation, 
        HitNormal, 
        HitMaterial,
        EndTrace, 
        StartTrace,
        /*optional extent*/,
        true, //bSkeletalBoxTest
        HitRegion,
        true,   //bGetMaterial
        true,   //bFindExitLocation
        ExitLocation,
        ExitNormal,
        ExitMaterial)
        {
            // Handle the ballistic impact with the current victim.
            if (!HandleBallisticImpact(Victim, HitLocation, HitNormal, Normal(HitLocation - StartTrace), HitMaterial, HitRegion, Momentum, ExitLocation, ExitNormal, ExitMaterial, CurrentWeapon, TotalMomentum, C_P))
                break;
        }

    // Iterate through all CompensatedPlayer actors again to decompensate for their ping.
    foreach DynamicActors(class'CompensatedPlayer', Other)
    {
        if (Other == C_P)
            continue;

        // Decompensate for the player's ping after projectile calculations.
        DecompensatePlayerForPing(Other);
    }
}

// HandleBallisticImpact function processes the impact of a ballistic projectile on a victim actor.
// It calculates damage, checks for penetration, applies modifiers based on hit region and protective equipment,
// and broadcasts damage information to the shooter's player controller (If hit feedback is enabled).

function bool HandleBallisticImpact(Actor Victim,
    vector HitLocation,
    vector HitNormal,
    vector NormalizedBulletDirection,
    Material HitMaterial,
    ESkeletalRegion HitRegion,
    out float Momentum,
    vector ExitLocation,
    vector ExitNormal,
    Material ExitMaterial,
    FiredWeapon CurrentWeapon,
    float TotalMomentum,
    CompensatedPlayer Shooter)
{
    local float MomentumToPenetrateVictim;
    local float MomentumLostToVictim;
    local vector MomentumVector;
    local bool PenetratesVictim;
    local float Damage;
    local SkeletalRegionInformation SkeletalRegionInformation;
    local ProtectiveEquipment Protection;
    local float DamageModifier, ExternalDamageModifier;
    local float LimbInjuryAimErrorPenalty;
    local IHaveSkeletalRegions SkelVictim;

    // Check if the owner of the weapon is valid...
    if( Pawn(CurrentWeapon.Owner) == None || Pawn(CurrentWeapon.Owner).Controller == None )
    {
        return false;
    }

    // ...and not in god mode, in which cases we don't want the shooter's ballistics to have an impact.
    if( Pawn(CurrentWeapon.Owner).Controller.bGodMode )
    {
        return false;
    }

    // If we've hit a hidden actor or an actor which is not world geometry, the ballistic projectile skips and continues onto the next target.
    if ((Victim.bHidden || Victim.DrawType == DT_None) && !(Victim.IsA('LevelInfo')))
    {
        return true;
    }

    // If we've hit ourselves, we skip and continue on.
    if(Victim == CurrentWeapon.Owner)
        return true;

    // If we've hit a door, we skip and continue on.
    if (Victim.IsA('SwatDoor'))
        return true;
    
    // Retrieve HitMaterial, ExitMaterial, SkeletalRegionInformation, and Protection for mesh-based victims.
    if (Victim.DrawType == DT_Mesh)
    {
        HitMaterial = Victim.GetCurrentMaterial(0);
        ExitMaterial = HitMaterial;

        if (HitRegion != REGION_None && Victim.IsA('IHaveSkeletalRegions'))
        {
            if (Victim.IsA('ICanUseProtectiveEquipment'))
            {
                SkeletalRegionInformation = ICanUseProtectiveEquipment(Victim).GetSkeletalRegionInformation(HitRegion);
                Protection = ICanUseProtectiveEquipment(Victim).GetSkeletalRegionProtection(HitRegion);
            }
        }
    }

    // Initialize MomentumToPenetrateVictim and MomentumLostToVictim based on victim type.
    if (Victim.class.name == 'LevelInfo' || CurrentWeapon.Ammo.RoundsNeverPenetrate)
    {
        MomentumToPenetrateVictim = Momentum;
        MomentumLostToVictim = Momentum;
    }
    else if(Victim.IsA('IHaveSkeletalRegions') && Pawn(Victim) != None)
    {
        MomentumToPenetrateVictim = GetRegionBasedMomentumToPenetrate(HitRegion, Protection, TotalMomentum);
        MomentumLostToVictim = FMin(Momentum, MomentumToPenetrateVictim);
    }
    else
    {
        MomentumToPenetrateVictim = Victim.GetMomentumToPenetrate(HitLocation, HitNormal, HitMaterial);
        MomentumLostToVictim = FMin(Momentum, MomentumToPenetrateVictim);
    }

    // Determine if the projectile penetrates the victim.
    PenetratesVictim = (MomentumLostToVictim < Momentum);

    // Calculate Damage based on MomentumLostToVictim.
    Damage = MomentumLostToVictim * MomentumToDamageConversionFactor;

    // Calculate MomentumVector based on NormalizedBulletDirection and MomentumLostToVictim.
    MomentumVector = NormalizedBulletDirection * MomentumLostToVictim;

    // Apply penetration fraction modifier if the projectile penetrates the victim.
    if (PenetratesVictim)
        MomentumVector *= Level.GetRepo().MomentumImpartedOnPenetrationFraction;
    
    // Apply external damage modifier.
    ExternalDamageModifier = Level.GetRepo().GetExternalDamageModifier(CurrentWeapon.Owner, Victim);
    Damage = Damage * ExternalDamageModifier;
    
    // Process damage and modifiers if damage is greater than 0 and SkeletalRegionInformation is available.
    if (Damage > 0.0 && SkeletalRegionInformation != None && Victim.IsA('Pawn'))
    {
        // Apply random damage modifier based on SkeletalRegionInformation.
        DamageModifier = RandRange(SkeletalRegionInformation.DamageModifier.Min, SkeletalRegionInformation.DamageModifier.Max);
        
        // Modify damage based on hit region and protective equipment.
        if (HitRegion == REGION_Head && !Protection.IsA('HelmetAndGoggles'))
            DamageModifier *= NoHelmetHeadHitDamageMultiplier;

        Damage *= DamageModifier;

        // Apply additional damage modifier for body armor.
        if (Protection != None && Protection.IsA('BodyArmor'))
        {
            if(Protection.IsA('HeavyBodyArmor'))
            {
                // Make FMJ work as intended by its description on heavy armored targets

                /* Full Metal jacket ammunition is a lead core surrounded by a strong metal jacket.
                    This ammunition is designed for high penetration.
                    It is best used against armored targets since it can penetrate the armor and still provide stopping power. */
                if(CurrentWeapon.Ammo.IsA('FullMetalJacket'))
                {
                    Damage += Damage * 0.26;
                }

                // Apply heavy armor damage reduction.
                Damage -= Damage * 0.28;
            }
            else
            {
                // Make JHP work as intended by its description on unarmored targets

                /* Jacketed hollow point ammunition is characterized by its hollow tip which initiates uniform expansion of the bullet tip to the depth of the hollow point.
                This expansion causes severe internal damage to the target with less penetration.
                JHP ammo is best used against unarmored targets since it causes maximum damage with less chance of penetration which could cause unwanted targets to be hit. */
                if(CurrentWeapon.Ammo.IsA('JacketedHollowPoint'))
                {
                    Damage += Damage * 0.26;
                }
            }
        }

        // Apply AimErrorPenalty based on SkeletalRegionInformation.
        LimbInjuryAimErrorPenalty = RandRange(SkeletalRegionInformation.AimErrorPenalty.Min, SkeletalRegionInformation.AimErrorPenalty.Max);
        Pawn(Victim).AccumulatedLimbInjury += LimbInjuryAimErrorPenalty;

        if(PlayerController(Pawn(Victim).Controller) != None && Shooter.PingCompensation.Feedback)
        {
            BroadcastDamageInformation(HitRegion, Damage, PlayerController(Pawn(Victim).Controller).PlayerReplicationInfo.PlayerName, Shooter.PC);
            
        }

        // Reduce the victim's health based on the calculated damage.
        Pawn(Victim).Health -= int((Damage - 0.5) + 1);

        // Trigger death event if the victim's health is zero or below.
        if(Pawn(Victim).Health <= 0)
        {
            Pawn(Victim).Died( Pawn(CurrentWeapon.Owner).Controller, CurrentWeapon.GetDamageType(), HitLocation, MomentumVector );
        }
    }
    // Process damage for non-Pawn or non-mesh-based victims.
    else if(Damage > 0.0 && (!Victim.IsA('Pawn') || Victim.DrawType != DT_Mesh))
    {
        // Deal damage using the weapon's DealDamage function.
        CurrentWeapon.DealDamage(Victim, int((Damage - 0.5) + 1), Pawn(CurrentWeapon.Owner), HitLocation, MomentumVector, CurrentWeapon.GetDamageType());
    }

    // Call OnSkeletalRegionHit for IHaveSkeletalRegions victims.
    SkelVictim = IHaveSkeletalRegions(Victim);
    if (SkelVictim != None) 
        SkelVictim.OnSkeletalRegionHit(HitRegion, HitLocation, HitNormal, Damage, CurrentWeapon.GetDamageType(), CurrentWeapon.Owner);

    // Update Momentum based on MomentumLostToVictim.
    Momentum -= MomentumLostToVictim;

    // Return whether the projectile penetrates the victim.
    return PenetratesVictim;
}

// This function returns different momentum to penetrate based on the region.

function float GetRegionBasedMomentumToPenetrate(ESkeletalRegion Region, ProtectiveEquipment Protection, Float Momentum)
{
    switch(Region)
    {
        case REGION_Head:
            if(Protection.IsA('HelmetAndGoggles'))
            {
                return Momentum;
            }
            else
            {
                return Momentum * 0.5;
            }
        case REGION_Torso:
            return Momentum;
        case REGION_LeftArm:
        case REGION_RightArm:
            return Momentum * 0.6;
        case REGION_LeftLeg:
        case REGION_RightLeg:
            return Momentum * 0.75;
        case REGION_Body_Max:
            return Momentum;
        default:
            return 0.0;
    }
    return 0.0;
}

// CompensatePlayerForPing function adjusts the player's location based on ping compensation.
// It retrieves the exact ping of the shooter, calculates the compensation time,
// evaluates the interpolation curves for X, Y, and Z coordinates, and updates the player's location.
// It also calculates the player's field of view based on aim direction to prevent...
// ...updating the location of a victim who is not within the FOV unnecessarily.

function CompensatePlayerForPing(CompensatedPlayer Victim, CompensatedPlayer Shooter)
{
    local Range CompensationTimeRange;
    local float CompensationTime;
    local float ExactPing;

    // Retrieve the exact ping of the shooter and convert it to seconds.
    ExactPing = float(Shooter.PC.ConsoleCommand("GETPING"));
    ExactPing /= 1000;

    // Get the input domain of interpolation curves for compensation time.
    InterpCurveGetInputDomain(Victim.PingCompensation.LocX, CompensationTimeRange.Min, CompensationTimeRange.Max);

    // Calculate compensation time based on the current level time and the exact ping.
    CompensationTime = FClamp(Level.TimeSeconds - ExactPing, CompensationTimeRange.Min, CompensationTimeRange.Max);

    // Evaluate interpolation curves for X, Y, and Z coordinates using the compensation time.
    Victim.PingCompensation.CompensationLocation.X = InterpCurveEval(Victim.PingCompensation.LocX, CompensationTime);
    Victim.PingCompensation.CompensationLocation.Y = InterpCurveEval(Victim.PingCompensation.LocY, CompensationTime);
    Victim.PingCompensation.CompensationLocation.Z = InterpCurveEval(Victim.PingCompensation.LocZ, CompensationTime);

    // Check if the aim direction of the shooter is within an acceptable threshold.
    if(Vector(NetPlayer(Shooter.PC.Pawn).GetAimRotation()) Dot Normal(Victim.PingCompensation.CompensationLocation - Shooter.PC.Pawn.GetThirdPersonEyesLocation()) - (0.00004 * VDist(Victim.PingCompensation.CompensationLocation, Shooter.PC.Pawn.GetThirdPersonEyesLocation())) > 0.9)
    {
        return;
    }

    // Check if the player can set the compensated location and update the player's location accordingly.
    if(Victim.PC.Pawn.CanSetLocation(Victim.PingCompensation.CompensationLocation))
    {
        // Save the current location, temporarily disable collision, set the compensated location, and re-enable collision.
        Victim.PingCompensation.SavedLocation = Victim.PC.Pawn.Location;
        Victim.PC.Pawn.bCollideWorld = False;
        Victim.PC.Pawn.SetLocation(Victim.PingCompensation.CompensationLocation);
        Victim.PC.Pawn.bCollideWorld = True;
    }
}

// DecompensatePlayerForPing function reverses the player's location adjustment made during ping compensation.
// It checks if a saved location is available, and if so, updates the player's location to the saved location.
// This function is typically called after compensating for ping to revert any temporary adjustments.

function DecompensatePlayerForPing(CompensatedPlayer Victim)
{
    // Check if a saved location is available for decompensation.
    if(Victim.PingCompensation.SavedLocation != vect(0.0,0.0,0.0))
    {
        // Check if the player is valid, not dead, and not incapacitated.
        if(Victim.PC.Pawn != None && !Victim.PC.Pawn.IsDead() && !Victim.PC.Pawn.IsIncapacitated())
        {
            // Check if the player can set the saved location and update the player's location accordingly.
            if(Victim.PC.Pawn.CanSetLocation(Victim.PingCompensation.SavedLocation))
            {
                // Temporarily disable collision, set the saved location, and re-enable collision.
                Victim.PC.Pawn.bCollideWorld = False;
                Victim.PC.Pawn.SetLocation(Victim.PingCompensation.SavedLocation);
                Victim.PC.Pawn.bCollideWorld = True;
            }
        }

        // Reset the saved location to the default vector.
        Victim.PingCompensation.SavedLocation = vect(0.0,0.0,0.0);
    }
    return;
}

// Function that broadcasts hit feedback to the shooter.

function BroadcastDamageInformation(ESkeletalRegion HitRegion, float Damage, string VictimPlayerName, PlayerController Shooter)
{
    switch (HitRegion)
    {
        case REGION_Head:
            Level.Game.BroadcastHandler.BroadcastText(none, Shooter, "[C=FFFFFF]You dealt"@int((Damage - 0.5) + 1)@"damage to"@VictimPlayerName@"[C=FFFFFF]by hitting Head!", 'Caption');
            break;
        case REGION_Torso:
            Level.Game.BroadcastHandler.BroadcastText(none, Shooter, "[C=FFFFFF]You dealt"@int((Damage - 0.5) + 1)@"damage to"@VictimPlayerName@"[C=FFFFFF]by hitting Torso!", 'Caption');
            break;
        case REGION_LeftArm:
            Level.Game.BroadcastHandler.BroadcastText(none, Shooter, "[C=FFFFFF]You dealt"@int((Damage - 0.5) + 1)@"damage to"@VictimPlayerName@"[C=FFFFFF]by hitting Left Arm!", 'Caption');
            break;
        case REGION_RightArm:
            Level.Game.BroadcastHandler.BroadcastText(none, Shooter, "[C=FFFFFF]You dealt"@int((Damage - 0.5) + 1)@"damage to"@VictimPlayerName@"[C=FFFFFF]by hitting Right Arm!", 'Caption');
            break;
        case REGION_LeftLeg:
            Level.Game.BroadcastHandler.BroadcastText(none, Shooter, "[C=FFFFFF]You dealt"@int((Damage - 0.5) + 1)@"damage to"@VictimPlayerName@"[C=FFFFFF][C=FFFFFF]by hitting Left Leg!", 'Caption');
            break;
        case REGION_RightLeg:
            Level.Game.BroadcastHandler.BroadcastText(none, Shooter, "[C=FFFFFF]You dealt"@int((Damage - 0.5) + 1)@"damage to"@VictimPlayerName@"[C=FFFFFF]by hitting Right Leg!", 'Caption');
            break;
        case REGION_Body_Max:
            Level.Game.BroadcastHandler.BroadcastText(none, Shooter, "[C=FFFFFF]You dealt"@int((Damage - 0.5) + 1)@"damage to"@VictimPlayerName@"[C=FFFFFF]by hitting Overall Body!", 'Caption');
            break;
        default:
            Level.Game.BroadcastHandler.BroadcastText(none, Shooter, "[C=FFFFFF]You dealt"@int((Damage - 0.5) + 1)@"damage to"@VictimPlayerName, 'Caption');
            break;
    }
}

// OnMissionStarted is called when the mission starts, displays a message if Enabled and not already shown.

function OnMissionStarted()
{
    if (Enabled && !MsgShown)
    {
        Level.Game.Broadcast(None, PINGCOMPENSATION_CREDIT@PINGCOMPENSATION_VERSION, 'Caption');
        MsgShown = true;
        MsgShownResetTimer = Spawn(class'Timer');
        MsgShownResetTimer.TimerDelegate = MsgShownReset;
        MsgShownResetTimer.StartTimer(5.0, false);
    }
}

// MsgShownReset is a timer delegate function to reset the MsgShown flag.

function MsgShownReset()
{
    MsgShown = false;
}

// Destroyed function unregisters Compensator from the MissionStarted game event.

event Destroyed()
{
    local SwatGameInfo GameInfo;

    GameInfo = SwatGameInfo(Level.Game);
    
    if(GameInfo != none && GameInfo.GameEvents != none)
    {
        GameInfo.GameEvents.MissionStarted.UnRegister(self);
    }

    super.Destroyed();
}

defaultproperties
{
    MaxPingCompensationTimeMilliseconds=300
    Enabled=true
    EnableCustomSkeletalRegionInfo=true
    PlayersAreAlwaysRelevant=true

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
}