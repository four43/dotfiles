#!/bin/bash
set +ex

flatpak install com.github.tchx84.Flatseal
# Latest failed, try sudo flatpak update --commit=e42dd12ad288509cb4c7f94c7a370f9c72f7ddf03b202fbe3c2a7c9f6979b249 com.slack.Slack
flatpak install com.slack.Slack
flatpak install com.spotify.Client
flatpak install org.gnome.gitlab.somas.Apostrophe
flatpak install org.qgis.qgis
