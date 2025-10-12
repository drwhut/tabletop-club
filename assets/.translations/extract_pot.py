#!/usr/bin/python3

# This script creates a .pot file for the default asset pack, using an exported
# JSON file. You can export the file by running the game with the arguments:
# --export-asset-db <FILE_NAME>

import datetime
import json
import polib
import sys

HEADER = """Tabletop Club Default Asset Pack Translation Template.
Copyright (c) 2020-2025 Benjamin 'drwhut' Beddows.
Copyright (c) 2021-2025 Tabletop Club contributors (see game/CREDITS.tres).
This file is distributed under the same license as the Tabletop Club package.
Benjamin 'drwhut' Beddows <drwhut@gmail.com>, 2023.
"""

if len(sys.argv) < 2:
    sys.exit("Need a file path to exported JSON file.")

json_path = sys.argv[1]
with open(json_path, "r") as json_file:
    asset_db = json.load(json_file)

    pot_file = polib.POFile(wrapwidth=-1)
    pot_file.header = HEADER
    creation_date = datetime.datetime.now()
    creation_date_str = creation_date.strftime("%Y-%m-%d %H:%M")
    pot_file.metadata = {
        "Project-Id-Version": "PROJECT VERSION",
        "Report-Msgid-Bugs-To": "EMAIL@ADDRESS",
        "POT-Creation-Date": creation_date_str,
        "PO-Revision-Date": "YEAR-MO-DA HO:MI+ZONE",
        "Last-Translator": "FULL NAME <EMAIL@ADDRESS>",
        "Language-Team": "LANGUAGE <LL@li.org>",
        "MIME-Version": "1.0",
        "Content-Type": "text/plain; charset=UTF-8",
        "Content-Transfer-Encoding": "8bit",
        "Generated-By": "extract_pot.py"
    }
    pot_file.metadata_is_fuzzy = True

    for pack in asset_db:
        for asset_type in asset_db[pack]:
            for asset in asset_db[pack][asset_type]:
                asset_name = asset["name"]
                loc = "../{}/{}/{}".format(pack, asset_type, asset_name)
                loc = loc.replace(" ", "_")

                key_index = 0
                for key in [ "name", "desc" ]:
                    value = asset[key]
                    if len(value) == 0:
                        continue
                    
                    key_index += 1
                    occurrence = (loc, str(key_index))

                    entry = pot_file.find(value)
                    if entry is None:
                        entry = polib.POEntry(
                            msgid=value,
                            msgstr="",
                            occurrences=[occurrence]
                        )
                        pot_file.append(entry)
                    else:
                        entry.occurrences.append(occurrence)
    
    pot_file.save("asset_pack.pot")
    print("asset_pack.pot")
