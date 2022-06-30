#include <cstrike>
#include <amxmodx>
#include <nvault>

new g_nvault
new bool:g_cansave[33]

public plugin_init()
{
	register_plugin("Save", "30.06.2022", "Oli")
	g_nvault = nvault_open("save")
}

public client_putinserver(id)
{
	load_data(id)
}


public client_disconnect(id)
{
	if (g_cansave[id])
		save_data(id)

	g_cansave[id] = false
}

public load_data(id)
{
	new szSteamID[35], iMoney
	get_user_authid(id, szSteamID, charsmax(szSteamID))

	iMoney = nvault_get(g_nvault, szSteamID)
	if (iMoney > 0)
		cs_set_user_money(id, iMoney)

	g_cansave[id] = true
}

public save_data(id)
{
	new szSteamID[35], szBuffer[32]
	get_user_authid(id, szSteamID, charsmax(szSteamID))

	num_to_str(cs_get_user_money(id), szBuffer, charsmax(szBuffer))
	nvault_set(g_nvault, szSteamID, szBuffer)
}

public plugin_end()
{
	nvault_close(g_nvault)
}