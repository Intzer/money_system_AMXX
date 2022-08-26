#include <amxmodx>
#include <nvault>
#include <sqlx>

#if AMXX_VERSION_NUM < 183
	#include <colorchat>
	#define create_cvar register_cvar
#endif

#define CONFIG_FILE "plugin-money_system"
#define TASK_MESSAGE 25252

new g_money[33]
new bool:g_cansave[33]
new bool:g_newuser[33]
new g_nvault
new Handle:g_mysql_tuple

new ms_use_mysql
new ms_mysql_host[128]
new ms_mysql_user[128]
new ms_mysql_password[128]
new ms_mysql_dbname[128]
new ms_money_limit

public plugin_init()
{
	register_plugin("Money System", "26.08.2022", "Oli")

	create_cvar("ms_use_mysql", "0")
	create_cvar("ms_mysql_host", "localhost")
	create_cvar("ms_mysql_user", "root")
	create_cvar("ms_mysql_password", "")
	create_cvar("ms_mysql_dbname", "dbname")
	create_cvar("ms_money_limit", "1000")

	server_cmd("exec addons/amxmodx/configs/plugins/%s.cfg", CONFIG_FILE)
	server_exec()
	handle_cvars()
}

public plugin_natives()
{
	register_native("ms_set_user_money", "native_ms_set_user_money", 1)
	register_native("ms_get_user_money", "native_ms_get_user_money", 1)
}

public native_ms_set_user_money(id, amount) g_money[id] = amount
public native_ms_get_user_money(id) return g_money[id]

public handle_cvars()
{
	ms_use_mysql = get_cvar_num("ms_use_mysql")
	get_cvar_string("ms_mysql_host", ms_mysql_host, charsmax(ms_mysql_host))
	get_cvar_string("ms_mysql_user", ms_mysql_user, charsmax(ms_mysql_user))
	get_cvar_string("ms_mysql_password", ms_mysql_password, charsmax(ms_mysql_password))
	get_cvar_string("ms_mysql_dbname", ms_mysql_dbname, charsmax(ms_mysql_dbname))
	ms_money_limit = get_cvar_num("ms_money_limit")

	if (ms_use_mysql)
		sql_init()
	else
		g_nvault = nvault_open("money_system")
}

public sql_init()
{
	g_mysql_tuple = SQL_MakeDbTuple(ms_mysql_host, ms_mysql_user, ms_mysql_password, ms_mysql_dbname)

	new iError, szError[512]
	new Handle:mysql_connection = SQL_Connect(g_mysql_tuple, iError, szError, charsmax(szError))
	if (mysql_connection == Empty_Handle)
	{
		SQL_FreeHandle(g_mysql_tuple)
		set_fail_state(szError)
	}
	SQL_FreeHandle(mysql_connection)

	new szQuery[512]
	formatex(szQuery, charsmax(szQuery), "CREATE TABLE IF NOT EXISTS `money_system` (`id` INT NOT NULL AUTO_INCREMENT , `steam_id` VARCHAR(100) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL , `money` INT NOT NULL , PRIMARY KEY (`id`)) ENGINE = InnoDB CHARSET=utf8 COLLATE utf8_general_ci;")
	SQL_ThreadQuery(g_mysql_tuple, "ignore_handler", szQuery)
}

public client_putinserver(id)
{
	load_data(id)
}

public client_disconnect(id)
{
	if (g_cansave[id])
		save_data(id)

	g_money[id] = 0
	g_cansave[id] = false
	g_newuser[id] = false
	remove_task(id+TASK_MESSAGE)
}

public load_data(id)
{
	new szSteamID[35]
	get_user_authid(id, szSteamID, charsmax(szSteamID))

	if (ms_use_mysql)
	{
		new szSteamID_escaped[70]
		mysql_escape_string(szSteamID_escaped, charsmax(szSteamID_escaped), szSteamID)

		new szQuery[256]
		formatex(szQuery, charsmax(szQuery), "SELECT * FROM `money_system` WHERE `steam_id` = '%s'", szSteamID_escaped)

		new iData[2]
		iData[0] = id
		iData[1] = get_user_userid(id)

		SQL_ThreadQuery(g_mysql_tuple, "load_data_handler", szQuery, iData, sizeof(iData))
	}
	else
	{
		g_money[id] = min(ms_money_limit, nvault_get(g_nvault, szSteamID))
		g_cansave[id] = true
		get_message_pre(id)
	}
}

public load_data_handler(failstate, Handle:query, error[], errnum, data[], size, Float:queuetime)
{
	if (failstate != TQUERY_SUCCESS)
	{
		log_amx(error)
		return PLUGIN_HANDLED
	}

	new id = data[0]

	if (!is_user_connected(id))
		return PLUGIN_HANDLED

	if (get_user_userid(id) != data[1])
		return PLUGIN_HANDLED

	if (SQL_NumResults(query) > 0)
		g_money[id] = min(ms_money_limit, SQL_ReadResult(query, 2))
	else
		g_newuser[id] = true

	g_cansave[id] = true
	get_message_pre(id)
	return PLUGIN_HANDLED
}

public save_data(id)
{
	new szSteamID[35], szBuffer[32]
	get_user_authid(id, szSteamID, charsmax(szSteamID))

	if (ms_use_mysql)
	{
		new szSteamID_escaped[70]
		mysql_escape_string(szSteamID_escaped, charsmax(szSteamID_escaped), szSteamID)

		new szQuery[256]
		if (g_newuser[id])
			formatex(szQuery, charsmax(szQuery), "INSERT INTO `money_system` (`steam_id`, `money`) values ('%s', '%d')", szSteamID_escaped, g_money[id])
		else
			formatex(szQuery, charsmax(szQuery), "UPDATE `money_system` SET `money` = '%d' WHERE `steam_id` = '%s'", g_money[id], szSteamID_escaped)
		
		SQL_ThreadQuery(g_mysql_tuple, "ignore_handler", szQuery)
	}
	else
	{
		num_to_str(g_money[id], szBuffer, charsmax(szBuffer))
		nvault_set(g_nvault, szSteamID, szBuffer)
	}
}

public ignore_handler(failstate, Handle:query, error[], errnum, data[], size, Float:queuetime)
{
	if (failstate != TQUERY_SUCCESS)
		log_amx(error)

	return PLUGIN_HANDLED
}

public get_message_pre(id)
{
	set_task(5.0, "get_message", id+TASK_MESSAGE)
}

public get_message(taskid)
{
	new id = taskid-TASK_MESSAGE
	client_print_color(id, 0, "^4[SAVE] ^1Сохранение монет активировано. Лимит сохранения - ^3%d^1!", ms_money_limit)
}

public plugin_end()
{
	if (ms_use_mysql)
		SQL_FreeHandle(g_mysql_tuple)
	else
		nvault_close(g_nvault)
}

stock mysql_escape_string(dest[], len, src[])
{
    copy(dest, len, src)

    replace_all(dest, len, "\", "\\")
    replace_all(dest, len, "\0", "\\0")
    replace_all(dest, len, "\r", "\\r")
    replace_all(dest, len, "\n", "\\n")
    replace_all(dest, len, "\x1a", "\Z")
    replace_all(dest, len, "'", "\'")
    replace_all(dest, len, "^"", "\^"")
}