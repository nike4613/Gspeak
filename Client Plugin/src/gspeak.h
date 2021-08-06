/*
* Gspeak 2.0
* by Thendon.exe
* Sneaky Rocks
*/

#ifndef GSPEAK_H
#define GSPEAK_H

#ifdef WIN32
#define PLUGINS_EXPORTDLL __declspec(dllexport)
#else
#define PLUGINS_EXPORTDLL __attribute__ ((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

	PLUGINS_EXPORTDLL const char* ts3plugin_name();
	PLUGINS_EXPORTDLL const char* ts3plugin_version();
	PLUGINS_EXPORTDLL int ts3plugin_apiVersion();
	PLUGINS_EXPORTDLL const char* ts3plugin_author();
	PLUGINS_EXPORTDLL const char* ts3plugin_description();
	PLUGINS_EXPORTDLL void ts3plugin_setFunctionPointers(const struct TS3Functions funcs);
	PLUGINS_EXPORTDLL int ts3plugin_init();
	PLUGINS_EXPORTDLL void ts3plugin_shutdown();

	void gs_initClients(uint64 serverConnectionHandlerID, uint64 channelID);
	void gs_initStatus();
	void gs_setStatusName(uint64 serverConnectionHandlerID, anyID clientID, char* clientName);
	void gs_shutClients();
	void gs_shutStatus(); 
	void gs_setIdle();
	void gs_setActive(uint64 serverConnectionHandlerID, uint64 channelID);
	void gs_shutdown();
	bool gs_isMe(uint64 serverConnectionHandlerID, anyID clientID);
	void gs_criticalError(int errorCode);
	int gs_openMapFile(HANDLE *hMapFile, TCHAR *name, unsigned int buf_size);
	bool gs_searchChannel(uint64 serverConnectionHandlerID, anyID clientID);
	void gs_clientMoved(uint64 serverConnectionHandlerID, anyID clientID, uint64 channelID);
	bool gs_isChannel(uint64 serverConnectionHandlerID, uint64 channelID);
	void gs_scanClients(uint64 serverConnectionHandlerID);
	void gs_clientThread(uint64 serverConnectionHandlerID, uint64 channelID);
	void gs_statusThread();
	void gs_cmdCheck(uint64 serverConnectionHandlerID, anyID clientID);
	bool gs_nameCheck(uint64 serverConnectionHandlerID, anyID clientID);
	int gs_findClient(anyID clientID);

	PLUGINS_EXPORTDLL void ts3plugin_onClientMoveEvent(uint64 serverConnectionHandlerID, anyID clientID, uint64 oldChannelID, uint64 newChannelID, int visibility, const char* moveMessage); 
	PLUGINS_EXPORTDLL void ts3plugin_onClientMoveMovedEvent(uint64 serverConnectionHandlerID, anyID clientID, uint64 oldChannelID, uint64 newChannelID, int visibility, anyID moverID, const char* moverName, const char* moverUniqueIdentifier, const char* moveMessage);
	PLUGINS_EXPORTDLL void ts3plugin_onConnectStatusChangeEvent(uint64 serverConnectionHandlerID, int newStatus, unsigned int errorNumber);
	PLUGINS_EXPORTDLL void ts3plugin_onTalkStatusChangeEvent(uint64 serverConnectionHandlerID, int talkStatus, int isReceivedWhisper, anyID clientID);
	PLUGINS_EXPORTDLL void ts3plugin_onCustom3dRolloffCalculationClientEvent(uint64 serverConnectionHandlerID, anyID clientID, float distance, float* volume);
	//PLUGINS_EXPORTDLL void ts3plugin_onEditPlaybackVoiceDataEvent(uint64 serverConnectionHandlerID, anyID clientID, short* samples, int sampleCount, int channels);
	PLUGINS_EXPORTDLL void ts3plugin_onEditPostProcessVoiceDataEvent(uint64 serverConnectionHandlerID, anyID clientID, short* samples, int sampleCount, int channels, const unsigned int* channelSpeakerArray, unsigned int* channelFillMask);
	PLUGINS_EXPORTDLL void ts3plugin_onClientDisplayNameChanged(uint64 serverConnectionHandlerID, anyID clientID, const char* displayName, const char* uniqueClientIdentifier);

#ifdef __cplusplus
}
#endif

#endif
