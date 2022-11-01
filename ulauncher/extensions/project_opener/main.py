import re
from functools import lru_cache
from itertools import chain
from pathlib import Path
from typing import Optional

from ulauncher.api.client.EventListener import EventListener
from ulauncher.api.client.Extension import Extension
from ulauncher.api.shared.action.RenderResultListAction import RenderResultListAction
from ulauncher.api.shared.action.RunScriptAction import RunScriptAction
from ulauncher.api.shared.event import KeywordQueryEvent
from ulauncher.api.shared.item.ExtensionResultItem import ExtensionResultItem


class ProjectOpenerExtension(Extension):
    def __init__(self):
        super().__init__()
        self.subscribe(KeywordQueryEvent, KeywordQueryEventListener())


class KeywordQueryEventListener(EventListener):
    def on_event(self, event, extension):
        items = []
        keyword = extension.preferences["project_kw"]

        type_editor_mapping = {
            "py": extension.preferences["editor_python"],
            "js": extension.preferences["editor_js"],
            "php": extension.preferences["editor_php"],
            None: extension.preferences["editor_default"],
        }

        project_name_query = event.query[len(keyword) + 1 :]
        for project_prefix in extension.preferences["project_dirs"].split(":"):
            for project_path in Path(project_prefix).expanduser().glob("*"):
                project_name = project_path.name
                if project_name_query in project_name:
                    project_type = self._get_project_type(project_path)
                    editor = type_editor_mapping[project_type]
                    items.append(
                        ExtensionResultItem(
                            icon=str(self._get_icon(editor)),
                            name=project_name,
                            description=f"Open {project_name} in {editor}",
                            on_enter=RunScriptAction(
                                f"#!/bin/bash\n{editor} $1", str(project_path)
                            ),
                        )
                    )

        return RenderResultListAction(items)

    @lru_cache
    def _get_project_type(self, proj_path: Path) -> Optional[str]:
        project_files = {
            *{str(x.name) for x in proj_path.glob("./*")},
            *{str(x.name) for x in proj_path.glob("./*/*")},
        }
        if {"package.json"} & project_files:
            return "js"
        elif {
            "Pipfile",
            "requirements.txt",
            "setup.py",
            "poetry.lock",
            "pydeps.txt",
        } & project_files:
            return "py"
        elif {"composer.json"} & project_files:
            return "php"
        elif {"index.html"} & project_files:
            # More vague, has an index.html
            return "js"

    @lru_cache
    def _get_icon(self, editor_name: str) -> str:
        search_paths = chain(
            Path("~/.local/share/applications")
            .expanduser()
            .glob(f"*{editor_name}*.desktop"),
            Path("/usr/share/applications").glob(f"*{editor_name}*.desktop"),
        )
        for desktop_file in search_paths:
            icon_search_results = re.search(r"Icon=(.*)", desktop_file.read_text())
            if icon_search_results:
                return icon_search_results.group(1)

        return "images/icon.svg"


if __name__ == "__main__":
    ProjectOpenerExtension().run()
