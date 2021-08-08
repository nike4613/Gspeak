#ifndef SHARED_H
#define SHARED_H

//#define RADIO_BUF 32
#define PASS_BUF 32
#define PLAYER_MAX 64
#define NAME_BUF 32

#define CMD_RENAME 1
#define CMD_FORCEMOVE 2
#define CMD_KICK 3
#define CMD_BAN 4
#define CMD_BUF 16

struct Client {
	short clientID;
	float pos[3];
	float volume_gm;
	float volume_ts;
	bool radio;
	bool talking;
	bool broadcasting;
	bool maybe_audible;
};

struct Status {
	short clientID;
	char name[NAME_BUF];
	short tslibV;
	short gspeakV;
	short radio_downsampler;
	short radio_distortion;
	float upward[3];
	float forward[3];
	float radio_volume;
	float radio_volume_noise;
	char password[PASS_BUF];
	bool talking;
	int command;
	bool hear_channel_commander;
	bool hear_unknown_clients;
	bool enabled;
};

bool gs_inChannel(Status const* status);
bool gs_gmodOnline(Status const* status);
bool gs_tsOnline(Status const* status);

#endif