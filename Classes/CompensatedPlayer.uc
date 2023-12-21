class CompensatedPlayer extends SwatGame.SwatMutator;

import enum EquipmentSlot from Engine.HandheldEquipment;

struct PingCompensationStruct
{
    var InterpCurve LocX;
    var InterpCurve LocY;
    var InterpCurve LocZ;
    var vector CompensationLocation;
    var vector SavedLocation;
    var EquipmentSlot WeaponSlot;
    var int Ammo;
    var float LastLocationUpdateTime;
    var bool Feedback;
};
var PingCompensationStruct PingCompensation;
var PlayerController PC;

function Tick(float Delta)
{
    if (PC == None)
        Destroy();
}