/*__________________________________________________________________________________________________
| Too Many Frags																		    
|___________________________________________________________________________________________________
| Credits:																			    
| -=[DAG]=-		- Original Idea														    
| v3x			- Updating the "is_user_overlimit"										    
| ConnorMcLeod	- For his RemovePlayerSlotsItem function.								    
| Exolent		- For his GetWeaponFromSlot function.									    
|___________________________________________________________________________________________________
| CVars:																				    
| tmf_mode - <0 = disables the plugin || 1 = controlled by difference || 2 = controlled by K/D>	    
| tmf_difference - <Specify the difference>												    
| tmf_prefix - <Specify the Prefix before the message>										    
|___________________________________________________________________________________________________
| Made by:																			    
| Smatify - https://smatify.com										    
|___________________________________________________________________________________________________
| Changelog:	
| Version 1.0.4
|	-
|
| Version 1.0.3
|	- Added nvault_close at plugin_end
|																		    
| Version 1.0.2																		    
|	- Renamed from "Too Much Frags" to "Too Many Frags"									    
|	- Updating the Code																    
|	- Added Vault Saving for saving "Too many Frags" for a map.								    
|	- Fixed "Reliable Overflow"-Bug														    
|																					    
| Version 1.0.1																		    
| 	- Updating the Code																    
|																					    
| Version 1.0.0																		   
| 	- First release																	    
|__________________________________________________________________________________________________*/

#include <amxmodx>
#include <amxmisc>
#include <hamsandwich> 
#include <fun>

#include <nvault>
#include <fakemeta>

#tryinclude <cstrike_pdatas> 

#if !defined _cbaseentity_included 
#assert Cstrike Pdatas and Offsets library required! Read the below instructions:   \ 
1. Download it at forums.alliedmods.net/showpost.php?p=1712101#post1712101   
2. Put it into amxmodx/scripting/include/ folder 
3. Compile this plugin locally, details: wiki.amxmodx.org/index.php/Compiling_Plugins_%28AMX_Mod_X%29 
4. Install compiled plugin, details: wiki.amxmodx.org/index.php/Configuring_AMX_Mod_X#Installing 
#endif  

#define PLUGIN "Too Many Frags"
#define VERSION "1.0.4"
#define AUTHOR "Smatify"

#define MESSAGE_PREFIX "[TMF]"

// Comment to disable saving
#define VAULT_SAVE

new cvar_mode,cvar_differ,cvar_kd
new g_iOverlimit[33]

#if defined VAULT_SAVE
new g_Vault
#endif

enum _:hudHide ( <<= 1 ) 
{ 
	HUD_HIDE_CAL = 1, 
	HUD_HIDE_FLASH, 
	HUD_HIDE_ALL, 
	HUD_HIDE_RHA, 
	HUD_HIDE_TIMER, 
	HUD_HIDE_MONEY, 
	HUD_HIDE_CROSS, 
	HUD_DRAW_CROSS 
} 

enum _:ammoIndexes 
{ 
	ammo_none, 
	ammo_338magnum = 1, // 30 
	ammo_762nato, // 90 
	ammo_556natobox, // 200 
	ammo_556nato, // 90 
	ammo_buckshot, // 32 
	ammo_45acp, // 100 
	ammo_57mm, // 100 
	ammo_50ae, // 35 
	ammo_357sig, // 52 
	ammo_9mm, // 120 
	ammo_flashbang, // 2 
	ammo_hegrenade, // 1 
	ammo_smokegrenade, // 1 
	ammo_c4 // 1 
}

public plugin_init() 
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	register_cvar("tmf_version", VERSION, FCVAR_SERVER | FCVAR_SPONLY | FCVAR_EXTDLL)
	
	register_event("CurWeapon", "CurWeapon", "be", "1=1")
	
	cvar_mode	= register_cvar("tmf_mode", "1")
	cvar_differ	= register_cvar("tmf_difference", "10")
	cvar_kd		= register_cvar("tmf_kills_per_death", "1.5")
	
	#if defined VAULT_SAVE
	g_Vault = nvault_open("tmf-vault")
	nvault_prune(g_Vault,0,get_systime())
	#endif
}

public client_authorized(id)
{
	g_iOverlimit[id] = 0
	#if defined VAULT_SAVE
	load_user_state(id)
	#endif
}

public client_disconnect(id)
{	
	g_iOverlimit[id] = 0
	#if defined VAULT_SAVE
	save_user_state(id)
	#endif
}

public save_user_state(id)
{  
	check_user_overlimit(id)
	
	new AuthID[35] 
	get_user_authid(id,AuthID,34) 
	new vaultkey[64],vaultdata[256] 
	
	format(vaultkey,63,"%s-TMF",AuthID) 
	format(vaultdata,255,"%i",g_iOverlimit[id]) 
	
	nvault_set(g_Vault,vaultkey,vaultdata) 
	return PLUGIN_CONTINUE 
}  

public load_user_state(id)
{ 
	new AuthID[35]
	get_user_authid(id,AuthID,34) 
	
	new vaultkey[64],vaultdata[256]  
	format(vaultkey,63,"%s-TMF",AuthID) 
	format(vaultdata,255,"%i",g_iOverlimit[id]) 
	
	nvault_get(g_Vault,vaultkey,vaultdata,255) 
	new statement[32]
	parse(vaultdata, statement, 31) 
	
	g_iOverlimit[id] = str_to_num(statement)
	return PLUGIN_CONTINUE 
}  

public CurWeapon(id)
{
	check_user_overlimit(id)
	new iWeapon = GetWeaponFromSlot(id,1)
	
	new s_Map[32]
	get_mapname(s_Map, charsmax(s_Map))
	
	new kd = get_user_frags(id) /  get_user_deaths(id)
	
	if(contain(s_Map, "de_") || contain(s_Map, "de_") && g_iOverlimit[id] > 0 && iWeapon > 0)
	{
		RemovePlayerSlotsItem(id,1)
		new user_name[33]
		get_user_name(id, user_name, charsmax(user_name))
		
		if(get_pcvar_num(cvar_mode) == 1)
		{
			print_color(0,id,0, "^4%s ^3%s ^1reached %i+. ^3%s ^1can now only play with secondary weapons.", MESSAGE_PREFIX, user_name, get_pcvar_num(cvar_differ), user_name)	
		}
		else if(get_pcvar_num(cvar_mode) == 2)
		{
			print_color(0,id,0,"^4%s ^%s ^1has a K/D from %i and reached &i.", MESSAGE_PREFIX, user_name, kd, get_pcvar_num(cvar_kd))
			print_color(0,id,0,"^1He can now only play with secondary weapons")
		}
	}
	return PLUGIN_HANDLED
}

public check_user_overlimit(id)
{
	new pcvar_mode = get_pcvar_num(cvar_mode)
	
	if(!pcvar_mode || !is_user_connected(id))
		return PLUGIN_HANDLED
	
	
	new frags = get_user_frags(id)
	new deaths = get_user_deaths(id)
	
	switch(pcvar_mode)
	{
		case 1:
		{
			if(frags - deaths >= get_pcvar_num(cvar_differ))
				g_iOverlimit[id] = 1
			return PLUGIN_HANDLED
		}
		case 2:
		{
			if(frags / deaths >= get_pcvar_num(cvar_kd))
				g_iOverlimit[id] = 1
			return PLUGIN_HANDLED
		}
	}
	g_iOverlimit[id] = 0
	return PLUGIN_HANDLED
}

public plugin_end()
{
	nvault_close(g_Vault)
}

public print_color(id, cid, color, const message[], any:...)
{
	new msg[192]
	vformat(msg, charsmax(msg), message, 5)
	new param
	if (!cid) 
		return
	else 
		param = cid
	
	new team[32]
	get_user_team(param, team, 31)
	switch (color)
	{
		case 0: msg_teaminfo(param, team)
		case 1: msg_teaminfo(param, "TERRORIST")
		case 2: msg_teaminfo(param, "CT")
		case 3: msg_teaminfo(param, "SPECTATOR")
	}
	if (id) msg_saytext(id, param, msg)
	else msg_saytext(0, param, msg)
		
	if (color != 0) msg_teaminfo(param, team)
}

msg_saytext(id, cid, msg[])
{
	message_begin(id?MSG_ONE:MSG_ALL, get_user_msgid("SayText"), {0,0,0}, id)
	write_byte(cid)
	write_string(msg)
	message_end()
}

msg_teaminfo(id, team[])
{
	message_begin(MSG_ONE, get_user_msgid("TeamInfo"), {0,0,0}, id)
	write_byte(id)
	write_string(team)
	message_end()
}

RemovePlayerSlotsItem(id, iSlot) 
{ 
	if( !(1 <= iSlot <= 5) ) 
	{ 
		return 0 
	} 
	
	new iActiveItem = get_pdata_cbase(id, m_pActiveItem) 
	
	if( iSlot == 1 && get_pdata_bool(id, m_bHasShield) ) 
	{ 
		RemoveUserShield( id ) 	
		if( 2 <= ExecuteHamB(Ham_Item_ItemSlot, iActiveItem) <= 4 ) 
		{ 
			ExecuteHamB(Ham_Item_Deploy, iActiveItem) 
		} 
		return 1 
	} 
	
	new iItem, iWeapons = pev(id, pev_weapons) 
	while( ( iItem = get_pdata_cbase(id, m_rgpPlayerItems_CBasePlayer[iSlot]) ) > 0 ) 
	{ 
		if( iItem == iActiveItem ) 
		{ 
			ExecuteHamB(Ham_Weapon_RetireWeapon, iItem) // only to call GetNextBestWeapon so player still have a weapon in hands. 
		} 
		iWeapons &= ~get_pdata_int(iItem, m_iId, XO_CBASEPLAYERITEM) 
		ExecuteHamB(Ham_RemovePlayerItem, id, iItem) 
		ExecuteHamB(Ham_Item_Kill, iItem) 
	} 
	set_pev(id, pev_weapons, iWeapons) 
	
	if( iSlot == 1 ) 
	{ 
		set_pdata_int(id, m_fHasPrimary, 0) 
	} 
	else if( iSlot == 4 ) 
	{ 
		set_pdata_int(id, m_rgAmmo_CBasePlayer[ammo_flashbang], 0) 
		set_pdata_int(id, m_rgAmmo_CBasePlayer[ammo_hegrenade], 0) 
		set_pdata_int(id, m_rgAmmo_CBasePlayer[ammo_smokegrenade], 0) 
	} 
	return 1 
} 

RemoveUserShield( id ) 
{ 
	if ( get_pdata_bool(id, m_bHasShield) ) 
	{ 
		set_pdata_bool(id, m_bHasShield, false) 
		set_pdata_int(id, m_fHasPrimary, 0) 
		set_pdata_bool(id, m_bUsesShield, false) 
		set_pev(id, pev_gamestate, 1) 
		new iHideHUD = get_pdata_int(id, m_iHideHUD) 
		if( iHideHUD & HUD_HIDE_CROSS ) 
		{ 
			set_pdata_int(id, m_iHideHUD, iHideHUD & ~HUD_HIDE_CROSS) 
		} 
		return 1 
	} 
	return 0 
}  

GetWeaponFromSlot( iPlayer, iSlot )
{
	if( !( 1 <= iSlot <= 5 ) )
		return -1;
	
	static const m_rgpPlayerItems_Slot0 = 367;
	
	return get_pdata_cbase( iPlayer, m_rgpPlayerItems_Slot0 + iSlot, 5 );
}