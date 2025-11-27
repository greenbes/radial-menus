#!/usr/bin/env bash

JSON='{
  "version": 1,
  "name": "quick-apps",
  "items": [
    {
      "id": "11111111-1111-1111-1111-111111111111",
      "title": "Terminal",
      "iconName": "terminal",
      "action": {"launchApp": {"path": "/System/Applications/Utilities/Terminal.app"}}
    },
    {
      "id": "22222222-2222-2222-2222-222222222222",
      "title": "Safari",
      "iconName": "safari",
      "action": {"launchApp": {"path": "/System/Applications/Safari.app"}}
    },
    {
      "id": "33333333-3333-3333-3333-333333333333",
      "title": "Notes",
      "iconName": "note.text",
      "action": {"launchApp": {"path": "/System/Applications/Notes.app"}}
    },
    {
      "id": "44444444-4444-4444-4444-444444444444",
      "title": "Calculator",
      "iconName": "plus.forwardslash.minus",
      "action": {"launchApp": {"path": "/System/Applications/Calculator.app"}}
    }
  ]
}'

ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$JSON'''))")
open "radial-menu://show?json=$ENCODED"


