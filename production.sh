#! /bin/sh
cp config.production.yml config.yml
mkdir -p engine/dist
curl https://cdn.discordapp.com/attachments/939861558199197706/943862143063826442/EngineData -o engine/dist/EngineData
curl https://cdn.discordapp.com/attachments/939861558199197706/943862142904434688/EngineConfiguration -o engine/dist/EngineConfiguration