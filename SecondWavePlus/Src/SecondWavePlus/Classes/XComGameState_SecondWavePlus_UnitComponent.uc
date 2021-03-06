// This is an Unreal Script
                           
class XComGameState_SecondWavePlus_UnitComponent extends SecondWave_GameStateParent;

var protected bool b_HasGot_NotCreatedEqually;
var protected bool b_HasGot_CommandersChoiceVet;
var protected bool b_HasGot_HiddenPotential;
var protected bool b_HasGot_AbsolutlyCritical;

var int ExtraCostExpensiveTalent;

var int LastUpdatedLevel;

var private array<HiddenPotentialLevelChanges> SavedLevelChanges;

public function SendEventsAfterInit(SecondWave_HiddenPotential_GameState HPGS,SecondWave_AbsolutlyCritical_GameState ACGS,SecondWave_NotCreatedEqually_GameState NCEGS,Optional XComGameState NewGameState)
{
	//local Object Myself;
	local XComGameState_Unit Unit;

	Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(self.OwningObjectId));
	//Myself=self;

	//`XEVENTMGR.TriggerEvent('NCE_Start',self,XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(self.OwningObjectId)),NewGameState);	
	//`XEVENTMGR.TriggerEvent('HiddenPotential_Start',self,XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(self.OwningObjectId)),NewGameState);	
	//`XEVENTMGR.TriggerEvent('AbsolutlyCritical_Start',self,XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(self.OwningObjectId)),NewGameState);	
	NCEGS.RandomStats(Unit,NewGameState);
	HPGS.AddHiddenPotentialToUnit(Unit,NewGameState);
	ACGS.AddAbsolutlyCriticalToUnit(Unit,NewGameState);

	//`XEVENTMGR.RegisterForEvent(Myself,'UnitRankUp',OnRankUp,ELD_OnStateSubmitted, , ,true);
}
/*function EventListenerReturn OnRankUp(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID)
{
	`log("RankedUp!");
	if(XComGameState_Unit(EventData).ObjectID==XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(self.OwningObjectId)).ObjectID)
		`XEVENTMGR.TriggerEvent('HiddenPotential_ApplyUpdate',XComGameState_Unit(EventData),XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(self.OwningObjectId)),NewGameState);	
	return ELR_NoInterrupt;
}*/
public function SetHiddenPotentialLevelChanges(array<HiddenPotentialLevelChanges> LevelChanges)
{	
	SavedLevelChanges=LevelChanges;
}
public function array<HiddenPotentialLevelChanges> GetSavedLevelChanges()
{		
	return SavedLevelChanges;	
}
public function HiddenPotentialLevelChanges GetSpecificLevelChanges(int i)
{		
	if(i>=0 && i<SavedLevelChanges.Length)
		return SavedLevelChanges[i];	
	return SavedLevelChanges[0];
}

public function SetHasGot_AbsolutlyCritical (bool InBool)
{
	b_HasGot_AbsolutlyCritical=InBool;	
}
public function SetHasGot_NotCreatedEqually (bool InBool)
{
	b_HasGot_NotCreatedEqually=InBool;	
}
public function SetHasGot_CommandersChoiceVet (bool InBool)
{
	b_HasGot_CommandersChoiceVet=InBool;	
}
public function SetHasGot_HiddenPotential (bool InBool)
{
	b_HasGot_HiddenPotential=InBool;
	if(!Inbool)
	{
		SavedLevelChanges.Length=0;
	}	
}
public function bool GetHasGot_AbsolutlyCritical ()
{
	return b_HasGot_AbsolutlyCritical;
}
public function bool GetHasGot_NotCreatedEqually ()
{
	return b_HasGot_NotCreatedEqually;	
}
public function bool GetHasGot_CommandersChoiceVet ()
{
	return b_HasGot_CommandersChoiceVet;	
}
public function bool GetHasGot_HiddenPotential ()
{
	return b_HasGot_HiddenPotential;	
}

static function GCValidationChecks() //Thanks Amineri and LWS
{
    local XComGameStateHistory History;
    local XComGameState NewGameState;
    local XComGameState_Unit UnitState;
    local XComGameState_SecondWavePlus_UnitComponent SWPCState;
 
    `LOG("LWOfficerUtilities: Starting Garbage Collection and Validation.");
 
    History = `XCOMHISTORY;
    NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Officer States cleanup");
    foreach History.IterateByClassType(class'XComGameState_SecondWavePlus_UnitComponent',SWPCState,,true)
    {
        `LOG("Found SWP State, OwningObjectID=" $ SWPCState.OwningObjectId $ ", Deleted=" $ SWPCState.bRemoved,,'Dragonpunk Second Wave Plus');
        //check and see if the OwningObject is still alive and exists
        if(SWPCState.OwningObjectId > 0)
        {
            UnitState = XComGameState_Unit(History.GetGameStateForObjectID(SWPCState.OwningObjectID));
            if(UnitState == none)
            {
                `LOG("SWP Component has no current owning unit, cleaning up state.",,'Dragonpunk Second Wave Plus');
                // Remove disconnected officer state
                NewGameState.RemoveStateObject(SWPCState.ObjectID);
            }
            else
            {
                `LOG("Found Owning Unit=" $ UnitState.GetFullName() $ ", Deleted=" $ UnitState.bRemoved,,'Dragonpunk Second Wave Plus');
                if(UnitState.bRemoved)
                {
                    `LOG("LWOfficerUtilities: Owning Unit was removed, Removing SWPCState");
                    NewGameState.RemoveStateObject(SWPCState.ObjectID);
                }
            }
        }
    }
    if (NewGameState.GetNumGameStateObjects() > 0)
        `GAMERULES.SubmitGameState(NewGameState);
    else
        History.CleanupPendingGameState(NewGameState);
}
 