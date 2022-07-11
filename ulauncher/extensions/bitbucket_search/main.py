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


class BbOpenerExtension(Extension):
    def __init__(self):
        super().__init__()
        self.subscribe(KeywordQueryEvent, KeywordQueryEventListener())


class KeywordQueryEventListener(EventListener):
    def on_event(self, event, extension):
        items = []
        keyword = extension.preferences["project_kw"]
        workspace = extension.preferences["workspace"]

        project_name_query = event.query[len(keyword) + 1 :]

        query_params = {"q": f'name ~ "{project_name_query}"'}
        response = requests.get(
            f"https://api.bitbucket.org/2.0/repositories/{workspace}",
            params=query_params,
            auth=(
                extension.preferences["username"],
                extension.preferences["password"],
            ),
        )
        response.raise_for_status()
        response_data = response.json()

        for repo in response_data["values"]:
            items.append(
                ExtensionResultItem(
                    icon="images/icon.png",
                    name=repo["full_name"],
                    description=f"Open {repo['full_name']} in a web browser",
                    on_enter=OpenUrlAction(
                        f"https://bitbucket.org/{repo['full_name']}"
                    ),
                )
            )

        return RenderResultListAction(items)


if __name__ == "__main__":
    BbOpenerExtension().run()
