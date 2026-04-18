class SawRunner extends KFMonster;

#EXEC OBJ LOAD FILE=SawRunner_R.ukx

var() bool bBitchMode;

simulated function PostBeginPlay()
{
    super.PostBeginPlay();
    class'ScrnZedFunc'.static.ZedBeginPlay(self);
}

simulated function SetBurningBehavior(){}

simulated function UnSetBurningBehavior(){}

function bool CanGetOutOfWay()
{
    return false;
}

function Bump(actor Other)
{
        local KFMonster KFMonst;

        KFMonst = KFMonster(Other);

        // Hurt/Kill enemies that we run into while raging
        if( !bShotAnim && KFMonst!=None && SawRunner(Other)==None && Pawn(Other).Health>0 )
		{
			Other.TakeDamage(0, self, Other.Location, Velocity * Other.Mass, class'DamTypePoundCrushed');
		}
	Super(Monster).Bump(Other);
}

simulated function Destroyed()
{
    class'ScrnZedFunc'.static.ZedDestroyed(self);
    super.Destroyed();
}

function bool IsHeadShot(vector HitLoc, vector ray, float AdditionalScale)
{
    return class'ScrnZedFunc'.static.IsHeadShot(self, HitLoc, ray, AdditionalScale, vect(0,0,0));
}

function TakeDamage(int Damage, Pawn InstigatedBy, Vector Hitlocation, Vector momentum, class<DamageType> DamType, optional int HitIndex)
{
    if (InstigatedBy == none || class<KFWeaponDamageType>(DamType) == none)
        Super(Monster).TakeDamage(Damage, instigatedBy, hitLocation, momentum, DamType); // skip NONE-reference error
    else
        Super.TakeDamage(Damage, instigatedBy, hitLocation, momentum, DamType);
}

function bool CanAttack(Actor A)
{
    return class'ScrnZedFunc'.static.CanAttack(self, A);
}

function bool MeleeDamageTarget(int hitdamage, vector pushdir)
{
    return class'ScrnZedFunc'.static.MeleeDamageTarget(self, hitdamage, pushdir);
}

simulated function CalcAmbientRelevancyScale()
{
        // Make the zed only relevant by thier ambient sound out to a range of 30 meters
    	CustomAmbientRelevancyScale = 1500/(100 * SoundRadius);
}

function SetMindControlled(bool bNewMindControlled)
{
    if( bNewMindControlled )
    {
        NumZCDHits++;

        // if we hit him a couple of times, make him rage!
        if( NumZCDHits > 1 )
        {
            if( !IsInState('ChargeToMarker') )
            {
                GotoState('ChargeToMarker');
            }
            else
            {
                NumZCDHits = 1;
                if( IsInState('ChargeToMarker') )
                {
                    GotoState('');
                }
            }
        }
        else
        {
            if( IsInState('ChargeToMarker') )
            {
                GotoState('');
            }
        }

        if( bNewMindControlled != bZedUnderControl )
        {
            SetGroundSpeed(OriginalGroundSpeed * 1.25);
    		Health *= 1.25;
    		HealthMax *= 1.25;
		}
    }
    else
    {
        NumZCDHits=0;
    }

    bZedUnderControl = bNewMindControlled;
}

function PlayTakeHit(vector HitLocation, int Damage, class<DamageType> DamageType)
{
	if( Level.TimeSeconds - LastPainAnim < MinTimeBetweenPainAnims )
		return;

    // Don't interrupt the controller if its waiting for an animation to end
    if( !Controller.IsInState('WaitForAnim') && Damage >= 10 && FRand() <= 0.12 )
        PlayDirectionalHit(HitLocation);

	LastPainAnim = Level.TimeSeconds;

	if( Level.TimeSeconds - LastPainSound < MinTimeBetweenPainSounds )
		return;

	LastPainSound = Level.TimeSeconds;
	PlaySound(HitSound[0], SLOT_Pain,1.25,,400);
}

function RangedAttack(Actor A)
{
	if ( bShotAnim || Physics == PHYS_Swimming)
		return;
	else if ( CanAttack(A) )
	{
		bShotAnim = true;
		SetAnimAction('Claw');
		Controller.bPreparingMove = true;
		Acceleration = vect(0,0,0);
		return;
	}
}

/*
simulated function int DoAnimAction( name AnimName )
{
	if( AnimName=='Claw' )
	{
		AnimBlendParams(1, 1.0, 0.0,, SpineBone1);
		PlayAnim(AnimName,, 0.1, 1);
		Return 1;
	}
	Return Super.DoAnimAction(AnimName);
}
*/

simulated event SetAnimAction(name NewAction)
{
	local int meleeAnimIndex;

	if( NewAction=='' )
		Return;
	if(NewAction == 'Claw')
	{
		meleeAnimIndex = Rand(3);
		NewAction = meleeAnims[meleeAnimIndex];
		CurrentDamtype = ZombieDamType[meleeAnimIndex];
	}
	else if( NewAction == 'DoorBash' )
	{
	   CurrentDamtype = ZombieDamType[Rand(3)];
	}
	ExpectingChannel = DoAnimAction(NewAction);

    if( AnimNeedsWait(NewAction) )
    {
        bWaitForAnim = true;
    }

	if( Level.NetMode!=NM_Client )
	{
		AnimAction = NewAction;
		bResetAnimAct = True;
		ResetAnimActTime = Level.TimeSeconds+0.3;
	}
}

// The animation is full body and should set the bWaitForAnim flag
simulated function bool AnimNeedsWait(name TestAnim)
{
    if( TestAnim == 'KnockDown' || TestAnim == 'DoorBash'  || TestAnim == 'Claw' )
    {
        return true;
    }

    return false;
}

/*
simulated function Tick(float DeltaTime)
{
    super.Tick(DeltaTime);

    // Keep the flesh pound moving toward its target when attacking
	if( Role == ROLE_Authority && bShotAnim)
	{
		if( LookTarget!=None )
		{
		    Acceleration = AccelRate * Normal(LookTarget.Location - Location);
		}
    }

*/

// This is to stop him from getting exploded by FP rage hopefully
function bool SameSpeciesAs(Pawn P)
{
    return P.IsA('ZombieFleshPound') || P.IsA('SawRunner');
}

// Scales the damage this Zed deals by the difficulty level
function float DifficultyDamageModifer()
{
    local float AdjustedDamageModifier;

    // Honestly you REALLY shouldn't be getting hit but this is so he doesn't insta-kill you even though he really should if you get hit by him
    if (bBitchMode)
    {
	    return 1.0;
    }
    else
    {
        if ( Level.Game.GameDifficulty >= 7.0 ) // Hell on Earth
        {
        	AdjustedDamageModifier = 1.75;
        }
        else if ( Level.Game.GameDifficulty >= 5.0 ) // Suicidal
        {
        	AdjustedDamageModifier = 1.50;
        }
        else if ( Level.Game.GameDifficulty >= 4.0 ) // Hard
        {
        	AdjustedDamageModifier = 1.25;
        }
        else if ( Level.Game.GameDifficulty >= 2.0 ) // Normal
        {
        	AdjustedDamageModifier = 1.0;
        }
        else //if ( GameDifficulty == 1.0 ) // Beginner
        {
        	AdjustedDamageModifier = 0.3;
        }
        
        // Do less damage if we're alone
        if( Level.Game.NumPlayers == 1 )
        {
        	AdjustedDamageModifier *= 0.75;
        }
        
        return AdjustedDamageModifier;
    }
}

defaultproperties
{
     bMeleeStunImmune=True
     damageForce=70000
     bFatAss=True
     KFRagdollName="Clot_Trip"
     MeleeRange=65.0
     AmbientSoundScaling=8.0
     SoundVolume=200
     AmbientGlow=0
     Mass=600.000000
     RotationRate=(Yaw=45000,Roll=0)

     Health=3000
     HealthMax=3000
     PlayerCountHealthScale=0.10
     PlayerNumHeadHealthScale=0.10
     HeadHealth=1200
     MeleeDamage=65
     JumpZ=320.000000

     CollisionRadius=26.000000
     CollisionHeight=44
     bCanDistanceAttackDoors=False
     Intelligence=BRAINS_Mammal
     bUseExtendedCollision=True
     ColOffset=(Z=36)
     ColRadius=36
     ColHeight=33
     ZombieFlag=3
     BleedOutDuration=7.0
     HeadHeight=2.5
     HeadScale=1.5
     OnlineHeadshotOffset=(X=20,Y=0,Z=56)
     OnlineHeadshotScale=1.5
     MotionDetectorThreat=1.0
     ZapThreshold=1.5
     bHarpoonToHeadStuns=true
     bHarpoonToBodyStuns=false
     ScoringValue=150
     DamageToMonsterScale=5.0
     bBoss=True

     DetachedArmClass=Class'KFSawRunner.SawRunnerGibArm'
     DetachedLegClass=Class'KFSawRunner.SawRunnerGibLeg'
     DetachedHeadClass=Class'KFSawRunner.SawRunnerGibHead'

     MoanVoice=SoundGroup'SawRunner_R.sawrunner_noises'
     MeleeAttackHitSound=Sound'SawRunner_R.chainsaw_attack_hit'
     JumpSound=SoundGroup'SawRunner_R.sawrunner_noises'
     HitSound(0)=SoundGroup'SawRunner_R.sawrunner_pain'
     DeathSound(0)=Sound'SawRunner_R.sawrunner_death'
     ChallengeSound(0)=SoundGroup'SawRunner_R.sawrunner_noises'
     ChallengeSound(1)=SoundGroup'SawRunner_R.sawrunner_noises'
     ChallengeSound(2)=SoundGroup'SawRunner_R.sawrunner_noises'
     ChallengeSound(3)=SoundGroup'SawRunner_R.sawrunner_noises'
     AmbientSound=Sound'SawRunner_R.chainsaw_loop'

     Mesh=SkeletalMesh'SawRunner_R.sawrunner'
     Skins(0)=Texture'SawRunner_R.headlol'
     Skins(1)=Texture'SawRunner_R.skoside_2'
     Skins(2)=Texture'SawRunner_R.byxa_fram_2'
     Skins(3)=Texture'SawRunner_R.byxa_bak_2'
     Skins(4)=Texture'SawRunner_R.sko_under'
     Skins(5)=Texture'SawRunner_R.hand'
     Skins(6)=Texture'SawRunner_R.jacket_front'
     Skins(7)=Texture'SawRunner_R.jacket_back'
     Skins(8)=Texture'SawRunner_R.chainsawtex1'
     Skins(9)=Texture'SawRunner_R.tex1'

     HeadlessWalkAnims(0)="Walk1"
     HeadlessWalkAnims(1)="Walk1"
     HeadlessWalkAnims(2)="Walk1"
     HeadlessWalkAnims(3)="Walk1"
     BurningWalkFAnims(0)="Walk1"
     BurningWalkFAnims(1)="Walk1"
     BurningWalkFAnims(2)="Walk1"
     BurningWalkAnims(0)="Walk1"
     BurningWalkAnims(1)="Walk1"
     BurningWalkAnims(2)="Walk1"
     MeleeAnims(0)="Claw"
     MeleeAnims(1)="Claw"
     MeleeAnims(2)="Claw"
     HitAnims(0)="HitF"
     HitAnims(1)="HitF"
     HitAnims(2)="HitF"
     KFHitFront="HitF"
     KFHitBack="HitF"
     KFHitLeft="HitF"
     KFHitRight="HitF"

     MovementAnims(0)="Walk1"
     WalkAnims(0)="Walk1"
     WalkAnims(1)="Walk1"
     WalkAnims(2)="Walk1"
     WalkAnims(3)="Walk1"

     PuntAnim="Claw"

     IdleHeavyAnim="Idle"
     IdleRifleAnim="Idle"
     FireHeavyRapidAnim="Claw"
     FireHeavyBurstAnim="Claw"
     FireRifleRapidAnim="Claw"
     FireRifleBurstAnim="Claw"

     TurnLeftAnim="TurnLeft"
     TurnRightAnim="TurnRight"
     IdleCrouchAnim="Idle"
     IdleWeaponAnim="Idle"
     IdleRestAnim="Idle"

     DrawScale=1.5
     Prepivot=(Z=26.0)

     bCannibal = false
     MenuName="Sawrunner"

     GroundSpeed=225.000000
     WaterSpeed=225.000000

     ControllerClass=Class'KFChar.SawZombieController'
}
