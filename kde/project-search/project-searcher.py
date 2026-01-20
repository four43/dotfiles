#!/usr/bin/env python3
"""
KRunner Project Searcher Plugin

Searches for projects in ~/projects/[group]/[project] and opens them in VSCode.
Implements the KRunner DBus interface for integration with KDE.
"""

import os
import sys
import subprocess
from pathlib import Path
from typing import List, Tuple

import dbus
import dbus.service
import dbus.mainloop.glib
from gi.repository import GLib

# Configuration
PROJECTS_BASE_DIR = os.path.expanduser("~/projects")
TRIGGER_KEYWORDS = ['project', 'proj', 'p']
VSCODE_COMMAND = 'code'

# DBus configuration
BUS_NAME = 'org.kde.runner.projectsearcher'
OBJECT_PATH = '/runner'
INTERFACE_NAME = 'org.kde.krunner1'


class ProjectSearcher(dbus.service.Object):
    """KRunner plugin for searching and opening projects."""

    def __init__(self):
        """Initialize the DBus service."""
        dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)

        session_bus = dbus.SessionBus()
        bus_name = dbus.service.BusName(BUS_NAME, bus=session_bus)
        super().__init__(bus_name, OBJECT_PATH)

        self.projects_cache = {}
        self._scan_projects()

        print(f"Project Searcher plugin started. Found {len(self.projects_cache)} projects.")
        sys.stdout.flush()

    def _scan_projects(self):
        """Scan the projects directory and cache project information."""
        self.projects_cache = {}

        try:
            projects_path = Path(PROJECTS_BASE_DIR)
            if not projects_path.exists():
                print(f"Warning: Projects directory {PROJECTS_BASE_DIR} does not exist")
                return

            # Scan for group/project structure
            for group_dir in projects_path.iterdir():
                if not group_dir.is_dir() or group_dir.name.startswith('.'):
                    continue

                for project_dir in group_dir.iterdir():
                    if not project_dir.is_dir() or project_dir.name.startswith('.'):
                        continue

                    project_id = str(project_dir)
                    project_name = project_dir.name
                    group_name = group_dir.name

                    self.projects_cache[project_id] = {
                        'name': project_name,
                        'group': group_name,
                        'path': project_id,
                        'display_name': f"{group_name}/{project_name}"
                    }

        except Exception as e:
            print(f"Error scanning projects: {e}")
            sys.stdout.flush()

    def _refresh_cache(self):
        """Refresh the projects cache."""
        self._scan_projects()

    def _match_query(self, query: str) -> List[dict]:
        """
        Match projects against the query string.

        Args:
            query: Search query from KRunner

        Returns:
            List of matching projects with relevance scores
        """
        query_lower = query.lower()
        matches = []

        for project_id, project_info in self.projects_cache.items():
            name_lower = project_info['name'].lower()
            group_lower = project_info['group'].lower()
            display_lower = project_info['display_name'].lower()

            # Calculate relevance
            relevance = 0.0

            # Exact matches get highest priority
            if query_lower == name_lower:
                relevance = 1.0
            elif query_lower in name_lower:
                # Substring match in project name
                relevance = 0.8
            elif query_lower in group_lower:
                # Match in group name
                relevance = 0.5
            elif query_lower in display_lower:
                # Match in full display name
                relevance = 0.6
            else:
                # Fuzzy matching - check if all query chars appear in order
                if self._fuzzy_match(query_lower, name_lower):
                    relevance = 0.4
                elif self._fuzzy_match(query_lower, display_lower):
                    relevance = 0.3

            if relevance > 0:
                matches.append({
                    'id': project_id,
                    'info': project_info,
                    'relevance': relevance
                })

        # Sort by relevance (highest first)
        matches.sort(key=lambda x: x['relevance'], reverse=True)
        return matches

    def _fuzzy_match(self, query: str, text: str) -> bool:
        """
        Check if all characters in query appear in text in order.

        Args:
            query: Search query
            text: Text to search in

        Returns:
            True if fuzzy match succeeds
        """
        query_idx = 0
        for char in text:
            if query_idx < len(query) and char == query[query_idx]:
                query_idx += 1
        return query_idx == len(query)

    @dbus.service.method(INTERFACE_NAME, in_signature='s', out_signature='a(sssida{sv})')
    def Match(self, query: str):
        """
        KRunner Match method - called when user types in KRunner.

        Args:
            query: The search query from KRunner

        Returns:
            List of matches in KRunner format
        """
        # Check if query starts with a trigger keyword
        query_parts = query.strip().split(maxsplit=1)
        if not query_parts:
            return []

        first_word = query_parts[0].lower()
        if first_word not in TRIGGER_KEYWORDS:
            return []

        # Get the actual search term
        search_term = query_parts[1] if len(query_parts) > 1 else ''
        if not search_term:
            # No search term, show all projects (limited)
            matches = list(self.projects_cache.values())[:10]
            results = []
            for project_info in matches:
                results.append((
                    project_info['path'],  # id
                    project_info['display_name'],  # text
                    'folder-code',  # icon
                    100,  # type (100 = normal match)
                    1.0,  # relevance
                    {
                        'category': dbus.String('Projects', variant_level=1),
                        'subtext': dbus.String(project_info['path'], variant_level=1)
                    }  # properties
                ))
            return results

        # Refresh cache periodically (every search)
        self._refresh_cache()

        # Find matching projects
        matches = self._match_query(search_term)

        # Convert to KRunner format
        results = []
        for match in matches[:15]:  # Limit to top 15 results
            project_info = match['info']
            relevance = match['relevance']

            results.append((
                project_info['path'],  # id
                project_info['display_name'],  # text
                'folder-code',  # icon
                100,  # type (100 = normal match)
                relevance,  # relevance
                {
                    'category': dbus.String('Projects', variant_level=1),
                    'subtext': dbus.String(project_info['path'], variant_level=1)
                }  # properties
            ))

        return results

    @dbus.service.method(INTERFACE_NAME, in_signature='ss', out_signature='')
    def Run(self, match_id: str, action_id: str):
        """
        KRunner Run method - called when user selects a match.

        Args:
            match_id: The ID of the selected match (project path)
            action_id: The ID of the action (unused)
        """
        project_path = match_id

        try:
            # Open project in VSCode
            print(f"Opening project: {project_path}")
            sys.stdout.flush()

            # Use Popen to avoid blocking
            subprocess.Popen(
                [VSCODE_COMMAND, project_path],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True
            )
        except Exception as e:
            print(f"Error opening project: {e}")
            sys.stdout.flush()

    @dbus.service.method(INTERFACE_NAME, in_signature='s', out_signature='a(ss)')
    def Actions(self, match_id: str):
        """
        KRunner Actions method - returns available actions for a match.

        Args:
            match_id: The ID of the match

        Returns:
            List of available actions (currently empty)
        """
        # No additional actions for now
        return []

    @dbus.service.method(INTERFACE_NAME, in_signature='', out_signature='a{sv}')
    def Config(self):
        """
        KRunner Config method - returns plugin metadata.
        This makes the plugin appear in Plasma Search settings.

        Returns:
            Dictionary with plugin configuration
        """
        return {
            'name': dbus.String('Project Searcher', variant_level=1),
            'id': dbus.String('org.kde.runner.projectsearcher', variant_level=1),
            'description': dbus.String('Search and open development projects', variant_level=1),
            'icon': dbus.String('folder-code', variant_level=1),
            'triggerWords': dbus.Array(TRIGGER_KEYWORDS, signature='s', variant_level=1),
            'matchRegex': dbus.String('^(' + '|'.join(TRIGGER_KEYWORDS) + r')\s+.*', variant_level=1),
        }


def main():
    """Main entry point."""
    try:
        # Create and run the service
        service = ProjectSearcher()

        # Run the GLib main loop
        loop = GLib.MainLoop()
        print("Project Searcher service is ready")
        sys.stdout.flush()
        loop.run()

    except KeyboardInterrupt:
        print("Service interrupted by user")
        sys.exit(0)
    except Exception as e:
        print(f"Fatal error: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()
