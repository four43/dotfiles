import os
import re
from functools import lru_cache
from itertools import chain
from pathlib import Path
from typing import Optional
import requests

from ulauncher.api.client.EventListener import EventListener
from ulauncher.api.client.Extension import Extension
from ulauncher.api.shared.action.OpenUrlAction import OpenUrlAction
from ulauncher.api.shared.action.RenderResultListAction import RenderResultListAction
from ulauncher.api.shared.event import KeywordQueryEvent
from ulauncher.api.shared.item.ExtensionResultItem import ExtensionResultItem


class CfOpenerExtension(Extension):
    def __init__(self):
        super().__init__()
        self.subscribe(KeywordQueryEvent, KeywordQueryEventListener())


class KeywordQueryEventListener(EventListener):
    def on_event(self, event, extension):
        items = []
        keyword = extension.preferences["project_kw"]
        subdomain = extension.preferences["subdomain"]

        page_query = event.query[len(keyword) + 1 :]

        query_params = {"cql": f'(title~"{page_query}*")'}
        response = requests.get(
            f"https://{subdomain}.atlassian.net/wiki/rest/api/content/search",
            params=query_params,
            auth=(
                extension.preferences["email"],
                extension.preferences["api_token"],
            ),
        )
        response.raise_for_status()
        response_data = response.json()

        for page in response_data["results"]:
            items.append(
                ExtensionResultItem(
                    icon="images/icon.png",
                    name=page["title"],
                    description=f"Open {page['title']} in a web browser",
                    on_enter=OpenUrlAction(
                        f"https://{subdomain}.atlassian.net/wiki{page['_links']['webui']}"
                    ),
                )
            )

        return RenderResultListAction(items)


if __name__ == "__main__":
    CfOpenerExtension().run()
