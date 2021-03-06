/**
 * XComPresentationLayer.uc
 * Copyright 2008-2010, Firaxis Games
 * 
 * Tactical game's presentation layer; shim between the game data and
 * user interface.
 * 
 * IMPORTANT: Do NOT use GotoState(), instead use PushState() & PopState()
 *            otherwise the state stack will not be preserved which leads
 *            to bad things happening in the UI & navigation.
 */

class XComPresentationLayer extends XComPresentationLayerBase;

const CAMERA_ZOOM_SCROLL_INCREMENT = 0.25f;

var protected XComCamera        m_kCamera;
var protected XG3DInterface     m_k3DUI;
var protected XComActionIconManager m_kActionIconManager;
var protected XComLevelBorderManager m_kLevelBorderManager;
var protected float             m_fTimeDilation;
//var protected bool              m_bIntroMatineeBusy;
var protected bool              m_bDramaticCameraAllowed;
var protected bool              m_bSuppressionMessageActive;
var bool                        m_bPathMessageActive; //accessible by the tutorial system

// Screens
var UIEnemyArrowContainer       m_kEnemyArrows; 
var UIInventoryTactical			m_kInventoryTactical; //LOOTING
var UIMissionSummary            m_kMissionSummary;
var UIChallengePostScreen		m_kChallengeModeSummary;
var UIMultiplayerHUD            m_kMultiplayerHUD;
var UIMultiplayerChatManager    m_kMultiplayerChatManager;
var UITacticalHUD               m_kTacticalHUD;
var UITacticalTutorialMgr       m_kUITutorialMgr;
var UITurnOverlay               m_kTurnOverlay;
var UIUnitFlagManager           m_kUnitFlagManager;
var UIMultiplayerPlayerStats    m_kMultiplayerStats;
var UIMultiplayerPostMatchSummary   m_kPostMatchSummary;

var public bool                 m_bAllowEnemyArrowSystem; 

const USE_UNIT_RING = false;    // If true suppose to use Flash unit ring.
var bool m_bUse2DUnitNumber;    //can be changed via console command
var public bool m_bIsDebugHideSelectedUnitDisc ; // Debug option to Hide the unit disc (unit ring) on selected units.

var XComMultiplayerUI           m_kMPInterface;

//var protected PUIHUD            m_kProtoHUD;    // Specific ProtoUI HUD
var protected bool				m_bZoomToggledIn;

// TODO: Remove this when all proper UI screens are implemented. This is temp so that certain UI calls are blocking and spin wait.  -tsmith 
var protected bool              HACK_bUIBusy;

var localized string       m_sLevelUp; 
var localized string       m_sPinned;
var localized string       m_sSaved;
var localized string       m_sHunted;
var localized string       m_sAbortTitle;
var localized string       m_sExtractTitle;
var localized string       m_strAbortAlienBase;
var localized string       m_strAbortWithMissingSoldiers;
var localized string       m_strAbortWithAllSoldiers;
var localized string       m_strAbortAccept;
var localized string       m_strExtractWithMissingSoldiers;
var localized string       m_strExtractWithAllSoldiers;
var localized string       m_strExtractAccept;
var localized string       m_strAbortCancel;
var localized string       m_strSuppressed;
var localized string       m_strItemDestroyed;
var localized string       m_strItemExplodeFragments;
var localized string       m_strArmorExplodeFragments;
var localized string       m_strUnitPanicked;
var localized string       m_strAutoLoot;
var localized string       m_strTimedLoot;
var localized string       m_strUnitDied;
var localized string	   m_strStartChallenge;

var string m_strSuppressedIcon;

var protectedwrite bool         m_bUIShowMyTurnOnOverlayInit;
var protectedwrite bool         m_bUIShowOtherTurnOnOverlayInit;
var protectedwrite bool         m_bUIShowReflexActionOnOverlayInit;
var protectedwrite bool         m_bUIShowSpecialTurnOnOverlayInit;

/// allows the concealment shader to be forced to the "off" position
var protectedwrite bool         m_bConcealmentShaderEnabled;

var private bool                m_bWaitForChallengeAccept; // DEPRECATED bsteiner 3/24/2016

//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//                             INITILIZATION
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

simulated function Init()
{
	// Needed as the debugger doesn't kick in when running directly from a map.
	`log("XComPresentationLayer.Init",,'uicore');

	super.Init();

	// Game camera
	m_kCamera = XComCamera(PlayerController(Owner).PlayerCamera);
	if(m_kCamera != none)
	{
		m_kCamera.Init();
	}

	// Minimap
	// TODO: get minimap working in MP. turn off for now. -tsmith 
	if (WorldInfo.NetMode == NM_Standalone)
	{
		//m_kMinimap = Spawn( class'XGMinimap', self );
	}

	// Action Icon manager
	m_kActionIconManager = Spawn ( class'XComActionIconManager', Owner );

	if( WorldInfo.bShowLevelBorder )
	{
		m_kLevelBorderManager = Spawn ( class'XComLevelBorderManager', Owner );
		m_kLevelBorderManager.InitManager();
	}
}

simulated function OnTacticalReadyForUI()
{
	InitUIScreensComplete();
}

// When game data and interface manager (top level Flash piece) are ready
// this can be called to get things rolling.
simulated function InitUIScreensComplete()
{
	local X2EventManager EventManager;
	local Object ThisObj;

	super.InitUIScreens();

	UITutorialMgr();
	UIFlagMgr();

	UIAbilityHUD();
	UIWorldMessages();
	UITurnOverlay();

	m_k3DUI = Spawn( class'XG3DInterface', self );

	if (`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_ChallengeData', true) != none)
	{
		InitializeChallengeModeUI();
	}

	InitializeSpecialMissionUI();
	
	m_bPresLayerReady = true;

	// Will display any pending information for the user since the screen has been transitioned. -ttalley
	`ONLINEEVENTMGR.PerformNewScreenInit();

	EventManager = `XEVENTMGR;
	ThisObj = self;
	EventManager.RegisterForEvent( ThisObj, 'PlayerTurnBegun', OnPlayerTurnBegun );
	EventManager.RegisterForEvent( ThisObj, 'PlayerTurnEnded', OnPlayerTurnEnded );
		
}

simulated function ClearUIToHUD(optional bool bInstant = true)
{
	//Set to the top-most state in the basic HUD setup.
	ScreenStack.PopUntilClass(class'UITurnOverlay', true);
}

simulated function UIObjectiveList GetObjectivesList() { return m_kTacticalHUD.m_kObjectivesControl; }

simulated function UITutorialMgr()
{
	local UITacticalTutorialMgr       kUITutorialMgr;
	kUITutorialMgr = Spawn(class'UITacticalTutorialMgr', self);
	kUITutorialMgr.InitScreen( XComTacticalController(Owner), Get2DMovie() );
}

simulated function UIFlagMgr()
{
	if (m_kUnitFlagManager == None)
	{
		m_kUnitFlagManager = Spawn( class'UIUnitFlagManager', self );
		ScreenStack.Push( m_kUnitFlagManager );
	}
}

simulated function ResetUnitFlag(StateObjectReference kUnitRef)
{
	local UIUnitFlag kFlag;
	local XComGameState_BaseObject StartingState;
	local int VisualizedHistoryIndex;

	if(m_kUnitFlagManager != None)
	{
		kFlag = m_kUnitFlagManager.GetFlagForObjectID(kUnitRef.ObjectID);
		if( kFlag != none )
		{
			VisualizedHistoryIndex = `XCOMVISUALIZATIONMGR.LastStateHistoryVisualized;
			StartingState = `XCOMHISTORY.GetGameStateForObjectID(kUnitRef.ObjectID, , VisualizedHistoryIndex);
			kFlag.UpdateFromState(StartingState, true);
			//kFlag.Hide();
			//m_kUnitFlagManager.RemoveFlag(kFlag);
		}
		else
		{
			m_kUnitFlagManager.AddFlag(kUnitRef);
		}
	}
}

simulated function UpdateConcealmentShader(bool ForceOff = false, bool ResetEffectTime = false, bool ForceToggle = false)
{
	local XComTacticalController TacticalController;
	local EConcealmentShaderOverride ConcealmentShaderOverride;
	local XComGameStateHistory History;
	local XComGameState_Unit UnitState;
	local bool EnableShader;

	// first check if we have cheated this with a console command. The console command overrides all
	ConcealmentShaderOverride = class'XComGameState_Cheats'.static.GetCheatsObject().ConcealmentShaderOverride;
	if(ConcealmentShaderOverride != eConcealmentShaderOverride_None)
	{
		EnableShader = ConcealmentShaderOverride == eConcealmentShaderOverride_On;
	}
	else
	{
		// no console command override, so check if we want to force it off
		if (ForceOff)
		{
			EnableShader = false;
		}
		else
		{
			// see if the currently active unit has concealment
			TacticalController = XComTacticalController(GetALocalPlayerController());
			History = `XCOMHISTORY;
			UnitState = XComGameState_Unit(History.GetGameStateForObjectID(TacticalController.GetActiveUnitStateRef().ObjectID, , `XCOMVISUALIZATIONMGR.LastStateHistoryVisualized));
			EnableShader = UnitState != none && UnitState.IsConcealed();
		}
	}

	if (ForceToggle)
		EnablePostProcessEffect('ConcealmentMode', !EnableShader, ResetEffectTime);

	EnablePostProcessEffect('ConcealmentMode', EnableShader, ResetEffectTime);

}

simulated function UIControllerMap()
{
	if( ScreenStack.GetScreen(class'UIControllerMap') == none )
	{
		TempScreen = Spawn( class'UIControllerMap', self );
		UIControllerMap(TempScreen).layout = eLayout_Battlescape; 	
		ScreenStack.Push( TempScreen );
	}
	else
	{
		//TODO: this should be refactored. Wherever this function is being called to toggle, should isntead be calling to pop. 
		ScreenStack.PopFirstInstanceOfClass(class'UIControllerMap');
	}
}

simulated function UIShowSquad() { PushState('State_TacticalHUD'); }
simulated function UIHideSquad() 
{ 
	if (GetStateName() == 'State_TacticalHUD')
		PopState(); 
	else   
		`warn("Attempt to hide squad but not currently showing squad!");
}


simulated function ZoomCameraOut()
{
	local X2CameraStack CameraStack;
	
	CameraStack = `CAMERASTACK;
	CameraStack.ZoomCameras(2.0); // cameras zoom from -1.0-1.0, so this will guarantee a maximum value
}
simulated function ZoomCameraIn()
{
	local X2CameraStack CameraStack;
	
	CameraStack = `CAMERASTACK;
	CameraStack.ZoomCameras(2.0); // make sure we are zoomed all the way out (max is 1, min is -1)
	CameraStack.ZoomCameras(-1.0); // zoom back in to normal
}
simulated function ZoomCameraScroll( bool bZoomIn, optional float amount = CAMERA_ZOOM_SCROLL_INCREMENT )
{
	local X2CameraStack CameraStack;
	
	CameraStack = `CAMERASTACK;
	CameraStack.ZoomCameras(bZoomIn ? amount : -amount);
}

simulated function ToggleZoom()
{
	m_bZoomToggledIn = !m_bZoomToggledIn;
	if (m_bZoomToggledIn)
	{
		ZoomCameraIn();
	}
	else
	{
		ZoomCameraOut();
	}
}
//simulated function UITerrorInfoScreen()
//{
//	ScreenStack.Push( Spawn( class'UITerrorInfo', self ) );
//}
//
simulated function UITurnOverlay()
{
	if (m_kTurnOverlay == None)
	{
		m_kTurnOverlay = Spawn( class'UITurnOverlay', self );
		ScreenStack.Push( m_kTurnOverlay );
	}
}

simulated function UIEnemyArrows()
{
	ScreenStack.Push( Spawn( class'UIEnemyArrowContainer', self ) );
}

simulated function UIMPShowGameOverScreen( bool bWinner )
{
	UIPostMatchSummary();
	`log("Win?: " $ bWinner );

	if(m_kMultiplayerChatManager != none)
		m_kMultiplayerChatManager.GameEnded();
}

simulated function UIPostMatchSummary()
{
	ScreenStack.Push( Spawn( class'UIMultiplayerPostMatchSummary', self ));
}

// TODO: Go back to lobby instead of disconnect.
simulated function UILeaveMultiplayerMatch()
{
	XComTacticalController(Owner).AttemptExit();
}

simulated function UIMPShowPlayerStats( XComMultiplayerUI kMPInterface  )
{
	TempScreen = Spawn( class'UIMultiplayerPlayerStats', self );
	UIMultiplayerPlayerStats(TempScreen).m_kMPInterface = kMPInterface; 	
	ScreenStack.Push( TempScreen );
}


simulated function UICombatLoseScreen( UICombatLoseType eLoseType ) 
{
	TempScreen = Spawn( class'UICombatLose', self );
	UICombatLose(TempScreen).m_eType = eLoseType; 	
	ScreenStack.Push( TempScreen );
}



//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//                             PRESENTATION LAYER INTERFACE
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

//Called based on UI Update frequency 
simulated function UIUpdate()
{
	super.UIUpdate();


	if ( m_kUnitFlagManager != none )
		m_kUnitFlagManager.Update();

 	UpdateSuppressionMsg();

	if( m_kEnemyArrows != none)
		m_kEnemyArrows.Update();
	
	if (m_kUITutorialMgr != none)
	     m_kUITutorialMgr.Update();
}

simulated function UpdateSuppressionMsg()
{
	local XGUnit        kActiveUnit;
	local XCom3DCursor  kCursor;

	if(XComTacticalController(Owner) == none)
	{
		//Occurs within the seamless loading transition
		return;
	}

	kCursor = XComTacticalController(Owner).GetCursor();
	kActiveUnit = XComTacticalController(Owner).GetActiveUnit();

	if( kActiveUnit == none || kCursor.bHidden )
	{
		if ( m_bSuppressionMessageActive )
		{
			GetWorldMessenger().RemoveMessage( "cursorSuppressMsg" );
			m_bSuppressionMessageActive = false;
		}
		return;
	}

	// MHU - Suppression cursor message
	if (false)//kPathingAction != none && kActiveUnit.GetNumberOfSuppressors() > 0)
	{
		GetWorldMessenger().Message("<img src='" $ m_strSuppressedIcon $ "' vspace='-3'/>" $ m_strSuppressed, kActiveUnit.Location, kActiveUnit.GetVisualizedStateReference(), eColor_Attention, class'UIWorldMessageMgr'.const.FXS_MSG_BEHAVIOR_STEADY, "cursorSuppressMsg");
		m_bSuppressionMessageActive = true;
	}
	else if ( m_bSuppressionMessageActive )
	{
		GetWorldMessenger().RemoveMessage( "cursorSuppressMsg" );
		m_bSuppressionMessageActive = false;
	}
}

simulated function XComCamera GetCamera()
{
	return m_kCamera;
}

simulated function UITacticalHUD GetTacticalHUD()
{
	return m_kTacticalHUD;
}

simulated function UISpecialMissionHUD GetSpecialMissionHUD()
{
	return UISpecialMissionHUD(ScreenStack.GetScreen(class'UISpecialMissionHUD'));
}

simulated function UIChallengeModeHUD GetChallengeModeHUD()
{
	return UIChallengeModeHUD( ScreenStack.GetScreen( class'UIChallengeModeHUD' ) );
}

simulated function XComActionIconManager GetActionIconMgr()
{
	return m_kActionIconManager;
}

simulated function XComLevelBorderManager GetLevelBorderMgr()
{
	return m_kLevelBorderManager;
}

simulated private function XComSoundManager GetSoundMgr() 
{ 
	return `XTACTICALSOUNDMGR; 
}

simulated function RemoveLevelBorder()
{
	m_kLevelBorderManager.SetBorderGameHidden(true);
}

simulated function bool IsBusy()
{
	return /*CAMIsBusy() ||*/ UIIsBusy();
}

// TODO: no slomo in multilayer right now because it is controlled by the server and can
// throw off animation timing and break action (i.e. slomo on XGAction_Fire). also
// slomo is a noop on clients because it calls on the WorldInfo.Game which doesnt exist. -tsmith 
// NOTE: the 'slomo' command will only work when the cheatmanager is enabled.   -tsmith 
/*simulated function EngageBulletTime( float fTimeDilation )
{
	if(WorldInfo.NetMode == NM_Standalone)
	{
		m_fTimeDilation = fTimeDilation;
		//Owner.ConsoleCommand( "SloMo" @ string(m_fTimeDilation) );
	}
}

simulated function DisengageBulletTime()
{
	if(WorldInfo.NetMode == NM_Standalone)
	{
		m_fTimeDilation = 1;
		//Owner.ConsoleCommand( "SloMo 1.0" );
	}
}

simulated function bool IsInBulletTime()
{
	return m_fTimeDilation != 1;
}

simulated function float GetTimeDilation()
{
	return m_fTimeDilation;
}*/

// Toggle the procedural dramatic cameras
function ToggleDramaticCameras()
{
	m_bDramaticCameraAllowed = !m_bDramaticCameraAllowed;
}
function bool IsDramaticCameraAllowed()
{
	return m_bDramaticCameraAllowed;
}

//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//                             HUD INTERFACE
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
simulated function ShowFriendlySquadStatistics()
{
	if (m_kUnitFlagManager != None)
		m_kUnitFlagManager.ShowAllFriendlyFlags();
}

simulated function HideFriendlySquadStatistics()
{
	if (m_kUnitFlagManager != None)
		m_kUnitFlagManager.HideAllFriendlyFlags();
}

simulated function ShowEnemySquadStatistics()
{
	if (m_kUnitFlagManager != None)
		m_kUnitFlagManager.ShowAllEnemyFlags();
}

simulated function HideEnemySquadStatistics()
{
	if (m_kUnitFlagManager != None)
		m_kUnitFlagManager.HideAllEnemyFlags();
}

simulated function HUDHide()
{
	if( !(`CHEATMGR != None && `CHEATMGR.bAllowSelectAll) )
	{
		m_kTacticalHUD.Hide();
		if( m_kMultiplayerHUD != none )
		{
			m_kMultiplayerHUD.Hide();
		}
	}
}

simulated function HUDShow(optional bool ShowTacticalHUD = true, optional bool IgnroreUntilInternalUpdate = false)
{
	// Don't show the TacticalHUD if the mission is over - sbatista 7/12/13
	if((m_kMissionSummary != none) || (m_kChallengeModeSummary != none))
		return;

	// When the turn begins, delay showing the HUD so that the animation state of UI elements is set before TacticalHUD is shown.
	// NOTE: HUD is now shown inside UITacticalHUD.InternalUpdate
	if(ShowTacticalHUD && m_kTacticalHUD != None)
		m_kTacticalHUD.Show();

	if( m_kMultiplayerHUD != none )
	{
		m_kMultiplayerHUD.Show();
	}

	if (IgnroreUntilInternalUpdate && m_kTacticalHUD != None)
	{
		m_kTacticalHUD.m_bIgnoreShowUntilInternalUpdate = true;
	}
}

// OVERRIDE BASE
// Show UI pieces after an ciematic has been played.
simulated function ShowUIForCinematics()
{	
	super.ShowUIForCinematics();
	
	HUDShow();
}

//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//                             PROTO HUD INTERFACE
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
simulated function PHUDMissionObjective( string strObjective )
{
	GetMessenger().Message(strObjective, eIcon_GenericCircle, ePulse_Cyan, 5);
}

simulated function PHUDShowHPBar( XGUnit kUnit, optional float fTimer = -1, optional int iDamage )
{
	//m_kProtoHUD.ShowUnitHP( kUnit, fTimer, iDamage );
}

simulated function PHUDHideHPBar( XGUnit kUnit )
{
	//m_kProtoHUD.HideUnitHP( kUnit );
}

/*  jbouscher - REFACTORING CHARACTERS
simulated function PHUDLevelUp( XGCharacter_Soldier kSoldier )
{
	local string message;
	message = Repl(m_sLevelUp, "%sRANK", `GAMECORE.GetRankString( kSoldier.m_kSoldier.iRank ));
	ReplaceText(message, "%sNAME", kSoldier.m_kSoldier.strLastName );
	
	GetMessenger().Message( message, eIcon_GenericCircle, ePulse_Cyan, 5 );
	kSoldier.m_kUnit.SetTimer(3, false, 'DelayPromotionSound');
}
*/

/*simulated function PHUDMessage( vector vLocation, string strMessage, optional EWidgetColor eColor = eColor_Cyan )
{
	if (m_kProtoHUD != none)
		m_kProtoHUD.HUDMsg( vLocation, strMessage, eColor );
}*/

simulated function MSGHunted( XGUnit kUnit )
{

}

simulated function MSGWeaponFragments(string strItem, int iNumFragments)
{
	local XGParamTag kTag;

	kTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	kTag.StrValue0 = strItem;
	kTag.IntValue0 = iNumFragments;

	GetMessenger().Message( `XEXPAND.ExpandString(m_strItemExplodeFragments), eIcon_ExclamationMark, ePulse_Cyan,5,,   );
}
simulated function MSGItemDestroyed( string strItem )
{
	local XGParamTag kTag;

	kTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	kTag.StrValue0 = strItem;

	GetMessenger().Message( `XEXPAND.ExpandString(m_strItemDestroyed), eIcon_ExclamationMark, ePulse_Red,5,,   );
}

simulated function MSGArmorFragments( string strChar, int iNumFragments )
{
	local XGParamTag kTag;

	kTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	kTag.StrValue0 = strChar;
	kTag.IntValue0 = iNumFragments;

	GetMessenger().Message( `XEXPAND.ExpandString(m_strArmorExplodeFragments), eIcon_ExclamationMark, ePulse_Cyan,5,,   );
}

simulated function MSGCloseEncounter( XGUnit kUnit )
{
	local XGParamTag kTag;
	local XComUIBroadcastMessage kBroadcastMessage;

	kTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	kTag.StrValue0 = kUnit.SafeGetCharacterName();

	kBroadcastMessage = GetMessenger().Message( `XEXPAND.ExpandString(`GAMECORE.m_aExpandedLocalizedStrings[eELS_UnitInCloseCombat]), eIcon_ExclamationMark, ePulse_Cyan,,, kUnit.m_eTeamVisibilityFlags, class'XComUIBroadcastMessage_ExpandUnitNameString' );
	if(kBroadcastMessage != none)
	{
		XComUIBroadcastMessage_ExpandUnitNameString(kBroadcastMessage).Init_ExpandUnitNameString(eELS_UnitInCloseCombat, kUnit, kUnit.m_eTeamVisibilityFlags, eIcon_ExclamationMark, ePulse_Cyan);
	}
}

simulated function MSGOverwatchShot( XGUnit kUnit )
{
	local XGParamTag kTag;
	local XComUIBroadcastMessage kBroadcastMessage;

	kTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	kTag.StrValue0 = kUnit.SafeGetCharacterName();

	kBroadcastMessage = GetMessenger().Message( `XEXPAND.ExpandString(`GAMECORE.m_aExpandedLocalizedStrings[eELS_UnitReactionShot]), eIcon_ExclamationMark, ePulse_Cyan,,, kUnit.m_eTeamVisibilityFlags, class'XComUIBroadcastMessage_ExpandUnitNameString' );
	if(kBroadcastMessage != none)
	{
		XComUIBroadcastMessage_ExpandUnitNameString(kBroadcastMessage).Init_ExpandUnitNameString(eELS_UnitReactionShot, kUnit, kUnit.m_eTeamVisibilityFlags, eIcon_ExclamationMark, ePulse_Cyan);
	}
}

simulated function MSGCriticallyWounded( XGUnit kUnit )
{
	local XGParamTag kTag;
	local XComUIBroadcastMessage kBroadcastMessage;

	kTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	kTag.StrValue0 = kUnit.SafeGetCharacterName();

	kBroadcastMessage = GetMessenger().Message( `XEXPAND.ExpandString(`GAMECORE.m_aExpandedLocalizedStrings[eELS_UnitCriticallyWounded]), eIcon_ExclamationMark, ePulse_Red,7,, kUnit.m_eTeamVisibilityFlags, class'XComUIBroadcastMessage_ExpandUnitNameString');
	if(kBroadcastMessage != none)
	{
		XComUIBroadcastMessage_ExpandUnitNameString(kBroadcastMessage).Init_ExpandUnitNameString(eELS_UnitCriticallyWounded, kUnit, kUnit.m_eTeamVisibilityFlags, eIcon_ExclamationMark, ePulse_Red, 7);
	}

	kUnit.UnitSpeak( 'TakingDamage', true );

	PlaySound( SoundCue(DynamicLoadObject("SoundAmbience.CriticalWoundCue", class'SoundCue')), true );
}

simulated function MSGSoldierDied(XGUnit kUnit)
{
	local XGParamTag kTag;
	local XComUIBroadcastMessage kBroadcastMessage;

	kTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	kTag.StrValue0 = kUnit.SafeGetCharacterName();

	kBroadcastMessage = GetMessenger().Message( `XEXPAND.ExpandString(`GAMECORE.m_aExpandedLocalizedStrings[eELS_SoldierDied]), eIcon_ExclamationMark, ePulse_Red,7,, kUnit.m_eTeamVisibilityFlags, class'XComUIBroadcastMessage_ExpandUnitNameString');
	if(kBroadcastMessage != none)
	{
		XComUIBroadcastMessage_ExpandUnitNameString(kBroadcastMessage).Init_ExpandUnitNameString(eELS_SoldierDied, kUnit, kUnit.m_eTeamVisibilityFlags, eIcon_ExclamationMark, ePulse_Red, 7);
	}

	kUnit.SetTimer(3, false, 'DelayKillSting');
}

simulated function MSGTankDied(XGUnit kUnit)
{
	local XGParamTag kTag;
	local XComUIBroadcastMessage kBroadcastMessage;

	kTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	kTag.StrValue0 = kUnit.SafeGetCharacterName();

	kBroadcastMessage = GetMessenger().Message( `XEXPAND.ExpandString(`GAMECORE.m_aExpandedLocalizedStrings[eELS_TankDied]), eIcon_ExclamationMark, ePulse_Red,7,, kUnit.m_eTeamVisibilityFlags, class'XComUIBroadcastMessage_ExpandUnitNameString');
	if(kBroadcastMessage != none)
	{
		XComUIBroadcastMessage_ExpandUnitNameString(kBroadcastMessage).Init_ExpandUnitNameString(eELS_TankDied, kUnit, kUnit.m_eTeamVisibilityFlags, eIcon_ExclamationMark, ePulse_Red, 7);
	}

	PlaySound( SoundCue(DynamicLoadObject("SoundAmbience.DeathStingCue", class'SoundCue')), true );
}

simulated function MSGStunned( XGUnit kUnit )
{
	local XGParamTag kTag;
	local XComUIBroadcastMessage kBroadcastMessage;

	kTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	kTag.StrValue0 = kUnit.SafeGetCharacterName();

	kBroadcastMessage = GetMessenger().Message( `XEXPAND.ExpandString(`GAMECORE.m_aExpandedLocalizedStrings[eELS_UnitIsStunned]), eIcon_ExclamationMark, ePulse_Red,7,, kUnit.m_eTeamVisibilityFlags, class'XComUIBroadcastMessage_ExpandUnitNameString');
	if(kBroadcastMessage != none)
	{
		XComUIBroadcastMessage_ExpandUnitNameString(kBroadcastMessage).Init_ExpandUnitNameString(eELS_UnitIsStunned, kUnit, kUnit.m_eTeamVisibilityFlags, eIcon_ExclamationMark, ePulse_Red, 7);
	}
}

simulated function MSGRecoveredFromCriticalWound( XGUnit kUnit)
{
	local XGParamTag kTag;
	local XComUIBroadcastMessage kBroadcastMessage;

	kTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	kTag.StrValue0 = kUnit.SafeGetCharacterName();

	kBroadcastMessage = GetMessenger().Message( `XEXPAND.ExpandString(`GAMECORE.m_aExpandedLocalizedStrings[eELS_UnitRecovered]), eIcon_ExclamationMark, ePulse_Cyan,,, kUnit.m_eTeamVisibilityFlags, class'XComUIBroadcastMessage_ExpandUnitNameString');
	if(kBroadcastMessage != none)
	{
		XComUIBroadcastMessage_ExpandUnitNameString(kBroadcastMessage).Init_ExpandUnitNameString(eELS_UnitRecovered, kUnit, kUnit.m_eTeamVisibilityFlags, eIcon_ExclamationMark, ePulse_Cyan);
	}
	PlaySound( SoundCue(DynamicLoadObject("SoundAmbience.SoldierRevivedCue", class'SoundCue')), true );
}
simulated function MSGStabilized( XGUnit kUnit)
{
	local XGParamTag kTag;
	local XComUIBroadcastMessage kBroadcastMessage;

	kTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	kTag.StrValue0 = kUnit.SafeGetCharacterName();

	kBroadcastMessage = GetMessenger().Message( `XEXPAND.ExpandString(`GAMECORE.m_aExpandedLocalizedStrings[eELS_UnitStabilized]), eIcon_ExclamationMark, ePulse_Cyan,,, kUnit.m_eTeamVisibilityFlags, class'XComUIBroadcastMessage_ExpandUnitNameString');
	if(kBroadcastMessage != none)
	{
		XComUIBroadcastMessage_ExpandUnitNameString(kBroadcastMessage).Init_ExpandUnitNameString(eELS_UnitStabilized, kUnit, kUnit.m_eTeamVisibilityFlags, eIcon_ExclamationMark, ePulse_Cyan);
	}

	PlaySound( SoundCue(DynamicLoadObject("SoundAmbience.SoldierStabilizedCue", class'SoundCue')), true );
}

simulated function MSGBleedingOut( XGUnit kUnit )
{
	local XGParamTag kTag;
	local XComUIBroadcastMessage kBroadcastMessage;

	if (kUnit.m_bStunned)
		return;                 //  being stunned is not the same thing as being critically wounded!

	kTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	kTag.StrValue0 = kUnit.SafeGetCharacterName();

	if (kUnit.m_iCriticalWoundCounter > 0) 
	{
		kTag.IntValue0 = kUnit.m_iCriticalWoundCounter;
		kBroadcastMessage = GetMessenger().Message( `XEXPAND.ExpandString(`GAMECORE.m_aExpandedLocalizedStrings[eELS_UnitBleedOut]), eIcon_ExclamationMark, ePulse_Red,4,, kUnit.m_eTeamVisibilityFlags, class'XComUIBroadcastMessage_UnitBleedingOut');
		if(kBroadcastMessage != none)
		{
			XComUIBroadcastMessage_UnitBleedingOut(kBroadcastMessage).Init_UnitBleedingOut(eELS_UnitBleedOut, kUnit, kUnit.m_iCriticalWoundCounter, kUnit.m_eTeamVisibilityFlags, eIcon_ExclamationMark, ePulse_Red, 4);
		}

		PlaySound( SoundCue(DynamicLoadObject("SoundAmbience.CriticalWoundSubsequentCue", class'SoundCue')), true );
	}
	else
	{
		kBroadcastMessage = GetMessenger().Message( `XEXPAND.ExpandString(`GAMECORE.m_aExpandedLocalizedStrings[eELS_UnitBledOut]), eIcon_ExclamationMark, ePulse_Red,,, kUnit.m_eTeamVisibilityFlags, class'XComUIBroadcastMessage_UnitBleedingOut');
		if(kBroadcastMessage != none)
		{
			XComUIBroadcastMessage_UnitBleedingOut(kBroadcastMessage).Init_UnitBleedingOut(eELS_UnitBledOut, kUnit, kUnit.m_iCriticalWoundCounter, kUnit.m_eTeamVisibilityFlags, eIcon_ExclamationMark, ePulse_Red);
		}
	}
}
simulated function MSGReanimate( XGUnit kUnit)
{
	local XGParamTag kTag;
	local XComUIBroadcastMessage kBroadcastMessage;

	kTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	kTag.StrValue0 = kUnit.SafeGetCharacterName();

	kBroadcastMessage = GetMessenger().Message( `XEXPAND.ExpandString(`GAMECORE.m_aExpandedLocalizedStrings[eELS_UnitReturnDeath]), eIcon_ExclamationMark, ePulse_Cyan,,, kUnit.m_eTeamVisibilityFlags, class'XComUIBroadcastMessage_ExpandUnitNameString');
	if(kBroadcastMessage != none)
	{
		XComUIBroadcastMessage_ExpandUnitNameString(kBroadcastMessage).Init_ExpandUnitNameString(eELS_UnitReturnDeath, kUnit, kUnit.m_eTeamVisibilityFlags, eIcon_ExclamationMark, ePulse_Cyan);
	}
}
function PHUDPanicking( XGUnit kUnit )
{
	local XGParamTag kTag;

	kTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	kTag.StrValue0 = kUnit.SafeGetCharacterName();

	GetMessenger().Message( `XEXPAND.ExpandString(m_strUnitPanicked), eIcon_ExclamationMark, ePulse_Red,,, kUnit.m_eTeamVisibilityFlags );
}

simulated function PHUDShowSquad()
{
	/*if(m_kProtoHUD != none)
		m_kProtoHUD.ShowSquad();*/
}

//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//                             UI INTERFACE
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

// Return true if a modal UI screen is up
simulated function bool UIIsBusy()
{
	return ((!Get2DMovie().bIsInited || Get2DMovie().HasModalScreens())
		    ||  (m_kControllerMap != none && m_kControllerMap.bIsVisible)
			||  HACK_bUIBusy);
}

simulated function SetHackUIBusy( bool bBusy )
{
	HACK_bUIBusy = bBusy;
}

simulated function UIEndGame()
{
	ConsoleCommand("demostop");
}

//----------------------------------------------------

simulated function UITimerMessage( string sTitle, string sSubtitle, string sCounter, int iUIState, bool bShow )
{
	local UISpecialMissionHUD_TurnCounter kTurnCounter;

	// Check to make sure Special Mission HUD is initialized, show error if it's not.
	if(GetSpecialMissionHUD() == none || GetSpecialMissionHUD().m_kGenericTurnCounter == none)
	{
		ScriptTrace();
		`log("GetSpecialMissionHUD() = " $ GetSpecialMissionHUD());
		`log("SpecialMissionHUD.GenericTurnCounter = " $ GetSpecialMissionHUD().m_kGenericTurnCounter);
		PopupDebugDialog("UI ERROR", "Encountered uninitialized values SpecialMissionHUD. Please inform UI team and provide log." $ 
									 "This can be caused if 'DisplayUISpecialMissionTimer' Kismet event is used during a Meld / Control Point mission.");
	}

	kTurnCounter = GetSpecialMissionHUD().m_kGenericTurnCounter;

	if( bShow )
	{
		kTurnCounter.SetUIState( iUIState );
		kTurnCounter.SetLabel(sTitle);
		kTurnCounter.SetSubLabel(sSubtitle);
		kTurnCounter.SetCounter( sCounter );
		kTurnCounter.Show();
	}
	else 
		kTurnCounter.Hide(); 
}

simulated function ConfirmStartTimerCallback(eUIAction Action); // DEPRECATED bsteiner 3/24/2016

simulated function UIChallengeStartTimerMessage()
{
	ScreenStack.Push( Spawn( class'UIChallengeModeScoringDialog', self ) );
}

simulated function bool WaitForChallengeAccept()
{
	return ScreenStack.GetScreen( class'UIChallengeModeScoringDialog' ) != none;
}

simulated function UIAbilityHUD()
{
	local XComEngine Engine;
	if (m_kTacticalHUD == None)
	{
		Engine = `XENGINE;
		if (Engine.IsMultiPlayerGame())
		{
			// MP Chat is PC specific functionality.
			if(!WorldInfo.IsConsoleBuild())
			{
				ScreenStack.Push( Spawn( class'UIMultiplayerChatManager', self), GetModalMovie() );
			}
		}

		m_kTacticalHUD = Spawn( class'UITacticalHUD', self );
		ScreenStack.Push( m_kTacticalHUD );
	}
}
simulated function DeactivateAbilityHUD()
{
	ScreenStack.PopIncludingClass(class'UIMultiplayerChatManager',false);

	m_kTacticalHUD = none;
}



// This is called when key bindings are updated.
simulated function UpdateShortcutText()
{
	if(m_kTacticalHUD != none)
	{
		if(m_kTacticalHUD.m_kMouseControls != none)
			m_kTacticalHUD.m_kMouseControls.UpdateControls();
	}
}

// Pop out of Shot HUD related states
simulated function PopTargetingStates()
{
	ScreenStack.PopIncludingClass(class'UIEnemyArrowContainer');

	m_kTacticalHUD.LowerTargetSystem();
}

simulated function UIMissionIntro( bool bShow )
{
	if( bShow )
	{
		m_kTacticalHUD.Hide();
		ScreenStack.Push(Spawn(class'UIMissionIntro', self));
	}
	else if(ScreenStack.IsInStack(class'UIMissionIntro'))
	{
		ScreenStack.PopFirstInstanceOfClass(class'UIMissionIntro');
		m_kTacticalHUD.Show();
	}
}

simulated function UIMissionSummaryScreen()
{
	local XComWorldData WorldData;

	if (m_kTacticalHUD != none )
		m_kTacticalHUD.Hide();

	m_kMissionSummary = UIMissionSummary(ScreenStack.Push( Spawn( class'UIMissionSummary', self )));

	m_kActionIconManager.ShowIcons(false);
		
	WorldData = class'XComWorldData'.static.GetWorldData();
	if( WorldData != none && WorldData.Volume != none )
	{
		WorldData.Volume.BorderComponent.SetCustomHidden(TRUE);
		WorldData.Volume.BorderComponentDashing.SetCustomHidden(TRUE);
	}
}

simulated function UIMissionSummaryScreen_Deactivate()
{
	local XComWorldData WorldData;

	m_kActionIconManager.ShowIcons(true);

	WorldData = class'XComWorldData'.static.GetWorldData();
	if( WorldData != none && WorldData.Volume != none )
	{
		WorldData.Volume.BorderComponent.SetCustomHidden(TRUE);
		WorldData.Volume.BorderComponentDashing.SetCustomHidden(TRUE);
	}

	`BATTLE.QuitAndTransition();
}

simulated function UIChallengeModeSummaryScreen( )
{
	local XComWorldData WorldData;

	if (m_kTacticalHUD != none)
		m_kTacticalHUD.Hide( );

	m_kChallengeModeSummary = UIChallengePostScreen( ScreenStack.Push( Spawn( class'UIChallengePostScreen', self ) ) );

	m_kActionIconManager.ShowIcons( false );

	WorldData = class'XComWorldData'.static.GetWorldData( );
	if (WorldData != none && WorldData.Volume != none)
	{
		WorldData.Volume.BorderComponent.SetCustomHidden( TRUE );
		WorldData.Volume.BorderComponentDashing.SetCustomHidden( TRUE );
	}
}

simulated function UIChallengeModeSummaryScreen_Deactivate( )
{
	local XComWorldData WorldData;

	m_kActionIconManager.ShowIcons( true );

	WorldData = class'XComWorldData'.static.GetWorldData( );
	if (WorldData != none && WorldData.Volume != none)
	{
		WorldData.Volume.BorderComponent.SetCustomHidden( TRUE );
		WorldData.Volume.BorderComponentDashing.SetCustomHidden( TRUE );
	}

	`BATTLE.QuitAndTransition( );
}


simulated public function OnTurnTimerExpired()
{
	if( false ) //TODO: bsteiner: if( friendly fire popup is active
	{
		//Force the friendly fire popup down. 
		Get2DMovie().DialogBox.ClearDialogs();
		GetTacticalHUD().m_kAbilityHUD.HitFriendliesDialogueCallback(eUIAction_Cancel);

	}
	else
	{
		//Close up any confirm dialogue that may be up
		Get2DMovie().DialogBox.ClearDialogs();
	}
}

simulated function UIFriendlyFirePopup()
{
	// TODO: bsteiner: 11.4.2013 what should this be doing?
}

//MHU - New presentation function to clear UI elements when the tactical combat ends
simulated function UIEndBattle()
{   
	//local UI_FxsMessageBox MsgBox;

	// Future TODO: Once the new "grenade player" is added, we should add a  conditional check to specifically ignore the grenade turn. -bsteiner

	if( `BATTLE.IsA( 'XGBattle_SP' ) )
	{
		/*MsgBox = GetMessenger().GetMessage("endTurnMessage_Alien");
		if (MsgBox != none)
			MsgBox.AnimateOut();

		MsgBox = GetMessenger().GetMessage("endTurnMessage_Xcom");
		if (MsgBox != none)
			MsgBox.AnimateOut();*/
		
		//Turning off turn ovelay
		m_kTurnOverlay.Hide(); 
	}

	HUDHide();
}

//TODO: should this be converted to a state? -bsteiner 
simulated function UIEndTurn( ETurnOverlay eOverlayType )
{	
	switch( eOverlayType )
	{
		case eTurnOverlay_Local: 
			// When the turn begins, delay showing the HUD so that the animation state of UI elements is set before TacticalHUD is shown.
			// NOTE: HUD is now shown inside UITacticalHUD.InternalUpdate
			HUDShow(false, true);

			if( m_kTurnOverlay.IsShowingAlienTurn() )
				m_kTurnOverlay.HideAlienTurn();

			if( m_kTurnOverlay.IsShowingOtherTurn() )
				m_kTurnOverlay.HideOtherTurn();

			if( m_kTurnOverlay.IsShowingSpecialTurn() )
				m_kTurnOverlay.HideSpecialTurn();


			m_kTurnOverlay.ShowXComTurn();
			
			GetSpecialMissionHUD().m_kGenericTurnCounter.OnTurnChange(true);

			`XTACTICALSOUNDMGR.OnTurnVisualized(eTeam_XCom);
			
			m_kUnitFlagManager.StartTurn();
			break;

		case eTurnOverlay_Remote:
			HUDHide();
			GetSpecialMissionHUD().m_kGenericTurnCounter.OnTurnChange(false);
			m_kUnitFlagManager.EndTurn();
			m_kTurnOverlay.ShowOtherTurn();
			`XTACTICALSOUNDMGR.OnTurnVisualized(eTeam_Alien);
			break;

		case eTurnOverlay_Alien:
			HUDHide();
			m_kUnitFlagManager.EndTurn();
			m_kTurnOverlay.ShowAlienTurn();
			`XTACTICALSOUNDMGR.OnTurnVisualized(eTeam_Alien);
			break;

	}
}

simulated function UIHideAllHUD()
{
	if( m_kTurnOverlay.IsShowingAlienTurn() )
		m_kTurnOverlay.HideAlienTurn();
			
	if( m_kTurnOverlay.IsShowingOtherTurn() )
		m_kTurnOverlay.HideOtherTurn();

	if( m_kTurnOverlay.IsShowingXComTurn() )
		m_kTurnOverlay.HideXComTurn();

	if( m_kTurnOverlay.IsShowingSpecialTurn() )
		m_kTurnOverlay.HideSpecialTurn();

	HUDHide();
}

simulated function UIMPShowPostMatchSummary()
{
	UIHideAllHUD();
	UIMissionSummaryScreen();
}

simulated function UIMPShowDisconnectedOverlay()
{
	UIHideAllHUD();
	ScreenStack.Push( Spawn( class'UIMultiplayerDisconnectPopup', self ) );
}

simulated function UIShowMyTurnOverlay()
{
	if(m_kTurnOverlay != none && m_kTurnOverlay.bIsInited)
	{
		if(!m_kTurnOverlay.IsShowingXComTurn())
		{
			HUDShow();
			m_kTurnOverlay.PulseXComTurn();
		}
	}
	else
	{
		m_bUIShowMyTurnOnOverlayInit = true;
		m_bUIShowOtherTurnOnOverlayInit = false;
		m_bUIShowReflexActionOnOverlayInit = false;
		m_bUIShowSpecialTurnOnOverlayInit = false;
	}
}

simulated function UIShowOtherTurnOverlay()
{
	if(m_kTurnOverlay != none && m_kTurnOverlay.bIsInited)
	{
		if(!m_kTurnOverlay.IsShowingOtherTurn())
		{
			HUDHide();
			m_kTurnOverlay.PulseOtherTurn();
		}
	}
	else
	{
		m_bUIShowMyTurnOnOverlayInit = false;
		m_bUIShowOtherTurnOnOverlayInit = true;
		m_bUIShowReflexActionOnOverlayInit = false;
		m_bUIShowSpecialTurnOnOverlayInit = false;
	}
}
simulated function UIShowReflexOverlay()
{
	if(m_kTurnOverlay != none && m_kTurnOverlay.bIsInited)
	{
		if(!m_kTurnOverlay.IsShowingReflexAction())
		{
			m_kTurnOverlay.ShowReflexAction();
		}
	}
	else
	{
		m_bUIShowMyTurnOnOverlayInit = false;
		m_bUIShowOtherTurnOnOverlayInit = false;
		m_bUIShowReflexActionOnOverlayInit = true;
		m_bUIShowSpecialTurnOnOverlayInit = false;
	}
}

simulated function UIHideReflexOverlay()
{
	if (m_kTurnOverlay != None && m_kTurnOverlay.bIsInited)
	{
		if (m_kTurnOverlay.IsShowingReflexAction())
		{
			m_kTurnOverlay.HideReflexAction();
		}
	}
	else
	{
		m_bUIShowReflexActionOnOverlayInit = false;
	}
}

simulated function UIShowSpecialTurnOverlay()
{
	if( m_kTurnOverlay != none && m_kTurnOverlay.bIsInited )
	{
		if( !m_kTurnOverlay.IsShowingSpecialTurn() )
		{
			HUDHide();
			m_kTurnOverlay.ShowSpecialTurn();
		}
	}
	else
	{
		m_bUIShowMyTurnOnOverlayInit = false;
		m_bUIShowOtherTurnOnOverlayInit = false;
		m_bUIShowReflexActionOnOverlayInit = false;
		m_bUIShowSpecialTurnOnOverlayInit = true;
	}
}
simulated function UIHideSpecialTurnOverlay()
{
	if( m_kTurnOverlay != None && m_kTurnOverlay.bIsInited )
	{
		if( m_kTurnOverlay.IsShowingSpecialTurn() )
		{
			m_kTurnOverlay.HideSpecialTurn();
			HUDShow();
		}
	}
	else
	{
		m_bUIShowSpecialTurnOnOverlayInit = false;
	}
}

simulated function UICloseChat()
{
	local UIMultiplayerChatManager kChat; 

	kChat = UIMultiplayerChatManager(ScreenStack.GetScreen( class'UIMultiplayerChatManager' ));

	if(kChat != none)
		kChat.CloseChat();
}

simulated function UIInventoryTactical(XComGameState_Unit Looter, Lootable LootableObject, delegate<UIInventoryTactical.OnScreenClosed> Callback)
{
	m_kInventoryTactical = Spawn( class'UIInventoryTactical', self );
	m_kInventoryTactical.InitLoot(Looter, LootableObject, Callback);
	ScreenStack.Push( m_kInventoryTactical );
}

//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//                             3D UI INTERFACE
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

simulated function DRAWRange( vector vLocation, float fRadius, LinearColor clrRange )
{
	if( m_k3DUI != none)
	{
		m_k3DUI.DrawRange( vLocation, fRadius, clrRange );
	}
}

simulated function DRAWControlCone( Vector vStart, vector vDir, float fDist, float fAngle, LinearColor kColor )
{
	if( m_k3DUI != none)
	{
		m_k3DUI.DrawControlCone( vStart, vDir, fDist, fAngle, kColor );
	}
}
simulated function DRAWPinningCone( Vector vStart, XGUnit kPinnedUnit, LinearColor kColor )
{
	if( m_k3DUI != none)
	{
		m_k3DUI.DrawPinningCone( vStart, kPinnedUnit, kColor );
	}
}

simulated function DRAWSelectionCone(Vector vStart, Vector vDir, float fDist, float fAngle, LinearColor kColor)
{
	if (m_k3DUI != none)
	{
		m_k3DUI.DrawControlCone(vStart, vDir, fDist, fAngle, kColor);
	}
}

simulated function InitializeSpecialMissionUI()
{
	if( ScreenStack.GetScreen( class'UISpecialMissionHUD' ) == none && Get2DMovie().bIsInited )
	{
		ScreenStack.Push( Spawn( class'UISpecialMissionHUD', self ));
	}
	ScreenStack.GetScreen(class'UISpecialMissionHUD').AllowShowDuringCinematic(`XENGINE.IsMultiplayerGame());
}

simulated function InitializeChallengeModeUI()
{
	if (ScreenStack.GetScreen( class'UIChallengeModeHUD' ) == none && Get2DMovie( ).bIsInited)
	{
		ScreenStack.Push( Spawn( class'UIChallengeModeHUD', self ) );
	}
	ScreenStack.GetScreen( class'UIChallengeModeHUD' ).AllowShowDuringCinematic( `XENGINE.IsMultiplayerGame( ) );
}

simulated function OnPauseMenu(bool bOpened)
{
	if (m_kTacticalHUD != none && m_kTacticalHUD.m_kTutorialHelpBox != none)
	{
		m_kTacticalHUD.m_kTutorialHelpBox.ToggleDepth(!bOpened);
	}
}

function bool PlayerCanSave()
{	
	return true;
}

simulated function bool IsGameplayOptionEnabled(EGameplayOption option) 
{
	return `GAMECORE.IsOptionEnabled(option);
}

function EventListenerReturn OnPlayerTurnBegun(Object EventData, Object EventSource, XComGameState GameState, Name EventID)
{
	local XComGameState_Player EventPlayer, LocalStatePlayer;
	local XGPlayer PlayerVisualizer, LocalPlayer;
	
	LocalPlayer = XComTacticalController(GetALocalPlayerController()).m_XGPlayer;
	LocalStatePlayer = XComGameState_Player(`XCOMHISTORY.GetGameStateForObjectID(LocalPlayer.ObjectID));

	EventPlayer = XComGameState_Player(EventData);
	
	if( EventPlayer != none )
	{
		PlayerVisualizer = XGPlayer(EventPlayer.GetVisualizer());

		//Make the MP turn overlay its own thing once we get the art sized properly
		if( EventPlayer.IsEnemyPlayer(LocalStatePlayer) || PlayerVisualizer.IsRemote() )
		{			
			if( !m_kTurnOverlay.IsShowingAlienTurn() )
			{
				m_kTurnOverlay.ShowAlienTurn();
			}
		}
	}
	else
	{
		`redscreen("EventPlayer should not be NULL");
	}

	return ELR_NoInterrupt;
}

function EventListenerReturn OnPlayerTurnEnded(Object EventData, Object EventSource, XComGameState GameState, Name EventID)
{
	if( m_kTurnOverlay.IsShowingAlienTurn() )
	{
		m_kTurnOverlay.HideAlienTurn();
	}

	if( m_kTurnOverlay.IsShowingSpecialTurn() )
		m_kTurnOverlay.HideSpecialTurn();

	return ELR_NoInterrupt;
}

defaultproperties
{	
	// Don't display system messages during gameplay (single or otherwise), this functionality is only required in Multiplayer menus.
	// During play we handle connection errors and system message display differently - sbatista
	m_bBlockSystemMessageDisplay=true
	m_bDramaticCameraAllowed=false
	m_fTimeDilation=1
	m_bUse2DUnitNumber = false;
	m_eUIMode=eUIMode_Tactical;
	m_bIsDebugHideSelectedUnitDisc  = false;
	m_bAllowEnemyArrowSystem = true;
	m_strSuppressedIcon = "Icon_SUPRESSION_HTML";
	m_bZoomToggledIn=true;
}
