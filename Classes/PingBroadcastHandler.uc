class PingBroadcastHandler extends Engine.BroadcastHandler;

var Engine.BroadcastHandler OriginalHandler;
var config bool WarnPlayersDeadChat;
var config bool ForwardSpecPlayersChatToAlivePlayers;

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
    local PlayerController P;

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

    if (ForwardSpecPlayersChatToAlivePlayers && Sender.IsInState('BaseSpectating'))
    {
        foreach DynamicActors(class'PlayerController', P)
        {
            if (P == Sender)
                continue;

            if (P.IsInState('Dead') || P.IsInState('ObserveTeam') || P.IsInState('ObserveLocation') || P.IsInState('BaseSpectating'))
                continue;

            Level.Game.BroadcastHandler.BroadcastText(none, P, "[c=808080][b]"$Sender.PlayerReplicationInfo.PlayerName$"[\\b]:"@Msg, 'Caption');
            SwatGamePlayerController(P).ClientReliablePlaySound(Sound(DynamicLoadObject("SW_meta.ui_TeamSay1", class'Sound', false)));
        }
    }

    OriginalHandler.BroadcastTeam(Sender, Msg, Type);
}

public function UpdateSentText()
{
    OriginalHandler.UpdateSentText();
}

public function bool AllowsBroadcast(Actor Broadcaster, int Len)
{
    local PlayerController P;

    if (WarnPlayersDeadChat)
    {
        P = PlayerController(Broadcaster);

        if (P != None && (P.IsInState('Dead') || P.IsInState('ObserveTeam') || P.IsInState('ObserveLocation')))
            Level.Game.BroadcastHandler.BroadcastText(none, P, "[C=FFFFFF]You are dead! Your team chat messages cannot be seen by your teammates.", 'Caption');
    }
    return OriginalHandler.AllowsBroadcast(Broadcaster, Len);
}

event Destroyed()
{
    Level.Game.BroadcastHandler = OriginalHandler;

    OriginalHandler = None;

    Super.Destroyed();
}

defaultproperties
{
    WarnPlayersDeadChat=true
    ForwardSpecPlayersChatToAlivePlayers=true
}