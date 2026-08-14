# Builder is ubuntu-based because we need i386 libs
FROM steamcmd/steamcmd:ubuntu-26 AS builder

# Install prerequisites to download steamcmd
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl tar
WORKDIR /root/installer

# Download and unpack installer
# If some certificate expires then --insecure can be added
RUN curl -sqL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz | tar zxvf -

FROM debian:bookworm-slim

# The TMOD Version. Ensure that you follow the correct format. Version releases can be found at https://github.com/tModLoader/tModLoader/releases if you're lost.
ARG TMOD_VERSION=v2026.06.3.6
ENV UPDATE_NOTICE="true"
ENV TMOD_SHUTDOWN_MESSAGE="Server is shutting down NOW!"
ENV TMOD_AUTOSAVE_INTERVAL="10"
ENV TMOD_AUTODOWNLOAD=""
ENV TMOD_ENABLEDMODS=""
ENV TMOD_USECONFIGFILE="No"

#--------- CONFIG SECTION --------- #
# The following environment variables will configure common settings for the tModLoader server.

ENV TMOD_MOTD="A tModLoader server powered by Docker!"
ENV TMOD_PASS="docker"
ENV TMOD_MAXPLAYERS="8"
ENV TMOD_WORLDNAME="Docker"
ENV TMOD_WORLDSIZE="3"
ENV TMOD_WORLDSEED="Docker"
ENV TMOD_DIFFICULTY="1"
ENV TMOD_SECURE="0"
ENV TMOD_LANGUAGE="en-US"
ENV TMOD_NPCSTREAM="60"
ENV TMOD_UPNP="0"
ENV TMOD_PRIORITY="1"
ENV TMOD_PORT="7777"

# JOURNEY MODE POWER PERMISSIONS

ENV TMOD_JOURNEY_SETFROZEN="0"
ENV TMOD_JOURNEY_SETDAWN="0"
ENV TMOD_JOURNEY_SETNOON="0"
ENV TMOD_JOURNEY_SETDUSK="0"
ENV TMOD_JOURNEY_SETMIDNIGHT="0"
ENV TMOD_JOURNEY_GODMODE="0"
ENV TMOD_JOURNEY_WIND_STRENGTH="0"
ENV TMOD_JOURNEY_RAIN_STRENGTH="0"
ENV TMOD_JOURNEY_TIME_SPEED="0"
ENV TMOD_JOURNEY_RAIN_FROZEN="0"
ENV TMOD_JOURNEY_WIND_FROZEN="0"
ENV TMOD_JOURNEY_PLACEMENT_RANGE="0"
ENV TMOD_JOURNEY_SET_DIFFICULTY="0"
ENV TMOD_JOURNEY_BIOME_SPREAD="0"
ENV TMOD_JOURNEY_SPAWN_RATE="0"

RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y libc6:i386 libstdc++6:i386 \
    && rm -rf /var/lib/apt/lists/*

# Copy steamcmd and its required libs from the builder
COPY --from=builder /root/installer/steamcmd.sh /usr/lib/games/steam/
COPY --from=builder /root/installer/linux32/steamcmd /usr/lib/games/steam/linux32/steamcmd
COPY --from=builder /usr/games/steamcmd /usr/bin/steamcmd
COPY --from=builder /etc/ssl/certs /etc/ssl/certs
COPY --from=builder /lib/i386-linux-gnu /lib/i386-linux-gnu
COPY --from=builder /root/installer/linux32/libstdc++.so.6 /lib/i386-linux-gnu/
RUN chown -R root:root /usr/bin/ /etc/ssl/certs /lib/ /usr/lib/

RUN groupadd -g 10000 nonpriv && \
    useradd -u 10000 -g nonpriv -d /home/nonpriv -m -s /usr/sbin/nologin nonpriv

RUN apt-get update \
    && apt-get install -y wget unzip tmux bash libsdl2-2.0-0 libicu72

RUN mkdir /data
RUN mkdir /data/tModLoader
RUN mkdir /data/tModLoader/Worlds
RUN mkdir /data/tModLoader/Mods
RUN mkdir /data/steamMods

EXPOSE 7777

RUN chown -R 10000:10000 /data

WORKDIR /terraria-server

RUN /usr/lib/games/steam/steamcmd.sh /terraria-server +login anonymous +quit

RUN wget https://github.com/tModLoader/tModLoader/releases/download/${TMOD_VERSION}/tModLoader.zip
RUN unzip -o tModLoader.zip \
    && rm tModLoader.zip

COPY DotNetInstall.sh ./LaunchUtils
COPY entrypoint.sh .
COPY inject.sh /usr/local/bin/inject
COPY autosave.sh .
COPY prepare-config.sh .

RUN chmod 755 ./LaunchUtils/DotNetInstall.sh \
    && chmod 755 ./LaunchUtils/ScriptCaller.sh \
    && chmod 755 ./entrypoint.sh \
    && chmod 755 ./autosave.sh \
    && chmod 755 /usr/local/bin/inject \
    && chmod 755 ./prepare-config.sh \
    && chmod 755 ./start-tModLoaderServer.sh

RUN ./LaunchUtils/DotNetInstall.sh

RUN chown -R 10000:10000 /terraria-server

USER nonpriv
ENTRYPOINT ["./entrypoint.sh"]
