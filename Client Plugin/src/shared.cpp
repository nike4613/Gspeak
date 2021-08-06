#include "shared.h"

bool gs_inChannel( Status const*status ) {
	return status->clientID > -1;
}

//Not realy save to say though
bool gs_gmodOnline(Status const*status) {
	return !(status->tslibV <= 0);
}

bool gs_tsOnline(Status const*status) {
	return !(status->gspeakV <= 0);
}