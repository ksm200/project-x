#include <amxmodx>
#include <amxmisc>
#include <reapi>

/*-----------Edit Safe----------------------------------------------------------------------*/
#define MODLOAD_TYPE		1	// 1 = UpdatePluginFile; 2 = UpdateLocalInfo
#define MULTIMOD_DIR		"multimod"

#define MAXMODS 			20
#define MAXADS				10

#define SELECTMENU 			8	// Maximum 8 options are possible at a time in a menu
#define MAXADMCUSTMAP		8	// Value should be equal or below SELECTMENU

#define MODNAME				32		
#define MAPNAME				32		
#define MODTAG				10

#define MAX_PLAYER_CNT		20
#define MAX_PLAYERNOMCNT	2	// Maximum number of map nominated by a player
/*------------End Safe-----------------------------------------------------------------------*/


#define PLUGIN 				"Multimod Manager"
#define VERSION 			"5.99"
#define AUTHOR 				"zero"

#define RELOAD_FEATURE		// For lazy moderators :3 ... you can change map to reload the mod

#define AMX_CURRENTMOD		"amx_multimod"
#define AMX_LASTMOD			"amx_lastmod"
#define AMX_LASTMAP			"amx_lastmap"
#define AMX_DEFPLUGINS		"amxx_plugins"

#pragma semicolon			1

#define SetBit(%1,%2)      	(%1 |= %2)
#define ClearBit(%1,%2)    	(%1 &= ~%2)
#define CheckBit(%1,%2)    	(%1 & %2)

#define VOTE_IN_PROGRESS	1
#define VOTE_FORCED			2
#define VOTE_IS_RUNOFF		4
#define VOTE_HAS_EXPIRED	8

#define VOTE_MOD			1
#define VOTE_MAP			2

#define TASKID_VOTE			892313
#define TASKID_REMINDER		237519
#define TASKID_ADS			439186

#define PLGNAME				64
#define PATHSTR				128
#define DATASTR				128
#define ADSLEN				190

enum nomTag
{
	g_nomvote = 0,
	g_nomid
};


new AMX_BANCONFDIR[PATHSTR];
new AMX_MODPLUGINS[PATHSTR];

new const g_Type [][] = 		{ "None", "Mod", "Map" };

new bool:g_rockedVote[MAX_PLAYER_CNT + 1];
new bool: g_rocked;
new g_rockedVoteCnt;
new Float:g_rtvWait;
new bool: g_wasLastRound = false, bool: g_handleMapChange = true, bool: g_endofmapvote; 
new Float: g_originalTimelimit;
new bool: g_pauseMapEndVoteTask = false, g_pauseMapEndManagerTask = false;

// Vote Variables
new g_votecnt[9];
new g_voteNames[9][MODNAME];
new g_runoffChoice[2];
new g_choiceCnt;
new g_voteDuration;
new g_votesCast;
new bool:g_playervotedid[MAX_PLAYER_CNT + 1];
new g_playerchoiceid[MAX_PLAYER_CNT + 1];

// Vote Status
new g_voteStatus;
new g_voteType;
new bool: g_refreshVoteStatus = true;

// Mod Variables
new g_modnames[MAXMODS][MODNAME];
new g_bannedLastMods[MAXMODS], g_totalBannedMods;
new g_bannedLastMaps[MAXMODS][MAXMODS][MAPNAME], g_totalBannedMaps[MAXMODS];
new g_mapHistory[MAXMODS][MAXMODS][MAPNAME], g_mapHistoryCount[MAXMODS];
new g_tag[MAXMODS][MODTAG];
new g_nominate[MAXMODS][nomTag];
new g_modcount;
new g_nextmodid; 
new g_currentmodid = -1;
//new g_lastmod[MODNAME];
new g_lastmodid = -1;
new bool: g_nextmodselected = false;

// Block Mod Variables
new g_blockedmod[MAXMODS];
new g_totalblocked;

// Map Variables
new Array: g_mapnames[MAXMODS];
new g_lastmap[MAPNAME];
new g_currentmap[MAPNAME];
new bool: g_nextmapselected = false;
new g_customVoteMapAdminID;

// Custom Map Variables
new g_playerVoteMapSel[MAX_PLAYER_CNT + 1][MAXADMCUSTMAP], g_playerVoteModMapSel[MAX_PLAYER_CNT + 1], g_playerVoteMapCnt[MAX_PLAYER_CNT + 1];

// Cvar Variable
new Array: g_cfglist;

// AD Variable
new g_ads[MAXADS][ADSLEN], g_totalads, g_currentad = 0;

// Mod Nomination
new g_playerlastnominated[MAX_PLAYER_CNT + 1], g_playernominatedid[MAX_PLAYER_CNT + 1], bool:g_playernominated[MAX_PLAYER_CNT + 1];

// Map Nomination
new g_playernominatedmapid[MAX_PLAYER_CNT + 1][MAX_PLAYERNOMCNT], g_playernominatedmapcnt[MAX_PLAYER_CNT + 1];

// Menu Cache
new const g_VoteMenuChoose[] = "mm_VoteMenuChoose";
//new g_menuChoose;

// Cvars 
new cvar_rtvWait, cvar_rtvRatio, cvar_rtv_enable, cvar_voteDuration, cvar_runoffDuration, cvar_runoffEnabled;
new cvar_endOfMapVote, cvar_endOnRound, cvar_rtvminplayers;
new cvar_nominate_enable, cvar_voteShowStatus;
new cvar_banLastmod, cvar_banLastmap,cvar_changehostname, cvar_playSounds;
new cvar_canAdminCancelRTV, cvar_pExtendMax, cvar_pExtendStep, cvar_nomModAfter, cvar_nomMapAfter, cvar_delayVote;
new cvar_prefix;

new g_totalcvars, srv_empty;
new g_chatPrefix[32];

enum Commands
{
	say,
	say_slash,
	sayteam,
	sayteam_slash,
};

new SayClientCmds[][30] = {
	
	"rtv",
	"vote_rock",
	"nmod",
	"cmdNextmod",
	"nmap",
	"cmdNextmap",
	"lmap",
	"cmdLastmap",
	"lmod",
	"cmdLastmod",
	"cmod",
	"cmdCurrentmod",
	"cmap",
	"cmdCurrentmap",
	"nom",
	"plrNominate",
	"cnom",
	"plrCancelNom"
};
	
new const say_commands[Commands][] = {
	"say %s",
	"say /%s",
	"say_team %s",
	"say_team /%s"
};

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	register_event("HLTV", "event_round_start", "a", "1=0", "2=0");
	register_event("TextMsg", "event_game_commencing", "a", "2=#Game_Commencing", "2=#Game_will_restart_in");
	register_event("30", "event_intermission", "a");
	
	register_clcmd("amx_mapmenu", "cmdMapsMenu", ADMIN_MAP, "- displays changelevel menu");
	register_clcmd("amx_votemapmenu", "cmdCustomMap", ADMIN_MAP, "- displays vote changelevel menu");
	register_clcmd("amx_modmenu", "cmdModsMenu", ADMIN_MAP, "- displays Mod menu");
	register_concmd("mm_cancelvote", "cmdCancelVote", ADMIN_MAP, "- cancels the votemod or votemap");
	register_concmd("mm_startvote", "cmdConStrVote", ADMIN_MAP, "- [Usage]: mm_startvote {mod/map} <Dontchange=0>");
	register_concmd("mm_nextmod", "cmdConNextMod", ADMIN_MAP, "- [Usage]: mm_nextmod <#modid>");
	
	for(new i = 0; i < sizeof(SayClientCmds); i += 2)
		rd_register_saycmd(SayClientCmds[i], SayClientCmds[i+1], 0);

	// Inicializa o histórico de mapas
	for(new i = 0; i < MAXMODS; i++)
	{
		g_mapHistoryCount[i] = 0;
		g_totalBannedMaps[i] = 0;
	}
	
	register_cvar("amx_nextmap", "", FCVAR_SERVER|FCVAR_EXTDLL|FCVAR_SPONLY);
	register_cvar("mm_debug", "0");
	srv_empty = register_cvar("srv_empty", "", FCVAR_SERVER|FCVAR_EXTDLL|FCVAR_SPONLY);
	
	cvar_voteDuration 		= register_cvar("mm_vote_duration", "25");
	cvar_runoffDuration 	= register_cvar("mm_runoffvote_duration", "25");
	cvar_runoffEnabled 		= register_cvar("mm_runoffvote_enable", "1");
	cvar_voteShowStatus		= register_cvar("mm_voteShowStatus", "0");
	cvar_rtv_enable 		= register_cvar("mm_rtv_enable", "1");
	cvar_rtvWait 			= register_cvar("mm_rtv_wait", "10");
	cvar_rtvRatio 			= register_cvar("mm_rtv_ratio", "0.60");
	cvar_endOfMapVote 		= register_cvar("mm_endonvote", "1");
	cvar_endOnRound 		= register_cvar("mm_endonchange", "1");
	cvar_rtvminplayers 		= register_cvar("mm_rtvmin_players", "1");
	cvar_nominate_enable 	= register_cvar("mm_nom_enable", "2");
	cvar_banLastmod			= register_cvar("mm_banlastmod", "1");
	cvar_banLastmap			= register_cvar("mm_banlastmap", "1");
	cvar_canAdminCancelRTV	= register_cvar("mm_canAdminCancelRtv", "0");
	cvar_pExtendMax			= register_cvar("mm_extendmap_max", "120");
	cvar_pExtendStep		= register_cvar("mm_extendmap_step", "15");
	cvar_changehostname		= register_cvar("mm_chgHostname", "Multimod Server (%modname%)");
	cvar_nomModAfter		= register_cvar("mm_nomModDelay", "30");				// in seconds
	cvar_nomMapAfter		= register_cvar("mm_nomMapDelay", "5");					// in seconds
	cvar_delayVote			= register_cvar("mm_delayVote", "30");					// in seconds
	cvar_playSounds			= register_cvar("mm_playSounds", "1");

	/* Reload server to load new prefix after change.*/
	cvar_prefix				= register_cvar("mm_prefix", "[^4Multimod^1]");
	/* ----------------------------------------------*/

	//g_menuChoose = register_menuid(g_VoteMenuChoose);
	register_menucmd(register_menuid(g_VoteMenuChoose), MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_9, "vote_handleChoice");
}

rd_register_saycmd(const saycommand[], const function[], flags) 
{
	new temp[64];
	for (new Commands:i = say; i < Commands; i++)
	{
		formatex(temp, charsmax(temp), say_commands[i], saycommand);
		register_clcmd(temp, function, flags);
	}
}

public cmdConNextMod(id, level, cid)
{
	if(!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED;
		
	if(read_argc() == 1)
	{
		console_print(id, "---- Mod List ----");
		for(new i = 0; i < g_modcount; i++) console_print(id, "%d. %s%s", i + 1, g_modnames[i], i == g_currentmodid ? " (currentmod)" : "");
		
		new szData[20];
		read_argv(0, szData, charsmax(szData));
		console_print(id, "[Usage]: %s <#modid>", szData);
	}else
	{
		new args[3];
		read_argv(1, args, charsmax(args));
		
		if(isdigit(args[0]))
		{
			new modID = str_to_num(args) - 1;
			new nextMap[MAPNAME];
			
			if(0 <= modID < g_modcount && modID != g_currentmodid)
			{
				if(!g_nextmodselected)
				{
					set_nextmod(modID);
					ArrayGetString(g_mapnames[g_nextmodid], 0, nextMap, charsmax(nextMap));
					set_nextmap(nextMap);
					set_task(2.0, "change_map");
				}
				else	console_print(id, "Nextmod already decided!!");
			} else	console_print(id, "Invalid Modid!!");
		} else	console_print(id, "Invalid Modid!!");
	}
	return PLUGIN_HANDLED;
}

public plrNominate(id)
{
	nominate_mainMenu(id, 1);
	return PLUGIN_HANDLED;
}
public plrCancelNom(id)
{
	nominate_mainMenu(id, 2);
	return PLUGIN_HANDLED;
}

public vote_setupEnd()
{
	g_originalTimelimit = get_cvar_float("mp_timelimit");
	
	if(g_originalTimelimit)
	{
		log("vote_setupEnd() OriginalTimelimit: %f", g_originalTimelimit);
		set_task(15.0, "vote_manageEnd", _, _, _, "b");
	}
}

public vote_manageEnd()
{
	new secondsLeft = get_timeleft();
	//log("Seconds Left: %i||Map VoteTAsk: %d||Map MngTask: %d", secondsLeft, g_pauseMapEndVoteTask, g_pauseMapEndManagerTask);
	
	if(secondsLeft < 225 && secondsLeft > 150 && !g_pauseMapEndVoteTask && get_pcvar_num(cvar_endOfMapVote) && !get_pcvar_num(srv_empty))
	{
		g_voteType = g_nextmodselected ? VOTE_MAP : VOTE_MOD;
		plr_print_color(0, "Time is going to expire soon, a %svote will happen.", g_Type[g_voteType]);
		
		SetBit(g_voteStatus, VOTE_IN_PROGRESS); 
		g_endofmapvote = true;
		
		set_task(1.0, "start_votedirector");
	}
	
	if(secondsLeft < 20 && !g_pauseMapEndManagerTask)
	{
		new nextMap[MAPNAME];
		
		if(!g_nextmapselected)
		{
			if(g_nextmodselected)
			{
				ArrayGetString(g_mapnames[g_nextmodid], 0, nextMap, charsmax(nextMap));
			}
			else
			{
				map_getNext(g_mapnames[g_currentmodid], g_currentmap, nextMap);
			}
			set_nextmap(nextMap);
		}
		
		get_cvar_string("amx_nextmap", nextMap, charsmax(nextMap));
		plr_print_color(0, "The nextmap will be '^4%s^1'.", nextMap);
		map_manageEnd();
	}
}

map_getNext(Array:mapArray, currentMap[], nextMap[32])
{
	new thisMap[32], mapCnt = ArraySize(mapArray), nextmapIdx = 0;
	for (new mapIdx = 0; mapIdx < mapCnt; mapIdx++)
	{
		ArrayGetString(mapArray, mapIdx, thisMap, sizeof(thisMap)-1);
		if (equal(currentMap, thisMap))
		{
			nextmapIdx = (mapIdx == mapCnt - 1) ? 0 : mapIdx + 1;
			//returnVal = nextmapIdx;
			break;
		}
	}
	ArrayGetString(mapArray, nextmapIdx, nextMap, sizeof(nextMap)-1);
}

public cmdConStrVote(id, level, cid)
{
	if(!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED;
	
	if(read_argc() <= 3)
	{
		new args1[32], args2[10];
		
		read_argv(1, args1, charsmax(args1));
		read_argv(2, args2, charsmax(args2));
		
		if(str_to_num(args2)) g_handleMapChange = false;
		
		if(equal(args1, "mod"))
		{
			SetBit(g_voteStatus, VOTE_FORCED);
			start_vote(id, VOTE_MOD, false);
		}else if(equal(args1, "map"))
		{
			SetBit(g_voteStatus, VOTE_FORCED);
			start_vote(id, VOTE_MAP, false);
		}
		else
		{
			g_handleMapChange = true;
			if(id)
				client_print(id, print_console, "[Usage]: mm_startvote {mod/map} <Dontchange=0>");
			else
				server_print("[Usage]: mm_startvote {mod/map} <Dontchange=0>");
		}
	}
	return PLUGIN_HANDLED;
}

public cmdCurrentmod(id)
{
	plr_print_color(id, "Current Mod - ^4%s^1", g_modnames[g_currentmodid]);
	return PLUGIN_HANDLED;
}

public cmdCurrentmap(id)
{
	plr_print_color(id, "Current Map - ^4%s^1", g_currentmap);
	return PLUGIN_HANDLED;
}

public cmdLastmod(id)
{
	if(g_lastmodid > -1)
	{
		plr_print_color(id, "Last Mod - ^4%s^1.", g_modnames[g_lastmodid]);
	}else{
		plr_print_color(id, "This is the first mod.");
	}
	
	return PLUGIN_HANDLED;
}

public cmdLastmap(id)
{
	if(g_lastmap[0])
	{
		plr_print_color(id, "Last Map - ^4%s^1.", g_lastmap);
	}else{
		plr_print_color(id, "This is the first map.");
	}
	return PLUGIN_HANDLED;
}

public cmdNextmod(id)
{
	if(g_nextmodselected)
		plr_print_color(id, "The nextmod will be ^4%s^1.", g_modnames[g_nextmodid]);
	else
		plr_print_color(id, "Nextmod not yet decided.");
	
	return PLUGIN_HANDLED;
}
public cmdNextmap(id)
{
	new temp[MAPNAME];
	if(g_nextmapselected)
	{
		get_cvar_string("amx_nextmap", temp, charsmax(temp));
		plr_print_color(id, "The nextmap will be ^4%s^1.", temp);
	}
	else
	{
		plr_print_color(id, "Nextmap not yet decided.");
	}
	return PLUGIN_HANDLED;
}

public client_connect(id)
{
	set_pcvar_num(srv_empty, 0);
}

public client_putinserver(id)
{
	g_playerlastnominated[id] = 0;
	g_playernominated[id] = false;
	g_playernominatedid[id] = g_currentmodid;
	
	vote_unrock(id);
}

public client_disconnected(id)
{
	if(g_playervotedid[id])
	{
		g_playervotedid[id] = false;
		g_votesCast--;
		g_votecnt[g_playerchoiceid[id]]--;
	}
	vote_unrock(id);
	
	if(g_playernominated[id])
	{
		reset_plrnominations(id);
	}
	
	if(!(get_realplayersnum() - 1)) set_pcvar_num(srv_empty, 1);
}

public event_round_start()
{
	if(g_wasLastRound)
	{
		map_manageEnd();
	}
}
public event_game_commencing()
{
	map_restoreOriginalTimeLimit();
}

map_restoreOriginalTimeLimit()
{
	if (g_originalTimelimit != -1)
	{	
		log("map_restoreOriginalTimeLimit() OrginalTimeLimi: %f", g_originalTimelimit);
		server_cmd("mp_timelimit %f", g_originalTimelimit);
		server_exec();
	}
}

public event_intermission()
{
	g_pauseMapEndManagerTask = true;
	set_task(floatmax(get_cvar_float("mp_chattime"), 2.0), "change_map");

	return PLUGIN_CONTINUE;
}

public cmdCancelVote(id, level, cid)
{
	if(!cmd_access(id, level, cid, 1) || g_nextmapselected)
		return PLUGIN_HANDLED;
		
	if(task_exists(TASKID_VOTE))
	{
		if(g_rocked && !get_pcvar_num(cvar_canAdminCancelRTV))
		{
			client_print(id, print_console, "You cannot cancel Vote%s rocked by RTV", g_Type[g_voteType]);
			return PLUGIN_HANDLED;
		}
		
		new szName[32];
		get_user_name(id, szName, charsmax(szName));
				
		plr_print_color(0, "Admin (^4%s^1) has cancelled the current vote%s", szName, g_Type[g_voteType]);
		log("cmdCancelVote() Vote%s cancelled by %s", g_Type[g_voteType], szName);
		
		remove_task(TASKID_VOTE);
		
		if(g_voteType == VOTE_MAP && g_nextmodselected)
		{
			g_nextmodselected = false;
			g_nextmodid = 0;
		}
		
		g_voteType = 0;
		g_customVoteMapAdminID = 0;
		g_voteStatus = 0;
		
		reset_nominations();
		reset_plrnominations(0);
		
		if(g_endofmapvote)
		{
			log("cmdCancelVote() End of mapvote cancelled and timelimit extended.");
			set_cvar_float("mp_timelimit", get_cvar_float("mp_timelimit") + get_pcvar_float(cvar_pExtendStep));
			server_exec();
		}
					
		if(g_rtvWait)
		{
			g_rtvWait = get_cvar_float("mp_timelimit") + g_rtvWait;
		}
		
		g_pauseMapEndManagerTask = false;
		g_pauseMapEndVoteTask = false;
		g_handleMapChange = true;
		
		new players[32], plrNum;
		get_players(players, plrNum, "ch");
		for( new i; i < plrNum; i++)
			show_menu(players[i], 0, "^n", 1);
	}
	return PLUGIN_HANDLED;
}

public cmdModsMenu(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED;

	mmmenu(id);

	return PLUGIN_HANDLED;
}
public cmdMapsMenu(id, level, cid)
{
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED;

	setmapmenu(id);

	return PLUGIN_HANDLED;
}

public mmmenu( id )
{
	new menu = menu_create("\yMultiMod Menu", "mm_handler");
	new szData[MODNAME + 10];
	
	menu_additem(menu, "Choose NextMod");
	menu_additem(menu, "Choose NextMap");
	menu_additem(menu, "Block Mods");
	
	if(g_nextmodselected)	
	{
		formatex(szData, charsmax(szData), "Cancel Mod \r(%s)", g_modnames[g_nextmodid]);
		menu_additem(menu, szData);
	}else
	{
		menu_additem(menu, "Cancel Mod");
	}
	menu_additem(menu, "VoteMod");
	menu_additem(menu, "VoteMap");	

#if defined RELOAD_FEATURE
	menu_additem(menu, "Reload");
#endif
	
	menu_display(id, menu, 0);
	return PLUGIN_HANDLED;
}

public mm_handler( id, menu, item )
{
	if(item == MENU_EXIT)
	{
		menu_destroy(id);
		return PLUGIN_HANDLED;
	}

	new command[6], access, callback;

	menu_item_getinfo(menu, item, access, command, sizeof command - 1, _, _, callback);
	
	switch(item)
	{
		case 0:	setmodmenu(id, 0);
		case 1:	client_cmd(id, "amx_mapmenu");
		case 2:	blockmenu(id, 0);
		case 3:	cancelmod(id);
		case 4:	start_vote(id, VOTE_MOD, false);
		case 5:	start_vote(id, VOTE_MAP, false);
		
#if defined RELOAD_FEATURE
		case 6:
		{
			new szName[32];
			get_user_name(id, szName, charsmax(szName));
			
			plr_print_color(0, "Admin (^4%s^1) has reloaded the mod.", szName);
			log("%s reloaded the %s (%s)", szName, g_modnames[g_currentmodid], g_currentmap);
			server_cmd("restart");
		}
#endif
	}
	
	return PLUGIN_HANDLED;
}

public start_vote(id, vote_type, bool: custom_map)
{
	if((vote_type == VOTE_MOD && g_nextmodselected) || g_nextmapselected || CheckBit(g_voteStatus, VOTE_IN_PROGRESS))
	{
		if(id)
			plr_print_color(id, "Vote%s is unavailable during voting process or Mod/Map is already decided.", g_Type[vote_type]);
		else
			server_print("Vote%s is unavailable during voting process or Mod/Map is already decided.", g_Type[vote_type]);
		return PLUGIN_HANDLED;
	}
	
	g_voteType = vote_type;
	SetBit(g_voteStatus, VOTE_IN_PROGRESS);
	
	if(custom_map) g_customVoteMapAdminID = id;
	else if(vote_type == VOTE_MAP) reset_plrnominationsmap(g_nextmodselected ? g_nextmodid : g_currentmodid);
	
	set_task(3.0, "start_votedirector", custom_map ? true : false);
	
	new szName[32];
	get_user_name(id, szName, charsmax(szName));
	plr_print_color(id, "Admin (^4%s^1) has started Vote%s.", szName, g_Type[vote_type]);
		
	return PLUGIN_HANDLED;
}

public cancelmod(id)
{	
	if(g_nextmapselected || g_voteType == VOTE_MAP || CheckBit(g_voteStatus, VOTE_IN_PROGRESS))
	{
		return PLUGIN_HANDLED;
	}
	
	if(g_nextmodselected)
	{
		new szName[32];
		get_user_name(id, szName, charsmax(szName));
		plr_print_color(0, "Admin (^4%s^1) has cancelled the NextMod ^3%s", szName, g_modnames[g_nextmodid]);
		log("%s cancelled %s", szName, g_modnames[g_nextmodid]);
		
		g_nextmodselected = false;
		g_nextmodid = 0;
		reset_plrnominationsmap(g_currentmodid);
		////log_amx("Next Mod - Reset");
	}
	
	return PLUGIN_HANDLED;
}

public blockmenu( id, pos )
{
	new menu = MakeModMenu(id, false, "\yBlock Mods", "block_handler");
	menu_display(id, menu, pos);
	
	return PLUGIN_HANDLED;
}

public block_handler( id, menu, item )
{
	if( item == MENU_EXIT )
	{
		//mmmenu(id);
		menu_destroy(menu);
		client_cmd(id, "amx_modmenu");
		return PLUGIN_HANDLED;
	}
	
	new szData[6], access, callback, page, menu1, menu2;

	menu_item_getinfo(menu, item, access, szData, charsmax(szData), _, _, callback);
	player_menu_info(id, menu1, menu2, page);
	menu_destroy(menu);
	
	new modID = str_to_num(szData);
	
	new sAdminName[32];
	get_user_name(id, sAdminName, charsmax(sAdminName));
	
	if(g_blockedmod[modID])
	{
		plr_print_color(0, "Admin (^4%s^1) Un-Blocked ^3%s.", sAdminName, g_modnames[modID]);
		g_blockedmod[modID] = false;
		g_totalblocked--;
	}
	else
	{
		plr_print_color(0, "Admin (^4%s^1) Blocked ^3%s.", sAdminName, g_modnames[modID]);
		g_blockedmod[modID] = true;
		g_totalblocked++;
	}
	block_write_file();
	blockmenu( id, page );

	return PLUGIN_HANDLED;
}

public block_write_file()
{
	new filePtr2;
	
	filePtr2 = fopen(AMX_BANCONFDIR, "wt");
	
	if(filePtr2)
	{
		for( new i = 0; i < g_modcount; i++ )
		{
			if( g_blockedmod[i] )
			{
				fprintf(filePtr2, "%s^n", g_modnames[i]);
			}
		}
		
		fclose(filePtr2);
	}
}

MakeModMenu(id, bool: custom, const szMenu[], const szHandler[])
{
	new menu = menu_create(szMenu, szHandler);
	new modline[MODNAME + 20], charCnt, sel_index[7];
	
	// Atualiza a lista de mods banidos
	update_banned_mods();
	
	for(new i = 0 ; i < g_modcount ; i++) 
	{
		if(i == g_currentmodid || (custom && (g_blockedmod[i] || is_mod_banned(i))))
			continue;
			
		charCnt = formatex(modline, charsmax(modline), "%s", g_modnames[i]);
		
		if(custom)
		{
			charCnt += formatex(modline[charCnt], charsmax(modline)-charCnt, " \r[%d]", g_nominate[i][g_nomvote]);
			if(g_playernominated[id] && g_playernominatedid[id] == i)
			{
				formatex(modline[charCnt], charsmax(modline)-charCnt, " \r(Nominated)");
			}
		}
		else
		{
			if(g_blockedmod[i])
			{
				formatex(modline[charCnt], charsmax(modline)-charCnt, " \r(Blocked)");
			}else if(g_nextmodselected && i == g_nextmodid)
			{
				formatex(modline[charCnt], charsmax(modline)-charCnt, " \r(Nextmod)");
			}
		}
		
		num_to_str(i, sel_index, charsmax(sel_index));
		menu_additem(menu, modline, sel_index, 0);
	}
	
	return menu;
}

public cmdNominate(id)
{
	if(!get_pcvar_num(cvar_nominate_enable))
	{
		plr_print_color(id, "Mod Nomination disabled.");
		return PLUGIN_HANDLED;
	}
	
	new menu = MakeModMenu(id, true, "\yNominate Mod", "nominate_handler");
	menu_display(id, menu, 0);
	
	return PLUGIN_HANDLED;
}

public nominate_handler(id, menu, item)
{
	if( item == MENU_EXIT )
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	if(CheckBit(g_voteStatus, VOTE_IN_PROGRESS) && g_voteType == VOTE_MAP)
	{
		plr_print_color(id, "VoteMod decided; Nominate Maps.");
		mapNominateMenu(id, 0);
		return PLUGIN_HANDLED;
	}
	
	new info[7], access, callback;

	menu_item_getinfo(menu, item, access, info, charsmax(info), _, _, callback);
	menu_destroy(menu);
	new modID = str_to_num(info);
	
	new secondsLeft = get_pcvar_num(cvar_nomModAfter) - (get_systime() - g_playerlastnominated[id]);
	if( secondsLeft <= 0 )
	{
		if(g_playernominated[id])
		{
			plr_print_color(id, "Cancel you previous nomination '^4%s^1' by typing '^4cnom^1' in chat.", g_modnames[g_playernominatedid[id]]);	
		}
		else
		{
			new szName[32];
			get_user_name(id, szName, charsmax(szName));
			
			plr_print_color(0, "(^3%s^1) nominated ^4%s", szName, g_modnames[modID]);
			
			g_playernominated[id] = true;
			g_playernominatedid[id] = modID;
			g_playerlastnominated[id] = get_systime();
			
			g_nominate[modID][g_nomvote]++;
			
			g_playernominatedmapcnt[id] = 0;
			mapNominateMenu(id, 0);
			log("(nominate_handler) PlrNominated: %s || ModNomCnt: %d || ModNomID: %d", g_modnames[g_nominate[modID][g_nomid]], g_nominate[modID][g_nomvote], g_nominate[modID][g_nomid]);
		}
	}
	else
	{
		plr_print_color(id, "You have nominated just few seconds ago. Wait (^4%i ^1seconds) more", secondsLeft);
	}
	
	return PLUGIN_HANDLED;
}

public cmdCancelnomMod(id)
{
	if(!get_pcvar_num(cvar_nominate_enable))
	{
		plr_print_color(id, "Mod Nomination disabled.");
		return PLUGIN_HANDLED;
	}
	
	if(CheckBit(g_voteStatus, VOTE_IN_PROGRESS))
	{
		plr_print_color(id, "You can't cancel your nominations while a vote is in progress");
		return PLUGIN_HANDLED;
	}
	
	if(!g_playernominated[id])
	{
		plr_print_color(id, "Nominate mod by typing '^4nom^1' in chat.");
		return PLUGIN_HANDLED;
	}
	
	reset_plrnominations(id);
				
	plr_print_color(id, "You have successfully cancelled your previous mod nomination.");
	
	return PLUGIN_HANDLED;
}

public cmdCancelnomMap(id)
{
	if(get_pcvar_num(cvar_nominate_enable) < 2)
	{
		plr_print_color(id, "Map Nomination disabled.");
		return PLUGIN_HANDLED;
	}
	
	if(g_playernominatedmapcnt[id] <= 0)
	{
		plr_print_color(id, "Nominate map by typing '^4nom^1' in chat.");
		return PLUGIN_HANDLED;
	}
	
	plr_print_color(id, "You have successfully cancelled your previous map nomination(s).");
	
	g_playernominatedmapcnt[id] = 0;
	return PLUGIN_HANDLED;
}

public setmodmenu(id, pos)
{	
	new menu = MakeModMenu(id, false, "\yChoose NextMod", "modmenu_handler");
	menu_display(id, menu, pos);
	
	return PLUGIN_HANDLED;
}

public modmenu_handler( id, menu, item )
{
	if(item == MENU_EXIT)
	{
		menu_destroy(menu);
		client_cmd(id, "amx_modmenu");
		return PLUGIN_HANDLED;
	}
	
	if(g_nextmodselected || g_nextmapselected || CheckBit(g_voteStatus, VOTE_IN_PROGRESS))
	{
		plr_print_color(id, "Mod/Map is already selected or Vote is in progress.");
		return PLUGIN_HANDLED;
	}
	
	new command[7], iaccess, callback, page, menu1, menu2;

	menu_item_getinfo(menu, item, iaccess, command, charsmax(command), _, _, callback);
	player_menu_info(id, menu1, menu2, page);
	menu_destroy(menu);
	
	new mod_index = str_to_num(command);
	
	if(g_blockedmod[mod_index])
	{
		plr_print_color(id, "This Item is blocked, Unblock it first!!!");
		
		setmodmenu(id, page);
		return PLUGIN_HANDLED;
	}
	
	new sAdminName[32];
	get_user_name(id, sAdminName, charsmax(sAdminName));
	
	plr_print_color(0, "Admin (^4%s^1) has decided the NextMod - ^3%s", sAdminName, g_modnames[mod_index]);
	log("%s selected the nextmod %s", sAdminName, g_modnames[mod_index]);
	reset_plrnominationsmap(mod_index);
	set_nextmod(mod_index);
	
	//setmodmenu(id, page);
	client_cmd(id, "amx_mapmenu");
	return PLUGIN_HANDLED;
}

public plugin_cfg()
{
	formatex(AMX_MODPLUGINS[get_configsdir(AMX_MODPLUGINS, charsmax(AMX_MODPLUGINS))], charsmax(AMX_MODPLUGINS), "/plugins-multimod.ini");

	if( file_exists(AMX_MODPLUGINS) )
		delete_file(AMX_MODPLUGINS);
		
	initSetup();
	
	server_cmd("amx_pausecfg add ^"MultiMod Manager^"");
	//set_task(10.0, "vote_setupEnd");
}

public plugin_end()
{
	map_restoreOriginalTimeLimit();
	
	if(g_nextmodselected)
	{
		set_localinfo(AMX_CURRENTMOD, g_modnames[g_nextmodid]);
		set_localinfo(AMX_LASTMOD, g_modnames[g_currentmodid]);
		@UpdatePlugins(g_nextmodid);
	}
	else if(g_currentmodid != -1)
	{
		@UpdatePlugins(g_currentmodid);
	}
	
	new mapNext[MAPNAME];
	get_cvar_string("amx_nextmap", mapNext, charsmax(mapNext));
	
	if(!equal(mapNext, g_currentmap))
		set_localinfo(AMX_LASTMAP, g_currentmap);
}

public CfgExec()
{
	new g_fileconf[PATHSTR];
	formatex(g_fileconf[get_configsdir(g_fileconf, charsmax(g_fileconf))], charsmax(g_fileconf), "/%s/multimod.cfg", MULTIMOD_DIR);
	server_cmd("exec %s", g_fileconf);
	server_exec();
	
	g_totalcvars = ArraySize(g_cfglist) ;
	for(new i = 0; i < g_totalcvars; i++)
	{
		server_cmd("%a", ArrayGetStringHandle(g_cfglist, i));
	}
	ArrayDestroy(g_cfglist);
	log_amx("Multimod-Config executed: %s", g_fileconf);
	
	new szHostname[64];
	get_pcvar_string(cvar_changehostname, szHostname, charsmax(szHostname));
	if(szHostname[0])
	{
		replace_all(szHostname, charsmax(szHostname), "%modname%", g_modnames[g_currentmodid]);
		server_cmd("hostname ^"%s^"", szHostname);
	}
		
	g_rtvWait = get_pcvar_float(cvar_rtvWait);
	get_pcvar_string(cvar_prefix, g_chatPrefix, charsmax(g_chatPrefix));
	replace_all(g_chatPrefix, charsmax(g_chatPrefix), "!g", "^4");
	replace_all(g_chatPrefix, charsmax(g_chatPrefix), "!t", "^3");
	replace_all(g_chatPrefix, charsmax(g_chatPrefix), "!n", "^1");
}

public firstRestart()
{
	log("firstRestart() First Start");
	
	set_localinfo(AMX_CURRENTMOD, g_modnames[0]);
	
	new szData[MAPNAME];
	ArrayGetString(g_mapnames[0], 0, szData, charsmax(szData));
	set_cvar_string("amx_nextmap", szData);
	
	@UpdatePlugins(0);	
	set_task(2.0, "change_map");
}

initSetup()
{
	new currentmod[MODNAME], lastmod[MODNAME];
		
	get_localinfo(AMX_CURRENTMOD, currentmod, charsmax(currentmod));
	get_localinfo(AMX_LASTMOD, lastmod, charsmax(lastmod));
	get_localinfo(AMX_LASTMAP, g_lastmap, charsmax(g_lastmap));
	get_mapname(g_currentmap, charsmax(g_currentmap));
	
	LoadMods(currentmod, lastmod);	
}


LoadMods(currentmod[], lastmod[])
{
	new filePath[PATHSTR], filePath2[PATHSTR], szData[MODNAME + MODTAG + 10], szModName[MODNAME], szTag[MODTAG];
	
	new configsDir[PATHSTR], pluginFile;
	formatex(configsDir[get_configsdir(configsDir, charsmax(configsDir))], charsmax(configsDir), "/%s", MULTIMOD_DIR);
	
	formatex(filePath, charsmax(filePath), "%s/multimod.ini", configsDir);
	formatex(AMX_BANCONFDIR, charsmax(AMX_BANCONFDIR), "%s/blocked.ini", configsDir);

	//server_print("File multimod.ini - %s", filePath);
	//server_print("AMX_BANDIR - %s", AMX_BANCONFDIR);
	
	new Trie: g_modblacklist = TrieCreate();
	new tsz;
	LoadBlocks(g_modblacklist);
	
	new filePtr = fopen(filePath, "rt");
	
	if(filePtr)
	{	
		g_modcount = 0;
		while(!feof(filePtr) && g_modcount < MAXMODS) 
		{
			fgets(filePtr, szData, charsmax(szData));
			trim(szData);
						
			if(szData[0] == '"')
			{
				parse(szData, szModName, charsmax(szModName), szTag, charsmax(szTag));
				formatex(filePath2, charsmax(filePath2), "%s/%s-maps.ini", configsDir, szTag);
				g_mapnames[g_modcount] = ArrayCreate(MAPNAME);
				
				if(LoadMaps(filePath2, g_modcount))
				{
					if(currentmod[0] && equal(szModName, currentmod))
					{
						g_currentmodid = g_modcount;
					} 
					
					if(equal(szModName, lastmod))
					{
						g_lastmodid = g_modcount;
					}
				
					copy(g_modnames[g_modcount], charsmax(g_modnames[]), szModName);
					copy(g_tag[g_modcount], charsmax(g_tag[]), szTag);
					//LoadPlugins(g_modcount, szTag);
								
					tsz = TrieKeyExists(g_modblacklist, szModName);
					g_blockedmod[g_modcount] = tsz;
					g_totalblocked += tsz;
					++g_modcount;
				}
				else
				{
					ArrayDestroy(g_mapnames[g_modcount]);
				}
				
				filePath2[0] = 0;
				formatex(filePath2, charsmax(filePath2), "%s/%s-plugins.ini", configsDir, szTag);
				
				if(!file_exists(filePath2))
				{
					pluginFile = fopen(filePath2, "wt+");
					if(pluginFile) fclose(pluginFile);
					else log_amx("File not created - <%s>", filePath2);
				}
			}
		}
		fclose(filePtr);
	}
	else
	{
		set_fail_state("%s does not exist", filePath);
	}
	
	TrieDestroy(g_modblacklist);
	
	if(g_modcount == 0)
	{
		log_amx("Zero mods Loaded!");
		set_fail_state("Zero mods Loaded.");
	}
	else if(g_currentmodid == -1)
	{
		log_amx("First Restart");
		server_print("First Restart");
		set_task(2.0, "firstRestart");
	}
	else
	{
		LoadModCfg(g_tag[g_currentmodid]);
		LoadAds(g_tag[g_currentmodid]);
		set_task(2.0, "CfgExec");
		set_task(6.0, "print_info");
		reset_nominations();
	
		set_task(10.0, "vote_setupEnd");
	}
	
	return 0;
}

LoadMaps(filePath[], modID)
{
	new szData[MAPNAME], count;
	
	new f = fopen(filePath, "rt");

	if(f)
	{
		while(!feof(f))
		{
			fgets(f, szData, charsmax(szData));
			trim(szData);

			if( !szData[0] || szData[0] == ';')
				continue;
				
			if( ValidMap(szData) )
			{
				ArrayPushString(g_mapnames[modID], szData);
				count++;
			}
		}
		fclose(f);
	}
	else
	{
		f = fopen(filePath, "wt+");
		if(f) fclose(f);
		else log_amx("File not created - <%s>", filePath);
	}
	return count;
}

LoadBlocks(&Trie: g_modblacklist)
{
	new szText[MODNAME], count = 0;
	
	new f = fopen(AMX_BANCONFDIR, "rt");
	
	if(f)
	{		
		while(!feof(f))
		{
			fgets(f, szText, charsmax(szText));
			trim(szText);
				
			if(!szText[0] || szText[0] == ';')
				continue;
				
			if(TrieSetCell(g_modblacklist, szText, 1))
				count++;
		}
		fclose(f);
	}
	return count;
}

LoadModCfg(sz_tag[])
{
	new f, filePath[PATHSTR], szData[DATASTR], szKey1[MODTAG], szKey2[MODTAG+4];
	new posStart;
	
	g_cfglist = ArrayCreate(128);
	
	formatex(filePath[get_configsdir(filePath, charsmax(filePath))], charsmax(filePath), "/%s/singlemodcfg.cfg", MULTIMOD_DIR);
	formatex(szKey2, charsmax(szKey2), "[%s]", sz_tag);
	copy(szKey1, charsmax(szKey1), "[all]");
	
	f = fopen(filePath, "rt");
	
	if(!f)
	{
		log_amx("Missing [%s]", filePath);
		return 0;
	}
	
	for(new i = 0; i < 2; i++)
	{
		if(KeyExists(f, szKey1, szKey2))
		{
			while(!feof(f))
			{
				posStart = ftell(f);
				
				fgets(f, szData, charsmax(szData));
				trim(szData);
					
				if(!szData[0] || szData[0] == '/' || szData[0] == ';')
					continue;
				
				if(szData[0] == '[') 
				{
					fseek(f, posStart, SEEK_SET);
					break;
				}
					
				ArrayPushString(g_cfglist, szData);
				//log_amx("<Mod Cfg> <%d> <%s>", i, szData);
			}
		}
	}
	fclose(f);
	
	return 0;
}

KeyExists(fileptr, key1[], key2[])
{
	new szData[MODTAG + 4];
	
	while(!feof(fileptr))
	{
		//keypos_start = ftell(fileptr);
		fgets(fileptr, szData, charsmax(szData));
		
		if(!szData[0] || szData[0] != '[')
			continue;
			
		trim(szData);
		
		if(equal(szData, key1) || equal(szData, key2))
			return true;
	}
	
	return false;
}

LoadAds(sz_tag[])
{
	g_totalads = 0;
	
	new f, filePath[PATHSTR], szData[ADSLEN], szKey1[MODTAG], szKey2[MODTAG+4];
	new posStart;
	
	formatex(filePath[get_configsdir(filePath, charsmax(filePath))], charsmax(filePath), "/%s/singlemodads.ini", MULTIMOD_DIR);
	formatex(szKey2, charsmax(szKey2), "[%s]", sz_tag);
	copy(szKey1, charsmax(szKey1), "[all]");
	
	f = fopen(filePath, "rt");
	
	if(!f)
	{
		//log_amx("Missing [%s]", filePath);
		return 0;
	}
	
	for(new i = 0; i < 2; i++)
	{
		if(KeyExists(f, szKey1, szKey2))
		{
			while(!feof(f) && g_totalads < MAXADS)
			{
				posStart = ftell(f);
				fgets(f, szData, charsmax(szData));
				trim(szData);
				
				if(!szData[0] || szData[0] == '/' || szData[0] == ';')
					continue;
				
				if(szData[0] == '[')
				{	
					fseek(f, posStart, SEEK_SET);
					break;
				}
				
				replace_colorargs(szData, charsmax(szData));
				if(containi(szData, "%") != -1)
				{	
					replace_conditions(szData, charsmax(szData));
				}
				copy(g_ads[g_totalads++], charsmax(g_ads[]), szData);
				//server_print("<Loop - %d> <%d> <%s>", i, g_totalads, szData);
			}
		}
	}
	fclose(f);
		
	//log_amx("<Ads Loaded> = <%d>", g_totalads);
	
	if(g_totalads)
	{
		set_task(random_float( 60.0, 80.0), "advertise");
	}
	return 0;
}

public advertise()
{	
	new players[32], count, id, szName[32];
	get_players(players, count, "ch");
	new szData1[ADSLEN], szData2[ADSLEN], nTagFound;
	
	if(containi(g_ads[g_currentad], "%you%") != -1)
	{
		split(g_ads[g_currentad], szData1, charsmax(szData1), szData2, charsmax(szData2), "%you%");
		nTagFound = 1;
	}
	
	for(new i = 0; i < count; i++)
	{
		id = players[i];
		
		if(nTagFound)
		{
			get_user_name(id, szName, charsmax(szName));
			plr_print_color(id, "%s%s%s", szData1, szName, szData2);
		}else
		{
			plr_print_color(id, "%s", g_ads[g_currentad]);
		}
		
	}
	
	if(++g_currentad >= g_totalads)
	{
                g_currentad = 0;
	}
	
	set_task(random_float(60.0, 80.0), "advertise");
	return PLUGIN_CONTINUE;
}

set_nextmod(modID)
{
	g_nextmodid = modID;
	g_nextmodselected = true;
	
	log("(set_nextmod) nextName: %s || nextID: %d", g_modnames[g_nextmodid], g_nextmodid);
}
set_nextmap(map[])
{	
	g_nextmapselected = true;
	set_cvar_string("amx_nextmap", map);
	
	log("(set_nextmap()) Next Map - %s", map);
}

public change_map()
{	
	map_restoreOriginalTimeLimit();
	
	// Adiciona o mapa atual ao histórico antes de mudar
	if(g_currentmodid != -1 && g_currentmap[0])
	{
		add_map_to_history(g_currentmodid, g_currentmap);
	}
	
	new map[MAPNAME];
	get_cvar_string("amx_nextmap", map, charsmax(map));

	if (!ValidMap(map))
	{
		new modid = g_nextmodselected ? g_nextmodid : g_currentmodid;
		if(ArraySize(g_mapnames[modid]) > 1)
			map_getNext(g_mapnames[modid], map, map);
		else 
			copy(map, charsmax(map), "de_dust2");
	}	

	log("change_map() Map: %s", map);
	server_cmd("changelevel %s", map);
}

@UpdatePlugins(modID)
{
#if MODLOAD_TYPE == 1
	UpdatePluginFile(modID);
#else
	UpdateLocalInfo(modID);
#endif
}

stock UpdateLocalInfo(modID)
{
	new filePath[256];
	formatex(filePath[get_configsdir(filePath, charsmax(filePath))], charsmax(filePath), "/%s/%s-plugins.ini", MULTIMOD_DIR, g_tag[modID]);

	if(!file_exists(filePath)){
		//server_print("[%s] does not exist !!!", filePath);
		filePath[0] = 0;
		copy(filePath[get_configsdir(filePath, charsmax(filePath))], charsmax(filePath), "/plugins.ini");
	}
	
	server_cmd("localinfo amxx_plugins ^"^"");
	set_localinfo(AMX_DEFPLUGINS, filePath);
	server_cmd("localinfo amxx_plugins ^"%s^"", filePath);
}

stock UpdatePluginFile(modID)
{	
	new file1, file2, iBytesRead , fileBuffer[1024];
	new path[256]/*, p_name[PLGNAME]*/;
	
	formatex(path[get_configsdir(path, charsmax(path))], charsmax(path), "/%s/%s-plugins.ini", MULTIMOD_DIR, g_tag[modID]);
	
	if((file1 = fopen(path, "rb")))
	{
		if((file2 = fopen(AMX_MODPLUGINS, "wb")))
		{
			while((iBytesRead = fread_blocks(file1, fileBuffer, sizeof(fileBuffer), BLOCK_BYTE)))
			{
				fwrite_blocks(file2, fileBuffer, iBytesRead, BLOCK_BYTE);
			}
			fclose(file2);
			fclose(file1);
		}
		else
		{
			fclose(file2);
			log_amx("Unable to create %s", AMX_MODPLUGINS);
		}
	}
	else
	{
		fclose(file1);
		log_amx("%s does not exist", path);
	}
}

stock bool:ValidMap(mapname[])
{
	if ( is_map_valid(mapname) )
	{
		return true;
	}
	// If the is_map_valid check failed, check the end of the string
	new len = strlen(mapname) - 4;
	
	// The mapname was too short to possibly house the .bsp extension
	if (len < 0)
	{
		return false;
	}
	if ( equali(mapname[len], ".bsp") )
	{
		// If the ending was .bsp, then cut it off.
		// the string is byref'ed, so this copies back to the loaded text.
		mapname[len] = '^0';
		
		// recheck
		if ( is_map_valid(mapname) )
		{
			return true;
		}
	}
	
	return false;
}

Float:map_getMinutesElapsed()
{		
	return (get_gametime() / 60.0);
}
vote_getRocksNeeded()
{
	return floatround(get_pcvar_float(cvar_rtvRatio) * float(get_realplayersnum()), floatround_ceil);
}

public rtv_remind(param)
{
	new id = param - TASKID_REMINDER;
	new players_left = vote_getRocksNeeded() - g_rockedVoteCnt;
	
	if( players_left )
		plr_print_color(id, "^3%i^1(^4 %i%% ^1) more players need to rockthevote to start the Modvote.", players_left, percent(players_left, vote_getRocksNeeded()) );
}

stock get_realplayersnum( )
{
	new players[32], playerCnt;
	get_players(players, playerCnt, "ch");
	
	return playerCnt;
}

stock update_banned_mods()
{
	new banCount = get_pcvar_num(cvar_banLastmod);
	if(banCount <= 0)
	{
		g_totalBannedMods = 0;
		return;
	}
	
	// Limpa a lista atual
	g_totalBannedMods = 0;
	
	// Adiciona o mod atual se estiver mudando
	if(g_currentmodid != -1 && banCount > 0)
	{
		g_bannedLastMods[g_totalBannedMods++] = g_currentmodid;
		banCount--;
	}
	
	// Adiciona mods anteriores baseado no histórico
	if(g_lastmodid != -1 && banCount > 0)
	{
		// Verifica se já não está na lista
		new bool:already_banned = false;
		for(new i = 0; i < g_totalBannedMods; i++)
		{
			if(g_bannedLastMods[i] == g_lastmodid)
			{
				already_banned = true;
				break;
			}
		}
		
		if(!already_banned)
		{
			g_bannedLastMods[g_totalBannedMods++] = g_lastmodid;
		}
	}
}

stock update_banned_maps(modID)
{
	new banCount = get_pcvar_num(cvar_banLastmap);
	if(banCount <= 0)
	{
		g_totalBannedMaps[modID] = 0;
		return;
	}
	
	// Limpa a lista atual para este mod
	g_totalBannedMaps[modID] = 0;
	
	// Adiciona o mapa atual se estiver no mesmo mod
	if(g_currentmap[0] && modID == g_currentmodid && banCount > 0)
	{
		copy(g_bannedLastMaps[modID][g_totalBannedMaps[modID]], MAPNAME-1, g_currentmap);
		g_totalBannedMaps[modID]++;
		banCount--;
	}
	
	// Adiciona mapas do histórico deste mod
	new historyIndex = g_mapHistoryCount[modID] - 1;
	while(banCount > 0 && historyIndex >= 0)
	{
		// Verifica se já não está na lista
		new bool:already_banned = false;
		for(new i = 0; i < g_totalBannedMaps[modID]; i++)
		{
			if(equal(g_bannedLastMaps[modID][i], g_mapHistory[modID][historyIndex]))
			{
				already_banned = true;
				break;
			}
		}
		
		if(!already_banned)
		{
			copy(g_bannedLastMaps[modID][g_totalBannedMaps[modID]], MAPNAME-1, g_mapHistory[modID][historyIndex]);
			g_totalBannedMaps[modID]++;
			banCount--;
		}
		historyIndex--;
	}
}

stock bool:is_map_banned(modID, const mapname[])
{
	for(new i = 0; i < g_totalBannedMaps[modID]; i++)
	{
		if(equal(g_bannedLastMaps[modID][i], mapname))
			return true;
	}
	return false;
}

stock add_map_to_history(modID, const mapname[])
{
	// Verifica se o mapa já está no histórico
	for(new i = 0; i < g_mapHistoryCount[modID]; i++)
	{
		if(equal(g_mapHistory[modID][i], mapname))
		{
			// Move o mapa para o final (mais recente)
			for(new j = i; j < g_mapHistoryCount[modID] - 1; j++)
			{
				copy(g_mapHistory[modID][j], MAPNAME-1, g_mapHistory[modID][j + 1]);
			}
			copy(g_mapHistory[modID][g_mapHistoryCount[modID] - 1], MAPNAME-1, mapname);
			return;
		}
	}
	
	// Se o histórico está cheio, remove o mais antigo
	if(g_mapHistoryCount[modID] >= MAXMODS)
	{
		for(new i = 0; i < MAXMODS - 1; i++)
		{
			copy(g_mapHistory[modID][i], MAPNAME-1, g_mapHistory[modID][i + 1]);
		}
		g_mapHistoryCount[modID] = MAXMODS - 1;
	}
	
	// Adiciona o novo mapa ao final
	copy(g_mapHistory[modID][g_mapHistoryCount[modID]], MAPNAME-1, mapname);
	g_mapHistoryCount[modID]++;
}

stock bool:is_mod_banned(modID)
{
	for(new i = 0; i < g_totalBannedMods; i++)
	{
		if(g_bannedLastMods[i] == modID)
			return true;
	}
	return false;
}

public vote_rock(id)
{
	if( !get_pcvar_num(cvar_rtv_enable) )
	{
		plr_print_color(id, "^4rtv ^1feature is disabled.");
		return;
	}/*
	if( get_pcvar_num(cvar_rtv_adminmode) && g_Admin )
	{
		plr_print_color(id, "^4rtv ^1feature is disabled when admin is online.");
		return;
	}*/
	if ( CheckBit(g_voteStatus, VOTE_IN_PROGRESS) )
	{
		plr_print_color(id, "%svote is already in progress.", g_Type[g_voteType]);
		return;
	}
	if( g_nextmodselected || g_nextmapselected )
	{
		plr_print_color(id, "Mod/Map is already decided.");
		return;
	}
	
	new Float:minutesElapsed = map_getMinutesElapsed();
	
	if ( get_realplayersnum() < get_pcvar_num(cvar_rtvminplayers) )
	{
		plr_print_color(id, "^3More than or equal to ^4%d ^1players are required to rockthevote.", get_pcvar_num(cvar_rtvminplayers));
		return;
	}
	if (g_rtvWait)
	{
		if (minutesElapsed < g_rtvWait)
		{
			plr_print_color(id, "You have to wait approximately ^4%i minutes ^1more before you can rock the vote.", floatround(g_rtvWait - minutesElapsed, floatround_ceil));
			return;
		}
	}

	new rocksNeeded = vote_getRocksNeeded();

	if (g_rockedVote[id])
	{
		plr_print_color(id, "You have already rocked the vote.");
		rtv_remind(TASKID_REMINDER + id);
		return;
	}

	g_rockedVote[id] = true;
	plr_print_color(id, "You have rocked the vote.");

	if (task_exists(TASKID_REMINDER))
	{
		remove_task(TASKID_REMINDER);
	}

	if (++g_rockedVoteCnt >= rocksNeeded)
	{
		plr_print_color(0, "Enough players have ^4'rocked the vote'^1, a vote for the next mod will now begin.");
		g_voteType = VOTE_MOD; 
		g_rocked = true;
		start_votedirector(false);
		
	}
	else
	{
		rtv_remind(TASKID_REMINDER);
		
		set_task(2 * 60.0, "rtv_remind", TASKID_REMINDER, _, _, "b");
	}
}

public print_info()
{
	new szData[128], charcnt;
	server_print("-------------Multimod Manager-------------");
	server_print("<Total Mods - %d> <Total Blocked - %d>", g_modcount, g_totalblocked);
	for( new i = 0; i < g_modcount; i++)
	{	
		charcnt = formatex(szData, charsmax(szData), "%d. <%s> <Maps - %d>", i + 1, g_modnames[i], ArraySize(g_mapnames[i]));
		
		if(i == g_currentmodid)
		{
			charcnt += formatex(szData[charcnt], charsmax(szData) - charcnt, " <Ads - %d> <Cvars - %d> <Banned Maps - %d> [currentmod]", g_totalads, g_totalcvars, g_totalBannedMaps[i]);
		}
		else
		{
			charcnt += formatex(szData[charcnt], charsmax(szData) - charcnt, " <Banned Maps - %d>", g_totalBannedMaps[i]);
		}
		
		if(g_blockedmod[i])
		{
			formatex(szData[charcnt], charsmax(szData) - charcnt, " [blocked]");
		}
		
		server_print("%s", szData);
	}
	server_print("-------------------------------------------");
}

//Votemod and votemap functions
stock percent(is, of)
{
	return (of != 0) ? floatround(floatmul(float(is)/float(of), 100.0)) : 0;
}

vote_loadRunoffChoices()
{
	new choiceCnt;
	new runoffChoicename[2][32];
	
	for(new i = 0; i < 2; i++)
	{
		copy(runoffChoicename[i], charsmax(runoffChoicename[]), g_voteNames[g_runoffChoice[i]]);
	}
	
	g_voteNames[0][0] = 0;
	g_voteNames[1][0] = 0;
	
	new modidx;
	if (g_runoffChoice[0] != g_choiceCnt)
	{
		copy(g_voteNames[modidx++], charsmax(g_voteNames[]), runoffChoicename[0]);
		choiceCnt++;
	}
	if (g_runoffChoice[1] != g_choiceCnt)
	{
		choiceCnt++;
	}
	copy(g_voteNames[modidx], charsmax(g_voteNames[]), runoffChoicename[1]);
	
	g_choiceCnt = choiceCnt;
	return choiceCnt; 
}

public map_manageEnd()
{	
	g_pauseMapEndManagerTask = true;
	
	if (get_realplayersnum() <= 1)
	{
		change_map();
	}
	else
	{
		if(get_pcvar_num(cvar_endOnRound) && g_wasLastRound == false)
		{
			g_wasLastRound = true;
			
			plr_print_color(0, "Change will happen after this round.");
			
			server_cmd("mp_timelimit 0");
		}
		else
		{
			message_begin(MSG_ALL, SVC_INTERMISSION);
			message_end();
			set_task(floatmax(get_cvar_float("mp_chattime"), 2.0), "change_map");
		}
	}
}

public start_votedirector(bool:forced)
{
	SetBit(g_voteStatus, VOTE_IN_PROGRESS);
	
	new choicesloaded, tempMapName[MAPNAME];
	
	if( CheckBit(g_voteStatus, VOTE_IS_RUNOFF) )
	{
		choicesloaded = vote_loadRunoffChoices();
		//g_voteDuration = get_pcvar_num(cvar_runoffDuration);
	}
	else
	{
		remove_task(TASKID_VOTE);
		
		g_pauseMapEndVoteTask = true;
		g_pauseMapEndManagerTask = true;
		
		if (forced)
		{
			SetBit(g_voteStatus, VOTE_FORCED);
		}
		
		switch(g_voteType)
		{
			case VOTE_MOD:	choicesloaded = votemod_loadChoices();
			case VOTE_MAP:	choicesloaded = g_customVoteMapAdminID ? votemap_customChoices(): votemap_loadChoices();
		}

		//g_voteDuration = get_pcvar_num(cvar_voteDuration);
	}
	
	g_refreshVoteStatus = true;
	
	if( choicesloaded )
	{	
		if(choicesloaded == 1 && g_voteType == VOTE_MAP && g_nextmodselected){
			ArrayGetString(g_mapnames[g_nextmodid], 0, tempMapName, charsmax(tempMapName));
			set_nextmap(tempMapName);
			plr_print_color(0, "Vote creation failed; More than '^41 %s^1' is required. Setting to next default !!!", g_Type[g_voteType]);
			g_pauseMapEndVoteTask = true;
	
			set_task(2.0, "change_map");
			
			return;
		}

		vote_resetStats();
		if(get_pcvar_num(cvar_playSounds)) sound(g_voteType);
		
		ClearBit(g_voteStatus, VOTE_HAS_EXPIRED);
		
		g_voteDuration = 7;
		
		set_task(1.0, "vote_countdownPendingVote", TASKID_VOTE, _, _, "a", 7);
		
		//set_task(10.0, "dbg_fakeVotes");
	}
	else
	{		
		plr_print_color(0, "Vote creation failed; More than '^41 %s^1' is required", g_Type[g_voteType]);
		
		if(g_voteType == VOTE_MOD && g_modcount == 1){
			plr_print_color(0, "Votemap for the currentmod is going to start ...");
			g_voteType = VOTE_MAP;
			set_task(3.0, "start_votedirector");
			
			return;
		}
	
		ClearBit(g_voteStatus, VOTE_IN_PROGRESS);
		ClearBit(g_voteStatus, VOTE_IS_RUNOFF);
		ClearBit(g_voteStatus, VOTE_FORCED);
		
		g_pauseMapEndVoteTask = false;
		g_pauseMapEndManagerTask = false;
		
		g_voteType = 0;
	}
	return;
}

public vote_countdownPendingVote()
{	
	set_hudmessage(0, 222, 50, -1.0, 0.13, 0, 1.0, 0.94, 0.0, 0.0, -1);
	show_hudmessage(0, "%svote will begin in %i seconds...", g_Type[g_voteType], g_voteDuration);
	
	new word[6];
	num_to_word(g_voteDuration, word, 5);
	client_cmd(0, "spk ^"fvox/%s^"", word);
	
	g_voteDuration--;
	
	if (g_voteDuration <= 0)
	{
		g_voteDuration = CheckBit(g_voteStatus, VOTE_IS_RUNOFF) ? get_pcvar_num(cvar_runoffDuration) : get_pcvar_num(cvar_voteDuration);
		client_cmd(0, "spk Gman/Gman_Choose%i", random_num(1, 2));
		counter();
	}
}

public counter()
{
	if( g_voteDuration < 0 )
	{
		set_task(1.0, "vote_expire", TASKID_VOTE);
	}
	else
	{
		set_task(1.0, "counter", TASKID_VOTE);
		vote_display();
		g_voteDuration--;
	}
}

public vote_display()
{
	static keys, voteStatus[512], voteTally[16];
	
	new isVoteOver = (g_voteDuration <= 0) ? 1 : 0;
		
	static voteHeader[90];
	if (isVoteOver)
	{
		formatex(voteHeader, charsmax(voteHeader), "\yResult of the Vote\w^n^n");
	}
	else
	{
		formatex(voteHeader, charsmax(voteHeader), "\yChoose the Next %s: \r[\wRemaining seconds\y: \r%i]\w^n^n", g_Type[g_voteType], g_voteDuration);
	}
	
	new charCnt;
	
	if(g_refreshVoteStatus || isVoteOver)
	{
		//server_print("Refresh Vote Status (Enter)");
		
		new isRunoff = CheckBit(g_voteStatus, VOTE_IS_RUNOFF);
		new isforced = CheckBit(g_voteStatus, VOTE_FORCED);
		new bool:allowExtend;
		
		switch( g_voteType )
		{
			case VOTE_MOD: allowExtend = ((isRunoff && g_choiceCnt == 1) || (!isforced && !isRunoff && get_cvar_float("mp_timelimit") < get_pcvar_float(cvar_pExtendMax)));
			case VOTE_MAP: allowExtend = (!g_nextmodselected && ((isRunoff && g_choiceCnt == 1) || (!isforced && !isRunoff && get_cvar_float("mp_timelimit") < get_pcvar_float(cvar_pExtendMax))));
		}
		
		voteStatus[0] = 0;
		keys = MENU_KEY_0;
	
		new votcnt;
	
		for (new g_voteNum = 0; g_voteNum < g_choiceCnt; g_voteNum++)
		{
			votcnt = g_votecnt[g_voteNum];
			vote_getTallyStr(voteTally, charsmax(voteTally), votcnt);
		
			charCnt += formatex(voteStatus[charCnt], charsmax(voteStatus)-charCnt, "\y%d\w. %s%s^n", g_voteNum + 1, g_voteNames[g_voteNum], voteTally );
			keys |= (1<<g_voteNum);
		}
		
		if ( allowExtend )
		{
			if ( !isRunoff )
			{
				charCnt += formatex(voteStatus[charCnt], charsmax(voteStatus)-charCnt, "^n");
			}
		
			vote_getTallyStr(voteTally, charsmax(voteTally), g_votecnt[g_choiceCnt]);
			
			switch(g_voteType)
			{
				case VOTE_MOD: charCnt += formatex(voteStatus[charCnt], charsmax(voteStatus)-charCnt, "\y%d\w. Extend \r%s%s", g_choiceCnt + 1, g_modnames[g_currentmodid], voteTally);
				case VOTE_MAP: charCnt += formatex(voteStatus[charCnt], charsmax(voteStatus)-charCnt, "\y%d\w. Extend \r%s%s", g_choiceCnt + 1, g_currentmap, voteTally);
			}
			
			keys |= (1<<g_choiceCnt);
		}
		g_refreshVoteStatus = false;
	}
	
	static menuClean[512];
	menuClean[0] = 0;
	
	charCnt = formatex(menuClean, charsmax(menuClean), "%s%s", voteHeader, voteStatus);
	
	if (isVoteOver)
	{
		formatex(menuClean[charCnt], charsmax(menuClean) - charCnt, "^n\yThe vote has ended.");
	}
	
	new players[32], playerCnt, id;
	get_players(players, playerCnt, "ch");

	new showStatus = get_pcvar_num(cvar_voteShowStatus);
	for (new playerIdx = 0; playerIdx < playerCnt; ++playerIdx)
	{
		id = players[playerIdx];
		
		if(showStatus || !g_playervotedid[id])
		{
			if(isVoteOver)	show_menu(id, keys, menuClean, 5, g_VoteMenuChoose);
			else	show_menu(id, keys, menuClean, g_voteDuration, g_VoteMenuChoose);
		}
	}
}

public vote_handleChoice(id, key)
{
	if (CheckBit(g_voteStatus, VOTE_HAS_EXPIRED))
	{
		client_cmd(id, "^"slot%i^"", key + 1);
		return;
	}
	
	new isVoteOver = (g_voteDuration <= 0) ? 1 : 0;
	
	if (g_playervotedid[id] == false && !isVoteOver )
	{
		new name[32];
		get_user_name(id, name, charsmax(name));
		
		g_votesCast++;
	
		if (key == g_choiceCnt)
		{
			if (g_playervotedid[id] == false)
			{
				plr_print_color(0, "^4%s ^1has chosen to extend the current ^3%s.", name, g_Type[g_voteType]);
			}
		}
		else
		{
			plr_print_color(0, "^4%s ^1has chosen ^3%s.", name, g_voteNames[key]);
		}
		g_votecnt[key]++;
		g_playerchoiceid[id] = key;
		g_playervotedid[id] = true;
		g_refreshVoteStatus = true;
	}
	else
	{
		client_cmd(id, "^"slot%i^"", key + 1);
	}
	
	set_task(0.1, "vote_display");
}

public dbg_fakeVotes()
{
	if (!(g_voteStatus & VOTE_IS_RUNOFF))
	{
		g_votecnt[0] += 3;	// choice 1
		g_votecnt[1] += 2;
		g_votecnt[2] += 1;
		g_votesCast = g_votecnt[0] + g_votecnt[1] + g_votecnt[2];
		g_refreshVoteStatus = true;
	}
	else if (g_voteStatus & VOTE_IS_RUNOFF)
	{
		g_votecnt[0] += 1;	// choice 1
		g_votecnt[1] += 0;	// choice 2
		
		g_votesCast = g_votecnt[0] + g_votecnt[1];
		g_refreshVoteStatus = true;
	}
}

vote_getTallyStr(voteTally[], voteTallyLen, voteCnt)
{
	if( voteCnt )
	{
		voteCnt = percent(voteCnt, g_votesCast);
		formatex(voteTally, voteTallyLen, " \y(\r%i%%\y)\w", voteCnt);	
	}
	else
	{
		voteTally[0] = 0;
	}
}

public vote_expire()
{	
	////log_amx("<vote_expire> executed");
	new tempModID;
	
	SetBit(g_voteStatus, VOTE_HAS_EXPIRED);
	
	new firstPlaceVoteCnt, secondPlaceVoteCnt, totalVotes;
	for (new idxChoice = 0; idxChoice <= g_choiceCnt; ++idxChoice)
	{
		totalVotes += g_votecnt[idxChoice];

		if (firstPlaceVoteCnt < g_votecnt[idxChoice])
		{
			secondPlaceVoteCnt = firstPlaceVoteCnt;
			firstPlaceVoteCnt = g_votecnt[idxChoice];
		}
		else if (secondPlaceVoteCnt < g_votecnt[idxChoice])
		{
			secondPlaceVoteCnt = g_votecnt[idxChoice];
		}
	}

	new firstPlace[9], firstPlaceCnt;
	new secondPlace[9], secondPlaceCnt;

	for (new idxChoice = 0; idxChoice <= g_choiceCnt; ++idxChoice)
	{
		if (g_votecnt[idxChoice] == firstPlaceVoteCnt)
		{
			firstPlace[firstPlaceCnt++] = idxChoice;
		}
		else if (g_votecnt[idxChoice] == secondPlaceVoteCnt)
		{
			secondPlace[secondPlaceCnt++] = idxChoice;
		}
	}
	
	// announce the outcome
	new idxWinner;
	if (firstPlaceVoteCnt)
	{
		// start a runoff vote, if needed
		if ( get_pcvar_num(cvar_runoffEnabled) && !CheckBit(g_voteStatus, VOTE_IS_RUNOFF) )
		{
			if (firstPlaceVoteCnt <= totalVotes / 2)
			{
				plr_print_color(0, "Runoff voting is required because the top choice didn't receive over^4 (50 percent) ^1of the votes cast.", 50);
				if(get_pcvar_num(cvar_playSounds)) sound(3);

				SetBit(g_voteStatus, VOTE_IS_RUNOFF);

				new choice1Idx, choice2Idx;
				if (firstPlaceCnt > 2)
				{
					choice1Idx = random_num(0, firstPlaceCnt - 1);
					choice2Idx = random_num(0, firstPlaceCnt - 1);
					
					if (choice2Idx == choice1Idx)
					{
						choice2Idx = (choice2Idx == firstPlaceCnt - 1) ? 0 : ++choice2Idx;
					}
					
					g_runoffChoice[0] = firstPlace[choice1Idx];
					g_runoffChoice[1] = firstPlace[choice2Idx];
					
					plr_print_color(0, "^4%i ^1choices were tied for first. Two of them were randomly selected for the vote.", firstPlaceCnt);
				}
				else if (firstPlaceCnt == 2)
				{
					g_runoffChoice[0] = firstPlace[0];
					g_runoffChoice[1] = firstPlace[1];
				}
				else if (secondPlaceCnt == 1)
				{
					g_runoffChoice[0] = firstPlace[0];
					g_runoffChoice[1] = secondPlace[0];
				}
				else
				{
					g_runoffChoice[0] = firstPlace[0];
					g_runoffChoice[1] = secondPlace[random_num(0, secondPlaceCnt - 1)];
					
					plr_print_color(0, "The first place choice and a randomly selected, of ^4%i^1, second place choice will be in the vote.", secondPlaceCnt);
				}
				vote_resetStats();
				set_task(3.0, "start_votedirector");
				
				return;
			}
		}

		if (firstPlaceCnt > 1)
		{
			idxWinner = firstPlace[random_num(0, firstPlaceCnt - 1)];
			plr_print_color(0, "The winning choice was randomly selected from the ^4%i ^1tied top choices.", firstPlaceCnt);
		}
		else
		{
			idxWinner = firstPlace[0];
		}

		if (idxWinner == g_choiceCnt)
		{
			switch(g_voteType)
			{
				case VOTE_MOD:
				{
					plr_print_color(0, "The current mod will be extended followed by a map vote.");
					
					g_voteType = VOTE_MAP;
					
					ClearBit(g_voteStatus, VOTE_IS_RUNOFF);
					
					reset_plrnominationsmap(g_currentmodid);
					
					plr_print_color(0, "A map vote for extension will appear in^4 1 min^1, Nominate maps for ^4%s^1", g_modnames[g_currentmodid]);
					set_task(get_pcvar_float(cvar_delayVote), "start_votedirector");
				}
				case VOTE_MAP:
				{
					plr_print_color(0, "The current map will be extended until next vote.");
					g_rocked = false;
					reset_nominations();
					reset_plrnominations(0);
					vote_resetStats();
					
					g_endofmapvote = false;
					g_voteType = 0;
					g_voteStatus = 0;
					
					if(g_rtvWait)
					{
						g_rtvWait = get_cvar_float("mp_timelimit") + g_rtvWait;
					}
					
					if(g_originalTimelimit)
					{
						log("vote_expire() Extended");
						set_cvar_float("mp_timelimit", get_cvar_float("mp_timelimit") + get_pcvar_float(cvar_pExtendStep));
						server_exec();
					}
					
					g_pauseMapEndVoteTask = false;
					g_pauseMapEndManagerTask = false;
					g_handleMapChange = true;
				}
			}
		}
		else 
		{
			switch(g_voteType)
			{
				case VOTE_MOD: 	
				{ 
					plr_print_color(0, "The next mod will be ^4%s", g_voteNames[idxWinner]);
					tempModID = modGetID(g_voteNames[idxWinner]);
					set_nextmod(tempModID);
					
					g_voteType = VOTE_MAP;
					
					ClearBit(g_voteStatus, VOTE_IS_RUNOFF);
					reset_plrnominationsmap(tempModID);
					plr_print_color(0, "A map vote for will appear in^4 %d secounds^1, Nominate maps for ^4%s^1", get_pcvar_num(cvar_delayVote), g_voteNames[idxWinner]);
					set_task(get_pcvar_float(cvar_delayVote), "start_votedirector");
				}
				case VOTE_MAP:	
				{
					g_voteStatus = 0;
					
					plr_print_color(0, "The next map will be ^4%s", g_voteNames[idxWinner]);
					set_nextmap(g_voteNames[idxWinner]);
					
					if( g_handleMapChange )
					{
						if(g_endofmapvote)
						{
							g_pauseMapEndManagerTask = false;
						}else
						{
							set_task(2.0, "map_manageEnd");
						}
					}
				}
			}
		}
	}
	else
	{
		idxWinner = random_num(0, g_choiceCnt - 1);
		
		switch(g_voteType)
		{
			case VOTE_MOD: 	
			{
				plr_print_color(0, "No one voted. The next mod was randomly chosen to be ^4%s", g_voteNames[idxWinner]);
				tempModID = modGetID(g_voteNames[idxWinner]);
				set_nextmod(tempModID);
				g_voteType = VOTE_MAP;
					
				ClearBit(g_voteStatus, VOTE_IS_RUNOFF);
				reset_plrnominationsmap(tempModID);
				plr_print_color(0, "A map vote for will appear in^4 %d seconds^1, Nominate maps for ^4%s^1", get_pcvar_num(cvar_delayVote), g_voteNames[idxWinner]);
				set_task(get_pcvar_float(cvar_delayVote), "start_votedirector");
			}
			case VOTE_MAP:	
			{
				g_voteStatus = 0;
				plr_print_color(0, "No one voted. The next map was randomly chosen to be ^4%s", g_voteNames[idxWinner]);
				set_nextmap(g_voteNames[idxWinner]);
				
				if( g_handleMapChange )
				{
					if(g_endofmapvote)
					{
						g_pauseMapEndManagerTask = false;
					}else
					{
						set_task(2.0, "map_manageEnd");
					}
				}
			}
		}	
	}
}

public custom_compare(const elem1[], const elem2[], const array[], const data[], data_size)
{
	if(elem1[g_nomvote] > elem2[g_nomvote])
		return -1;
	else if(elem1[g_nomvote] < elem2[g_nomvote])
		return 1;
	return 0;
}

votemap_customChoices()
{
	g_choiceCnt = 0;
	
	new tempMap[MAPNAME], size = g_playerVoteMapCnt[g_customVoteMapAdminID], modID = g_playerVoteModMapSel[g_customVoteMapAdminID];
	
	for(new i = 0; i < size; i++)
	{
		ArrayGetString(g_mapnames[modID], g_playerVoteMapSel[g_customVoteMapAdminID][i], tempMap, charsmax(tempMap));
		copy(g_voteNames[g_choiceCnt++], charsmax(g_voteNames[]), tempMap);
	}
	g_customVoteMapAdminID = 0;
	
	return g_choiceCnt;
}

votemod_loadChoices()
{
	g_choiceCnt = 0;
	
	new unsuccessfullcnt, randID, bool: voteSelID[MAXMODS];
	new mod_counter = min(g_modcount, SELECTMENU);
	
	// Atualiza a lista de mods banidos
	update_banned_mods();
	
	log("(votemod_loadChoices) Blocked: %d || Banned: %d || Mod count(max): %d || Mod counter: %d", g_totalblocked, g_totalBannedMods, g_modcount, mod_counter);
	
	if(get_pcvar_num(cvar_nominate_enable))
	{
		SortCustom2D(g_nominate, g_modcount, "custom_compare");
	
		new tempID[nomTag], tempNomCnt = 0;
		while(g_choiceCnt < mod_counter && tempNomCnt < g_modcount)
		{
			tempID[g_nomvote] = g_nominate[tempNomCnt][g_nomvote];
			tempID[g_nomid] = g_nominate[tempNomCnt][g_nomid];
		
			if(tempID[g_nomvote] == 0)
			{
				break;
			}
		
			if(!is_mod_banned(tempID[g_nomid]) && tempID[g_nomid] != g_currentmodid)
			{
				copy(g_voteNames[g_choiceCnt], charsmax(g_voteNames[]), g_modnames[tempID[g_nomid]]);
				voteSelID[tempID[g_nomid]] = true;
				g_choiceCnt++;
			}
			tempNomCnt++;
		}
	}
	
	while( g_choiceCnt < mod_counter )
	{
		g_voteNames[g_choiceCnt][0] = 0;
		unsuccessfullcnt = 0;
		
		randID = random_num(0, g_modcount - 1);
		
		while((g_blockedmod[randID] || g_currentmodid == randID || is_mod_banned(randID) || voteSelID[randID]) && unsuccessfullcnt < g_modcount )
		{
			unsuccessfullcnt++;
			if( ++randID == g_modcount )
			{
				randID = 0;
			}
		}
		if(unsuccessfullcnt == g_modcount)
		{
			break;
		}
		
		voteSelID[randID] = true;
		
		copy(g_voteNames[g_choiceCnt], charsmax(g_voteNames[]), g_modnames[randID]);
		
		g_choiceCnt++;
		log("(votemod_loadChoices) ChoiceCnt: %d || g_votename: %s || RandomIndex: %d || Mod counter: %d", g_choiceCnt, g_modnames[randID], randID, mod_counter);
	}
	
	return g_choiceCnt;
}

votemap_loadChoices()
{
	g_choiceCnt = 0;
	
	new unsuccessfullcnt = 0, randomIndex;
	new mapName[MAPNAME];
	new modID = g_nextmodselected ? g_nextmodid : g_currentmodid;
	
	new g_mapcount = ArraySize(g_mapnames[modID]);
	
	// Atualiza a lista de mapas banidos para este mod
	update_banned_maps(modID);
	
	new map_counter = min(g_mapcount, SELECTMENU);
	log("(votemap_loadChoices) Map count(max): %d || Map counter: %d || Banned maps: %d", g_mapcount, map_counter, g_totalBannedMaps[modID]);
	
	if(get_pcvar_num(cvar_nominate_enable) >= 2)
	{
		new players[32], playerCnt, playerID;
		get_players(players, playerCnt);
	
		for(new k = 0; k < MAX_PLAYERNOMCNT && g_choiceCnt < map_counter; k++)
		{
			for(new i; i < playerCnt; i++)
			{
				playerID = players[i];
				if(k < g_playernominatedmapcnt[playerID])
				{
					g_voteNames[g_choiceCnt][0] = 0;
					ArrayGetString(g_mapnames[modID], g_playernominatedmapid[playerID][k], mapName, charsmax(mapName));
					
					// Verifica se o mapa não está banido
					if(!is_map_banned(modID, mapName))
					{
						copy(g_voteNames[g_choiceCnt++], charsmax(g_voteNames[]), mapName);
						log("(votemap_loadChoices) mapName: %s || playerID: %d || plrMapCnt: %d || modID: %d || mapID: %d", mapName, playerID, g_playernominatedmapcnt[playerID], modID, g_playernominatedmapid[playerID][k]);
					}
				}
			}
		}
	}
	
	while( g_choiceCnt < map_counter )
	{
		g_voteNames[g_choiceCnt][0] = 0;
		randomIndex = random_num(0, g_mapcount - 1);
		ArrayGetString(g_mapnames[modID], randomIndex, mapName, charsmax(mapName));
		
		unsuccessfullcnt = 0;
	
		while((equal(g_currentmap, mapName) || is_map_banned(modID, mapName) || map_isInMenu(mapName)) && unsuccessfullcnt < g_mapcount )
		{
			unsuccessfullcnt++;
			if( ++randomIndex == g_mapcount )
			{
				randomIndex = 0;
			}
			ArrayGetString(g_mapnames[modID], randomIndex, mapName, charsmax(mapName));
		}
		if(unsuccessfullcnt >= g_mapcount)
		{
			break;
		}
		copy(g_voteNames[g_choiceCnt++], charsmax(g_voteNames[]), mapName);
		
		log("(votemap_loadChoices) mapName: %s || RandomIndex: %d || UnSuccess: %d", g_voteNames[g_choiceCnt-1], randomIndex, unsuccessfullcnt);
	}
	return g_choiceCnt;
}

bool: map_isInMenu(map[])
{
	for (new idxChoice = 0; idxChoice < g_choiceCnt; ++idxChoice)
	{
		if (equal(map, g_voteNames[idxChoice]))
		{
			return true;
		}
	}
	return false;
}

modGetID(current[])
{
	new returnVal = -1;
	for (new Idx = 0; Idx < g_modcount; Idx++)
	{
		if (equal(current, g_modnames[Idx]))
		{
			returnVal = Idx;
			break;
		}
	}
	
	return returnVal;
}

sound(iKey)
{
	switch(iKey)
	{
		case 1:	client_cmd(0, "spk ^"get red(e80) ninety(s45) to check(e20) use bay(s18) mode^"");
		case 2:	client_cmd(0, "spk ^"get red(e80) ninety(s45) to check(e20) use bay(s18) mass(e42) cap(s50)^"");
		case 3:	client_cmd(0, "spk ^"run officer(e40) voltage(e30) accelerating(s70) is required^"");		
	}
}

vote_resetStats()
{
	g_votesCast = 0;
	g_rockedVoteCnt	= 0;
	arrayset(g_votecnt, 0, sizeof(g_votecnt));
	
	for(new i = 1; i <= MAX_PLAYER_CNT; i++)
	{
		g_playervotedid[i] = false;
		g_playerchoiceid[i] = 0;
		g_rockedVote[i] = false;
	}
}
vote_unrock(id)
{
	if (g_rockedVote[id])
	{
		g_rockedVote[id] = false;
		g_rockedVoteCnt--;
		
		if(g_rockedVoteCnt < 0) g_rockedVoteCnt = 0;
	}
}


stock plr_print_color(id, const text[], any:...)
{
#if AMXX_VERSION_NUM < 183
	static szMsg[192];
	new iPlayers[32], iCount;
	
	vformat(szMsg, charsmax(szMsg), text, 3);
	
	format(szMsg, charsmax(szMsg), "^1%s %s", g_chatPrefix, szMsg);
	if(id > 0)
	{
		message_saytext(id, szMsg);
	}
	else
	{
		get_players(iPlayers, iCount, "ch");
       
		for(new i = 0 ; i < iCount ; i++)
		{
			message_saytext(iPlayers[i], szMsg);
		}
	}
#else
	static szMsg[192];
	vformat(szMsg, charsmax(szMsg), text, 3);
	client_print_color(id, print_team_default, "%s %s", g_chatPrefix, szMsg);
#endif
}

stock message_saytext(id, szMsg[])
{
	static s_iMsgidSayText = 0;
	if(!s_iMsgidSayText)
	{
		s_iMsgidSayText = get_user_msgid("SayText");
	}
	message_begin(MSG_ONE, s_iMsgidSayText, _, id);
	write_byte(id);
	write_string(szMsg);
	message_end();
}

reset_nominations()
{
	for(new i = 0; i < g_modcount; i++)
	{
		g_nominate[i][g_nomvote] = 0;
		g_nominate[i][g_nomid] = i;
		
		////log_amx("reset_nominations() <%d> <%d>", g_nominate[i][g_nomvote], g_nominate[i][g_nomid]);
	}
}

reset_plrnominationsmap(modID)
{
	for(new i = 1; i <= MAX_PLAYER_CNT; i++)
	{
		if(g_playernominatedid[i] != modID)
		{
			g_playernominatedid[i] = modID;
			g_playernominatedmapcnt[i] = 0;
		}
	}
}

reset_plrnominations(id)
{
	if(id)
	{
		g_nominate[g_playernominatedid[id]][g_nomvote]--;
		if(g_nominate[g_playernominatedid[id]][g_nomvote] < 0) g_nominate[g_playernominatedid[id]][g_nomvote] = 0;
		g_playernominated[id] = false;
		g_playernominatedid[id] = g_currentmodid;		
		g_playernominatedmapcnt[id] = 0;
	}
	else
	{
		for(new i = 1; i <= MAX_PLAYER_CNT; i++)
		{
			g_playernominated[i] = false;
			g_playerlastnominated[i] = 0;
			g_playernominatedmapcnt[i] = 0;
			g_playernominatedid[i] = g_currentmodid;
		}
	}
}

replace_colorargs(string[], len)
{	
	replace_all(string, len, "!t", "^x03");
	replace_all(string, len, "!n", "^x01");
	replace_all(string, len, "!g", "^x04");
}
replace_conditions(string[], len)
{	
	replace(string, len, "%currentmod%", g_modnames[g_currentmodid]);
	
	if(g_lastmodid > -1)
	{
		replace(string, len, "%lastmod%", g_modnames[g_lastmodid]);
	}else{
		replace(string, len, "%lastmod%", "First Mod");
	}
	
	replace(string, len, "%currentmap%", g_currentmap);
	
	if(g_lastmap[0])
	{
		replace(string, len, "%lastmap%", g_lastmap);
	}else{
		replace(string, len, "%lastmap%", "First Map");
	}
}


/*public cmdDebugNom(id)
{
	new randID;
	for(new i; i < 6; i++)
	{
		do
		{
			randID = random_num(0, g_modcount - 1);
		}while(randID == g_currentmodid);
		g_nominate[randID][g_nomvote]++;
		//log_amx("Nominated - <%s> <%d>", g_modnames[randID], randID);
	}
	
	//reset_nominations();
	
	return PLUGIN_HANDLED;
}*/

MakeMapMenu(id, const modID, const menuID, chooseMode, playerVoteMapCnt = 0)
{
	new sel_index[10], mapline[DATASTR], matchNom;
	
	new mapSize = ArraySize(g_mapnames[modID]);
	
	// Atualiza a lista de mapas banidos para este mod
	update_banned_maps(modID);
	
	if(chooseMode == 2)
	{
		num_to_str(mapSize, sel_index, charsmax(sel_index));
		menu_additem(menuID, "Start Voting^n", sel_index, playerVoteMapCnt ? 0 : 1 << 26);
	}
	
	for(new i = 0; i < mapSize; i++)
	{
		ArrayGetString(g_mapnames[modID], i, mapline, charsmax(mapline));
		num_to_str(i, sel_index, charsmax(sel_index));
		
		switch(chooseMode)
		{
			case 2:
			{
				if(isMapSelected(id, i))
				{
					add(mapline, charsmax(mapline), " (selected)");
					menu_additem(menuID, mapline, sel_index, 1 << 26);
				}
				else	
				{
					menu_additem(menuID, mapline, sel_index, 0);
				}
			}
			case 3:
			{
				if(equal(mapline, g_currentmap) || is_map_banned(modID, mapline))
					continue;
				
				matchNom = is_map_nom(modID, i);
				if(matchNom == id)
				{
					add(mapline, charsmax(mapline), " (Your Nomination)");
					menu_additem(menuID, mapline, sel_index, 1 << 26);
				}else if(matchNom)
				{
					add(mapline, charsmax(mapline), " (Others Nominated)");
					menu_additem(menuID, mapline, sel_index, 1 << 26);
				}
				else
				{
					menu_additem(menuID, mapline, sel_index, 0);
				}
			}
			default: 
			{
				// Para admin menu, mostra se está banido
				if(is_map_banned(modID, mapline))
				{
					add(mapline, charsmax(mapline), " (banned)");
					menu_additem(menuID, mapline, sel_index, 1 << 26);
				}
				else
				{
					menu_additem(menuID, mapline, sel_index, 0);
				}
			}
		}
	}
}

public setmapmenu(id)		// Menu chooseMode = 1
{	
	g_playerVoteModMapSel[id] = g_nextmodselected ? g_nextmodid : g_currentmodid;
	
	new szData[MODNAME + 20];
	formatex(szData, charsmax(szData), "\yChange Map \r(\w%s\r)", g_modnames[g_playerVoteModMapSel[id]]);
	
	new menu = menu_create(szData, "menu_handler_map");
	MakeMapMenu(id, g_playerVoteModMapSel[id], menu, 1, 0);
	
	menu_display(id, menu, 0);
	return PLUGIN_CONTINUE;
}

public menu_handler_map( id, menu, item )
{
	if(item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	if(g_nextmapselected || CheckBit(g_voteStatus, VOTE_IN_PROGRESS))
	{
		plr_print_color(id, "Map is already selected or Vote is in progress.");
		
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	new szData[10], paccess, callback;

	menu_item_getinfo(menu, item, paccess, szData, charsmax(szData), _, 0, callback);
	menu_destroy(menu);
	
	new modID = g_playerVoteModMapSel[id];	//str_to_num(sz_tempModID);
	new mapID = str_to_num(szData);
	
	//log_amx("<MODID - %d> <MapID - %d>", modID, mapID);
	
	new matchMap[MAPNAME];
	
	if(modID != (g_nextmodselected ? g_nextmodid : g_currentmodid))//!equal(matchMap, name))
	{
		plr_print_color(id, "MapID mismatch. Reopen to refresh your Map Menu.");
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	ArrayGetString(g_mapnames[modID], mapID, matchMap, charsmax(matchMap));
	
	new sAdminName[32];
	get_user_name(id, sAdminName, charsmax(sAdminName));
	
	plr_print_color(0, "Admin (^4%s^1) Changed Map to ^3%s", sAdminName, matchMap);
	log("%s changed map %s", sAdminName, matchMap);
	g_pauseMapEndVoteTask = true;
	set_nextmap(matchMap);
	
	set_task(2.0, "change_map");
	return PLUGIN_HANDLED;
}


isMapSelected(id, tempMapID)
{
	for(new i; i < g_playerVoteMapCnt[id]; i++)
		if(g_playerVoteMapSel[id][i] == tempMapID)
			return 1;
	
	return 0;
}
public cmdCustomMap(id)
{
	g_playerVoteModMapSel[id] = g_nextmodselected ? g_nextmodid : g_currentmodid;
	g_playerVoteMapCnt[id] = 0;
	
	custommapmenu(id, 0);
	
	return PLUGIN_HANDLED;
}

public custommapmenu(id, pos)		// Menu chooseMode = 2
{	
	new modID = g_playerVoteModMapSel[id];
	new title[MODNAME + 100];
	formatex(title, charsmax(title), "\yCustom VoteMap \r(\w%s\r)^n\yTotal Selected \r[\w%d\r]", g_modnames[modID], g_playerVoteMapCnt[id]);
	
	new menu = menu_create(title, "custom_maphandleChoice");
	MakeMapMenu(id, modID, menu, 2, g_playerVoteMapCnt[id]);
	
	menu_display(id, menu, pos);
	return PLUGIN_CONTINUE;
}

public custom_maphandleChoice(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	new szData[10], paccess, callback, pos, menu1, menu2;

	menu_item_getinfo(menu, item, paccess, szData, charsmax(szData), _, 0, callback);
	player_menu_info(id, menu1, menu2, pos);
	menu_destroy(menu);
	
	new modID = g_playerVoteModMapSel[id];
	new mapID = str_to_num(szData);
	
	//log_amx("<MODID - %d> <MapID - %d>", modID, mapID);
	
	if(mapID == ArraySize(g_mapnames[modID]))
	{			
		if(modID != (g_nextmodselected ? g_nextmodid : g_currentmodid))//!equal(matchMap, name))
		{
			plr_print_color(id, "ModID mismatch. Refresh your Map Menu and select again.");
			menu_destroy(menu);
			return PLUGIN_HANDLED;
		}
		
		start_vote(id, VOTE_MAP, true);
		return PLUGIN_HANDLED;
	}
	
	new matchMap[MAPNAME];
		
	if(g_playerVoteMapCnt[id] < MAXADMCUSTMAP)
	{
		ArrayGetString(g_mapnames[modID], mapID, matchMap, charsmax(matchMap));
		g_playerVoteMapSel[id][g_playerVoteMapCnt[id]++] = mapID;
		
		plr_print_color(id, "Selected Map - ^4%s", matchMap);	
	}
	else
	{
		plr_print_color(id, "Max selected -^4 %d!.", g_playerVoteMapCnt[id]);
	}
	custommapmenu(id, pos);
	
	return PLUGIN_HANDLED;
}

public mapNominateMenu(id, pos)
{
	if(get_pcvar_num(cvar_nominate_enable) < 2)
	{
		plr_print_color(id, "Map Nomination disabled.");
		return PLUGIN_HANDLED;
	}
	
	new modID = g_playernominatedid[id];
	new title[200];
	formatex(title, charsmax(title), "\yNominate Map \r(\w%s\r)^n\yYour Nominations \r[\w%d\r]", g_modnames[modID], g_playernominatedmapcnt[id]);
	
	new menu = menu_create(title, "nominate_MapHandler");
	MakeMapMenu(id, modID, menu, 3, g_playerVoteMapCnt[id]);
	
	menu_display(id, menu, pos);
	return PLUGIN_CONTINUE;
}
public nominate_MapHandler(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	new szData[10], paccess, callback, pos, menu1, menu2;

	menu_item_getinfo(menu, item, paccess, szData, charsmax(szData), _, 0, callback);
	
	new modID = g_playernominatedid[id];
	new mapID = str_to_num(szData);
	
	player_menu_info(id, menu1, menu2, pos);
	
	menu_destroy(menu);
	new secondsLeft = get_pcvar_num(cvar_nomMapAfter) - (get_systime() - g_playerlastnominated[id]);
	
	if(secondsLeft > 0)
	{
		plr_print_color(id, "You have nominated just few seconds ago. Wait (^4%i ^1seconds) more", secondsLeft);
		return PLUGIN_HANDLED;
	}
	
	/*if(modID != g_playernominatedid[id])
	{
		plr_print_color(id, "ModID mismatch. Refresh your Map Menu and select again.");
		return PLUGIN_HANDLED;
	}*/
	
	new matchMap[MAPNAME], szName[32];
	if(g_playernominatedmapcnt[id] < MAX_PLAYERNOMCNT)
	{
		ArrayGetString(g_mapnames[modID], mapID, matchMap, charsmax(matchMap));
		
		if(is_map_nom(modID, mapID))
		{
			plr_print_color(id, "This map has been nominated just now, Try another...");
			mapNominateMenu(id, pos);
			return PLUGIN_HANDLED;
		}
		g_playernominatedmapid[id][g_playernominatedmapcnt[id]++] = mapID;
		g_playerlastnominated[id] = get_systime();
		
		get_user_name(id, szName, charsmax(szName));
		plr_print_color(0, "(^3%s^1) has nominated Map [^4%s^1]", szName, matchMap);
		
		log("(nominate_Maphandler) mapName: %s || plrMapCnt: %d || modID: %d || mapID: %d || plrID: %d", matchMap, g_playernominatedmapcnt[id], modID, mapID, id);
	}
	else
	{
		plr_print_color(id, "Nomination max selected -^4 %d^1!, Type '^4cnom^1' to cancel.", g_playernominatedmapcnt[id]);
	}
	
	mapNominateMenu(id, pos);
	return PLUGIN_HANDLED;
}
is_map_nom(modID, mapID)
{
	for(new i = 1; i <= MAX_PLAYER_CNT; i++)
	{
		if(g_playernominatedid[i] != modID)
			continue;
			
		for(new j = 0; j < g_playernominatedmapcnt[i]; j++)
		{
			if(g_playernominatedmapid[i][j] == mapID)
				return i;
		}
	}
	return 0;
}

nominate_mainMenu(id, mode)
{
	new szData[DATASTR], index[7];
	
	switch(mode)
	{
		case 1: formatex(szData, charsmax(szData), "\yNominate");
		case 2: formatex(szData, charsmax(szData), "\yCancel Nomination");
	}
	
	new menu = menu_create(szData, "nominate_mainHandler");
	
	num_to_str(mode, index, charsmax(index));
	
	if(g_playernominated[id]) 
		formatex(szData, charsmax(szData), "Mod \r[%s]", g_modnames[g_playernominatedid[id]]);
	else
		formatex(szData, charsmax(szData), "Mod \r(Not selected)");
	menu_additem(menu, szData, index, 0);
		
	formatex(szData, charsmax(szData), "Map \r[%s Maps]", g_modnames[g_playernominatedid[id]]);
	menu_additem(menu, szData, index, 0);
	
	menu_display(id, menu);
	return PLUGIN_HANDLED;
}

public nominate_mainHandler(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	new szData[7], paccess, callback;

	menu_item_getinfo(menu, item, paccess, szData, charsmax(szData), _, 0, callback);
	menu_destroy(menu);
	
	new subkey = str_to_num(szData);
	
	switch(subkey)
	{
		case 1:
		{
			switch(item)
			{
				case 0:	cmdNominate(id);
				case 1:	mapNominateMenu(id, 0);
			}
		}
		case 2:
		{
			switch(item)
			{
				case 0:	cmdCancelnomMod(id);
				case 1:	cmdCancelnomMap(id);
			}
		}	
	}
	
	return PLUGIN_HANDLED;
}

log(const text[] = "", {Float,Sql,Result,_}:...)
{	
	if (get_cvar_num("mm_debug"))
	{
		new formattedText[1024];
		format_args(formattedText, 1023, 0);
		// grab the current game time
		new Float:gameTime = get_gametime();
		// log text to file
		log_to_file("_multimod.log", "{%3.4f} %s", gameTime, formattedText);
	}
	// not needed but gets rid of stupid compiler error
	if (text[0] == 0) return;
}

public plugin_natives(){
	register_library("multimod");
	register_native("multimod_get_mm_tag", "_get_mm_tag");
	register_native("multimod_get_mm_dir", "_get_mm_dir");
}

public _get_mm_tag(iPlugin, iParams){
	if(iParams != 2){
		log_error(AMX_ERR_PARAMS, "Plugin-id: #%d | (_get_mm_tag) Arguments: 2 are required!", iPlugin);
		return 0;
	}

	if(g_currentmodid == -1){
		set_string(1, "None", get_param(2));
		return 1;
	}

	if(g_nextmodselected) set_string(1, g_tag[g_nextmodid], get_param(2));
	else set_string(1, g_tag[g_currentmodid], get_param(2));

	return 1;
}

public _get_mm_dir(iPlugin, iParams){
	if(iParams != 2){
		log_error(AMX_ERR_PARAMS, "Plugin-id: #%d | (_get_mm_dir) Arguments: 2 are required!", iPlugin);
		return 0;
	}

	set_string(1, MULTIMOD_DIR, get_param(2));

	return 1;
}
