class PingBroadcastHandler extends Engine.BroadcastHandler;

var Engine.BroadcastHandler OriginalHandler;
var Compensator Compensator;

public function Broadcast(Actor Sender, coerce string Msg, optional name Type)
{
    local CompensatedPlayer C_P;

    if (Msg ~= "!PingHitFeedback" || Msg ~= "!PingHitF" || Msg ~= "!RealPing" || Msg ~= "!ActualPing" || Msg ~= "!TruePing" || Msg ~= "!ExactPing")
    {
        if (Controller(Sender) != None)
        {
            foreach DynamicActors(class'CompensatedPlayer', C_P)
            {
                if (Controller(Sender) == C_P.PC)
                {
                    break;
                }
            }

            if (C_P == None)
            {
                Level.Game.BroadcastHandler.BroadcastText(none, PlayerController(Sender), "[C=FFFFFF]Ping Compensation mod is not initialized for you yet! Please spawn in the game once then try this command again.", 'Caption');
                return;
            }
        }

        if (Msg ~= "!PingHitFeedback" || Msg ~= "!PingHitF")
        {
            C_P.PingCompensation.Feedback = !C_P.PingCompensation.Feedback;

            if (C_P.PingCompensation.Feedback)
                Level.Game.BroadcastHandler.BroadcastText(none, C_P.PC, "[C=FFFFFF]You have turned hit feedback [C=00FF00]ON [C=FFFFFF]for ping compensation mod!", 'Caption');
            else
                Level.Game.BroadcastHandler.BroadcastText(none, C_P.PC, "[C=FFFFFF]You have turned hit feedback [C=FF0000]OFF [C=FFFFFF]for ping compensation mod!", 'Caption');
        }
        else
        {
            Level.Game.BroadcastHandler.BroadcastText(none, C_P.PC, "[C=FFFFFF]Your ping is"$C_P.PC.ConsoleCommand("GETPING")@"ms.", 'Caption');
        }
        return;
    }

    OriginalHandler.Broadcast(Sender, Msg, Type);
}

public function BroadcastTeam(Controller Sender, coerce string Msg, optional name Type)
{
    local CompensatedPlayer C_P;

    if (Msg ~= "!PingFeedback" || Msg ~= "!PingHitF" || Msg ~= "!RealPing" || Msg ~= "!ActualPing" || Msg ~= "!TruePing" || Msg ~= "!ExactPing")
    {
        foreach DynamicActors(class'CompensatedPlayer', C_P)
        {
            if (Sender == C_P.PC)
            {
                break;
            }
        }

        if (C_P == None)
        {
            Level.Game.BroadcastHandler.BroadcastText(none, PlayerController(Sender), "[C=FFFFFF]Ping Compensation mod is not initialized for you yet! Please spawn in the game once then try this command again.", 'Caption');
            return;
        }

        if (Msg ~= "!PingFeedback" || Msg ~= "!PingHitF")
        {
            C_P.PingCompensation.Feedback = !C_P.PingCompensation.Feedback;

            if (C_P.PingCompensation.Feedback)
                Level.Game.BroadcastHandler.BroadcastText(none, C_P.PC, "[C=FFFFFF]You have turned hit feedback [C=00FF00]ON [C=FFFFFF]for ping compensation mod!", 'Caption');
            else
                Level.Game.BroadcastHandler.BroadcastText(none, C_P.PC, "[C=FFFFFF]You have turned hit feedback [C=FF0000]OFF [C=FFFFFF]for ping compensation mod!", 'Caption');
        }
        else
        {
            Level.Game.BroadcastHandler.BroadcastText(none, C_P.PC, "[C=FFFFFF]Your ping is"$C_P.PC.ConsoleCommand("GETPING")@"ms.", 'Caption');
        }
        return;
    }

    OriginalHandler.BroadcastTeam(Sender, Msg, Type);
}

public function UpdateSentText()
{
    OriginalHandler.UpdateSentText();
}

public function bool AllowsBroadcast(Actor Broadcaster, int Len)
{
    return OriginalHandler.AllowsBroadcast(Broadcaster, Len);
}

event Destroyed()
{
    Level.Game.BroadcastHandler = OriginalHandler;

    OriginalHandler = None;

    Super.Destroyed();
}