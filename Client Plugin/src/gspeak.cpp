/*
* Gspeak 2.6
* by Thendon.exe
* Sneaky Rocks
*/

#ifdef _WIN32
#pragma warning (disable : 4100)  /* Disable Unreferenced parameter warning */
#include <Windows.h>
#endif

#include <stdio.h>
#include <thread>
#include <ts3_functions.h>
#include <teamspeak/public_errors.h>
#include <teamspeak/public_errors_rare.h>
#include <teamspeak/public_definitions.h>
#include <teamspeak/public_rare_definitions.h>
#include "shared.h"
#include "gspeak.h"
#include <string>
#include <atomic>
#include <mutex>

static struct TS3Functions ts3Functions;

#ifdef _WIN32
#define _strcpy(dest, destSize, src) strcpy_s(dest, destSize, src)
#define snprintf sprintf_s
#else
#define _strcpy(dest, destSize, src) { strncpy(dest, src, destSize-1); (dest)[destSize-1] = '\0'; }
#endif
#define PLUGIN_API_VERSION 24

#define PATH_BUFSIZE 512
#define COMMAND_BUFSIZE 128
#define INFODATA_BUFSIZE 128
#define SERVERINFO_BUFSIZE 256
#define CHANNELINFO_BUFSIZE 512
#define RETURNCODE_BUFSIZE 128

#define GSPEAK_VERSION 2700
#define SCAN_SPEED 100
#define VOLUME_MAX 1800
#define SHORT_SIZE 32767

static char* pluginID = NULL;

#ifdef _WIN32
static int wcharToUtf8(const wchar_t* str, char** result) {
	int outlen = WideCharToMultiByte(CP_UTF8, 0, str, -1, 0, 0, 0, 0);
	*result = (char*)malloc(outlen);
	if (WideCharToMultiByte(CP_UTF8, 0, str, -1, *result, outlen, 0, 0) == 0) {
		*result = NULL;
		return -1;
	}
	return 0;
}
#endif

struct Client *clients;
struct Status *status;

std::mutex statusLock;
std::mutex clientsLock;

HANDLE hMapFileO;
HANDLE hMapFileV;

TCHAR clientName[] = TEXT("Local\\GMapO");
TCHAR statusName[] = TEXT("Local\\GMapV");

std::atomic_bool statusThreadActive;
std::atomic_bool statusThreadBreak;
std::atomic_bool clientThreadActive;
std::atomic_bool clientThreadBreak;

using namespace std;
//*************************************
// REQUIRED TEAMSPEAK3 FUNCTIONS
//*************************************

const char* ts3plugin_name() {
#ifdef _WIN32
	static char* result = NULL;
	if (!result) {
		const wchar_t* name = L"Gspeak2";
		if (wcharToUtf8(name, &result) == -1) {
			return "Gspeak2";
		}
	}
	return result;
#else
	return "Gspeak2";
#endif
}

const char* ts3plugin_version() {
	return "2.6";
}

int ts3plugin_apiVersion() {
	return PLUGIN_API_VERSION;
}

const char* ts3plugin_author() {
	return "Sneaky Rocks GbR";
}

const char* ts3plugin_description() {
	return "This plugin connects Garry's Mod with Teamspeak3";
}

void ts3plugin_setFunctionPointers(const struct TS3Functions funcs) {
	ts3Functions = funcs;
}

int ts3plugin_init() {
	printf("[Gspeak] init\n");

	std::scoped_lock _lock{ statusLock };

	//Open shared memory struct: status
	if (gs_openMapFile(&hMapFileV, statusName, sizeof(Status)) == 1) {
		return 1;
	} 
	//status = (Status*)malloc(sizeof(Status));
	status = (Status*)MapViewOfFile(hMapFileV, FILE_MAP_ALL_ACCESS, 0, 0, sizeof(Status));
	if (status == NULL) {
		gs_criticalError(GetLastError());
		printf("[Gspeak] could not view file\n");
		CloseHandle(hMapFileV);
		hMapFileV = NULL;
		return 1;
	}
	status->gspeakV = GSPEAK_VERSION;
	status->command = 0;
	status->clientID = -1;

	//Check for Gspeak Channel
	uint64 serverID = ts3Functions.getCurrentServerConnectionHandlerID();
	anyID clientID;
	if (ts3Functions.getClientID(serverID, &clientID) == ERROR_ok) {
		uint64 channelID;
		if (ts3Functions.getChannelOfClient(serverID, clientID, &channelID) == ERROR_ok) {
			if (gs_isChannel(serverID, channelID)) {
				gs_setActive(serverID, channelID);
				return 0;
			}
		}
	}

	gs_setIdle();
	return 0;
}

void ts3plugin_shutdown() {
	printf("[Gspeak] shutdown\n");

	thread wait(gs_shutdown);
	wait.join();

	if (pluginID) {
		free(pluginID);
		pluginID = NULL;
	}
}

//*************************************
// GSPEAK FUNCTIONS
//*************************************

void gs_initClients(uint64 serverConnectionHandlerID, uint64 channelID) {
	clientThreadBreak.store(false, std::memory_order_release);
	thread(gs_clientThread, serverConnectionHandlerID, channelID).detach();
}

void gs_initStatus() {
	statusThreadBreak.store(false, std::memory_order_release);
	thread(gs_statusThread).detach();
}

void gs_shutClients() {
	clientThreadBreak.store(true, std::memory_order_release);
}

void gs_shutStatus() {
	statusThreadBreak.store(true, std::memory_order_release);
}

void gs_setIdle() {
	gs_shutClients();
	gs_initStatus();
}

void gs_setActive(uint64 serverConnectionHandlerID, uint64 channelID) {
	gs_shutStatus();
	gs_initClients(serverConnectionHandlerID, channelID);
}

void gs_shutdown() {
	{
		std::scoped_lock _lock{ statusLock };
		status->gspeakV = -1;
	}

	if (clientThreadActive.load(std::memory_order_acquire)) gs_shutClients();
	if (statusThreadActive.load(std::memory_order_acquire)) gs_shutStatus();
	while (true) {
		if (!clientThreadActive.load(std::memory_order_acquire) && !statusThreadActive.load(std::memory_order_acquire)) {
			std::scoped_lock _lock{ statusLock, clientsLock };
			UnmapViewOfFile(status);
			CloseHandle(hMapFileV);
			hMapFileV = NULL;
			status = NULL;
			break;
		}
		this_thread::sleep_for(chrono::milliseconds(SCAN_SPEED));
	}
}

void gs_criticalError(int errorCode) {
	char msg[48];
	sprintf_s(msg, "[Gspeak] critical error - Code: %d", errorCode);
	ts3Functions.printMessageToCurrentTab(msg);
	printf("%s\n", msg);
}

int gs_openMapFile(HANDLE *hMapFile, TCHAR const* name, unsigned int buf_size) {
	*hMapFile = OpenFileMapping(FILE_MAP_ALL_ACCESS, FALSE, name);
	if (*hMapFile == NULL) {
		int code = GetLastError();
		printf("[Gspeak] error code - %d\n", code);
		if (code == 5) {
			ts3Functions.printMessageToCurrentTab("[Gspeak] access denied - restart Teamspeak3 with Administrator!");
			return 1;
		}
		else if (code == 2) {
			*hMapFile = CreateFileMapping(INVALID_HANDLE_VALUE, NULL, PAGE_READWRITE, 0, buf_size, name);
			if (*hMapFile == NULL) {
				gs_criticalError(GetLastError());
				return 1;
			}
		}
		else {
			gs_criticalError(GetLastError());
			return 1;
		}
	}
	return 0;
}

bool gs_searchChannel(Status const* status, uint64 serverConnectionHandlerID, anyID clientID) {
	uint64 *channels;
	if (ts3Functions.getChannelList(serverConnectionHandlerID, &channels) == ERROR_ok) {
		uint64 localChannelID;
		if (ts3Functions.getChannelOfClient(serverConnectionHandlerID, clientID, &localChannelID) != ERROR_ok) 
			return false;

		if (gs_isChannel(serverConnectionHandlerID, localChannelID))
			return true;

		for (int i = 0; channels[i]; i++) {
			if (channels[i] == localChannelID)
				continue;

			if (gs_isChannel(serverConnectionHandlerID, channels[i])) {
				if (ts3Functions.requestClientMove(serverConnectionHandlerID, clientID, channels[i], status->password, NULL) == ERROR_ok)
					return true;
			}
		}
	}
	return false;
}

void gs_clientMoved(uint64 serverConnectionHandlerID, anyID clientID, uint64 channelID) {
	anyID localClientID;
	if (ts3Functions.getClientID(serverConnectionHandlerID, &localClientID) != ERROR_ok) return;
	uint64 localChannelID;
	if (ts3Functions.getChannelOfClient(serverConnectionHandlerID, localClientID, &localChannelID) != ERROR_ok) return;
	if (localChannelID == 0 || channelID == 0) return; //Leaving Server or closing Teamspeak

	if (localClientID == clientID) {
		if (gs_isChannel(serverConnectionHandlerID, channelID))
			gs_setActive(serverConnectionHandlerID, channelID);
		else if (clientThreadActive.load(std::memory_order_acquire))
			gs_setIdle();
	}
}

bool gs_isChannel(uint64 serverConnectionHandlerID, uint64 channelID) {
	char *chname;
	if (ts3Functions.getChannelVariableAsString(serverConnectionHandlerID, channelID, CHANNEL_NAME, &chname) == ERROR_ok) {
		std::string str(chname);
		if (str.find("Gspeak") != string::npos) { //MAY CHANGE TO ID
			return true;
		}
	}
	return false;
}

bool gs_canAlwaysHearClient(Status const* status, uint64 serverConnectionHandlerID, anyID clientId) {
	int isCommander;
	return status->hear_channel_commander
		&& ts3Functions.getClientVariableAsInt(serverConnectionHandlerID, clientId, CLIENT_IS_CHANNEL_COMMANDER, &isCommander) == ERROR_ok
		&& isCommander;
}

bool gs_canAlwaysHearGspeakClient(Status const* status, uint64 serverConnectionHandlerID, Client const* client) {
	return client->broadcasting || gs_canAlwaysHearClient(status, serverConnectionHandlerID, client->clientID);
}

void gs_scanClients(Status const* status, Client const* clients, uint64 serverConnectionHandlerID) {
	TS3_VECTOR position;
	for (int i = 0; clients[i].clientID != 0 && i < PLAYER_MAX; i++) {
		if (gs_canAlwaysHearGspeakClient(status, serverConnectionHandlerID, &clients[i])) {
			TS3_VECTOR zero{ 0.0, 0.0, 0.0 };
			ts3Functions.channelset3DAttributes(serverConnectionHandlerID, clients[i].clientID, &zero);
			continue;
		}

		position.x = clients[i].pos[0];
		position.y = clients[i].pos[1];
		position.z = clients[i].pos[2];
		ts3Functions.channelset3DAttributes(serverConnectionHandlerID, clients[i].clientID, &position);
	}
}

std::mutex cmdLock;

void gs_cmdCheck(Status* status, uint64 serverConnectionHandlerID, anyID clientID) {
	std::scoped_lock _lock{ cmdLock };

	if (status->command <= 0)
		return;

	bool success;
	switch (status->command) {
	case CMD_RENAME:
		success = gs_nameCheck(status, serverConnectionHandlerID, clientID);
		break;
	case CMD_FORCEMOVE:
		success = gs_searchChannel(status, serverConnectionHandlerID, clientID);
		break;
	}

	if (!success)
	{
		status->command = -2;
		return;
	}

	status->command = -1;
}
/*
void gs_kickClient(uint64 serverConnectionHandlerID, anyID clientID) {
	ts3Functions.requestClientKickFromChannel(serverConnectionHandlerID, clientID, "Gspeak Kick Command", NULL);
}
*/
bool gs_nameCheck(Status const* status, uint64 serverConnectionHandlerID, anyID clientID) {
	if (!gs_inChannel( status ))
		return false;

	char* clientName;
	ts3Functions.getClientVariableAsString(serverConnectionHandlerID, clientID, CLIENT_NICKNAME, &clientName);

	if (strlen(status->name) < 1)
		return true;
	if (strcmp(clientName, status->name) == 0)
		return true;

	if (ts3Functions.setClientSelfVariableAsString(serverConnectionHandlerID, CLIENT_NICKNAME, status->name) != ERROR_ok)
		return false;

	ts3Functions.flushClientSelfUpdates(serverConnectionHandlerID, NULL);
	return true;
}

void gs_setStatusName(Status* status, uint64 serverConnectionHandlerID, anyID clientID, char* clientName = NULL ) {
	if (!gs_isMe(serverConnectionHandlerID, clientID))
		return;
	if(clientName == NULL)
		ts3Functions.getClientVariableAsString(serverConnectionHandlerID, clientID, CLIENT_NICKNAME, &clientName);

	//causing crashes for special characters
	strcpy_s(status->name, NAME_BUF * sizeof(char), clientName);
}

void gs_clientThread(uint64 serverConnectionHandlerID, uint64 channelID) {
	printf("[Gspeak] clientThread created\n");

	{
		std::scoped_lock _lock{ clientsLock };
		//Open shared memory struct: clients
		if (gs_openMapFile(&hMapFileO, clientName, sizeof(Client) * PLAYER_MAX) == 1) {
			printf("[Gspeak] openMapFile error\n");
			return;
		}
		clients = (Client*)MapViewOfFile(hMapFileO, FILE_MAP_ALL_ACCESS, 0, 0, sizeof(Client) * PLAYER_MAX);
		if (clients == NULL) {
			gs_criticalError(GetLastError());
			printf("[Gspeak] could not view file\n");
			CloseHandle(hMapFileO);
			hMapFileO = NULL;
			return;
		}

		clientThreadActive.store(true, std::memory_order_release);
		printf("[Gspeak] has been loaded successfully\n");
		ts3Functions.printMessageToCurrentTab("[Gspeak] has been loaded successfully!");
	}

	TS3_VECTOR zero = { 0.0f, 0.0f, 0.0f };
	TS3_VECTOR forward;
	TS3_VECTOR upward;

	anyID clientID;
	ts3Functions.getClientID(serverConnectionHandlerID, &clientID);
	{
		std::scoped_lock _lock{ statusLock };
		gs_setStatusName(status, serverConnectionHandlerID, clientID);
	}

	while (!clientThreadBreak.load(std::memory_order_acquire)) {
		{
			std::scoped_lock _lock{ statusLock, clientsLock };

			ts3Functions.getClientID(serverConnectionHandlerID, &clientID);
			if (clientID != status->clientID) {
				status->clientID = clientID;
			}
			gs_cmdCheck(status, serverConnectionHandlerID, clientID);

			forward.x = status->forward[0];
			forward.y = status->forward[1];
			forward.z = status->forward[2];
			upward.x = status->upward[0];
			upward.y = status->upward[1];
			upward.z = status->upward[2];
			ts3Functions.systemset3DListenerAttributes(serverConnectionHandlerID, &zero, &forward, &upward);

			gs_scanClients(status, clients, serverConnectionHandlerID);
		}

		this_thread::sleep_for(chrono::milliseconds(SCAN_SPEED));
	}	

	clientThreadActive.store(false, std::memory_order_release);

	std::scoped_lock _lock{ clientsLock };
	UnmapViewOfFile(clients);
	CloseHandle(hMapFileO);
	hMapFileO = NULL;
	clients = NULL;
	ts3Functions.printMessageToCurrentTab("[Gspeak] has been shut down!");

	status->clientID = -1;
	printf("[Gspeak] clientThread destroyed\n");
}

void gs_statusThread() {
	printf("[Gspeak] statusThread created\n");
	statusThreadActive.store(true, std::memory_order_release);
	while (!statusThreadBreak.load(std::memory_order_acquire)) {
		//Gmod initialized
		if (status->tslibV > 0) {
			uint64 serverID = ts3Functions.getCurrentServerConnectionHandlerID();
			anyID clientID;
			if (ts3Functions.getClientID(serverID, &clientID) == ERROR_ok) {
				gs_cmdCheck(status, serverID, clientID);
			}
		}

		this_thread::sleep_for(chrono::milliseconds(SCAN_SPEED));
	}
	statusThreadActive.store(false, std::memory_order_release);
	printf("[Gspeak] statusThread destroyed\n");
}

int gs_findClient(Client* clients, anyID clientID) {
	for (int i = 0; clients[i].clientID != 0 && i < PLAYER_MAX; i++) {
		if (clients[i].clientID == clientID) return i;
	}
	return -1;
}

void ts3plugin_onClientDisplayNameChanged(uint64 serverConnectionHandlerID, anyID clientID, const char* displayName, const char* uniqueClientIdentifier) {
	std::scoped_lock _lock{ statusLock };
	gs_setStatusName(status, serverConnectionHandlerID, clientID, (char*)displayName);
}

void ts3plugin_onClientMoveEvent(uint64 serverConnectionHandlerID, anyID clientID, uint64 oldChannelID, uint64 newChannelID, int visibility, const char* moveMessage) {
	gs_clientMoved(serverConnectionHandlerID, clientID, newChannelID);
}

void ts3plugin_onClientMoveMovedEvent(uint64 serverConnectionHandlerID, anyID clientID, uint64 oldChannelID, uint64 newChannelID, int visibility, anyID moverID, const char* moverName, const char* moverUniqueIdentifier, const char* moveMessage) {
	gs_clientMoved(serverConnectionHandlerID, clientID, newChannelID);
}

void ts3plugin_onConnectStatusChangeEvent(uint64 serverConnectionHandlerID, int newStatus, unsigned int errorNumber) {
	if (newStatus == STATUS_DISCONNECTED)
		if (clientThreadActive)
			gs_setIdle();

	if (newStatus == STATUS_CONNECTION_ESTABLISHED && errorNumber == ERROR_ok){
		//ALL FINE
	}
}

bool gs_isMe(uint64 serverConnectionHandlerID, anyID clientID) {
	anyID localClientID;
	ts3Functions.getClientID(serverConnectionHandlerID, &localClientID);
	if (localClientID == clientID) return true;
	return false;
}

void ts3plugin_onTalkStatusChangeEvent(uint64 serverConnectionHandlerID, int talkStatus, int isReceivedWhisper, anyID clientID) {
	std::scoped_lock _lock{ clientsLock, statusLock };

	if (!clientThreadActive.load(std::memory_order_acquire)) return;

	if (gs_isMe(serverConnectionHandlerID, clientID)) {
		if (talkStatus == STATUS_TALKING) status->talking = true;
		else status->talking = false;
	}
	else {
		int it = gs_findClient(clients, clientID);
		if (it > -1) {
			if (talkStatus != STATUS_TALKING) clients[it].talking = false;
		}
	}
}

void ts3plugin_onCustom3dRolloffCalculationClientEvent(uint64 serverConnectionHandlerID, anyID clientID, float distance, float* volume) {
	if (!clientThreadActive.load(std::memory_order_acquire)) return;
	*volume = 1.0f;
}

void ts3plugin_onEditPostProcessVoiceDataEvent(uint64 serverConnectionHandlerID, anyID clientID, short* samples, int sampleCount, int channels, const unsigned int* channelSpeakerArray, unsigned int* channelFillMask) {
	std::scoped_lock _lock{ clientsLock, statusLock };
	
	if (!clientThreadActive.load(std::memory_order_acquire)) return;
	if (!status->enabled) return;

	int it = gs_findClient(clients, clientID);

	clients[it].volume_ts = 0;

	bool alwaysHear = gs_canAlwaysHearClient(status, serverConnectionHandlerID, clientID);

	if (alwaysHear) return;

	if (it < 0) { // we don't know about the client
		// if we're supposed to *hear* those unknown clients, then exit early
		if (status->hear_unknown_clients) return;
		// otherwise, clear their samples so they're inaudible
		for (int i = 0; i < sampleCount; i++) {
			short sample_it = i * channels;
			for (int j = 0; j < channels; j++) {
				samples[sample_it + j] = 0;
			}
		}
	} else {
		// otherwise, we know about the client
		if (clients[it].talking != true) clients[it].talking = true;

		// if the client is broadcasting, then we don't want to do any more work
		if (clients[it].broadcasting) return;

		//If volume is in a reasonable range, and the client is supposed to be heard
		if (clients[it].volume_gm > 0 && clients[it].volume_gm <= 1 && clients[it].maybe_audible) {
			float sum = 0;
			for (int i = 0; i < sampleCount; i++) {
				unsigned short sample_it = i * channels;
				//Average volume detection for mouth move animation
				if (samples[sample_it] > VOLUME_MAX) sum += VOLUME_MAX;
				else sum += abs(samples[sample_it]);

				if (clients[it].radio) {
					if (i % status->radio_downsampler == 0) {
						//Noise
						float noise = (((float)rand() / RAND_MAX) * SHORT_SIZE * 2) - SHORT_SIZE;
						for (int j = 0; j < channels; j++) {
							//Distortion
							short sample_new = static_cast<short>(
								(samples[sample_it] > status->radio_distortion
									? status->radio_distortion
									: samples[sample_it] < status->radio_distortion * (-1)
									? status->radio_distortion * (-1)
									: samples[sample_it])
								* status->radio_volume * clients[it].volume_gm);
							short sample_noise = (short)(sample_new + noise * status->radio_volume_noise);
							//Downsampling future samples
							bool temp_bool = false;
							for (int n = 0; n < status->radio_downsampler; n++) {
								int temp_it = sample_it + j + n * channels;
								if (temp_bool) {
									samples[temp_it] = sample_noise;
									temp_bool = false;
								}
								else {
									samples[temp_it] = sample_new;
									temp_bool = true;
								}
							}
						}
					}
				} else {
					for (int j = 0; j < channels; j++) {
						samples[sample_it + j] = (short)(samples[sample_it + j] * clients[it].volume_gm);
					}
				}
			}
			//Sending average volume to Gmod
			clients[it].volume_ts = sum / sampleCount / VOLUME_MAX;
			return;
		}
	}
}