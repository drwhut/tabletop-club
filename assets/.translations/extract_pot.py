#!/usr/bin/python3

# This script creates a .pot file for the default asset pack, using an exported
# JSON file. You can export the file by running the game with the arguments:
# --export-asset-db <FILE_NAME>

import datetime
import json
import sys

class Message:
    def __init__(self, msg, loc):
        self.msgid = msg
        self.locs = [loc]
    
    def write(self, file):
        # TODO: Deal with new-lines within the message.
        file.write("\n#:")
        for loc in self.locs:
            file.write(" " + loc)
        file.write("\nmsgid \"" + self.msgid + "\"\nmsgstr \"\"\n")

HEADER = """# Tabletop Club Default Asset Pack Translation Template.
# Copyright (c) 2020-2022 Benjamin 'drwhut' Beddows.
# Copyright (c) 2021-2022 Tabletop Club contributors (see game/CREDITS.tres).
# This file is distributed under the same license as the Tabletop Club package.
# Benjamin 'drwhut' Beddows <drwhut@gmail.com>, 2021.
#
#, fuzzy
msgid ""
msgstr ""
"Project-Id-Version: Tabletop Club \\n"
"Report-Msgid-Bugs-To: \\n"
"POT-Creation-Date: CREATION_DATE\\n"
"PO-Revision-Date: YEAR-MO-DA HO:MI+ZONE\\n"
"Last-Translator: FULL NAME <EMAIL@ADDRESS>\\n"
"Language-Team: LANGUAGE <LL@li.org>\\n"
"MIME-Version: 1.0\\n"
"Content-Type: text/plain; charset=UTF-8\\n"
"Content-Transfer-Encoding: 8bit\\n"
"Generated-By: extract_pot.py\\n"
"""

def add_message(msg_list, msg, loc):
    found = False

    for msg_obj in msg_list:
        if msg_obj.msgid == msg:
            msg_obj.locs.append(loc)
            found = True
            break
    
    if not found:
        msg_list.append(Message(msg, loc))

if len(sys.argv) < 2:
    sys.exit("Need a file path to exported JSON file.")

json_path = sys.argv[1]
with open(json_path, "r") as json_file:
    asset_db = json.load(json_file)

    with open("asset_pack.pot", "w") as pot_file:
        print("asset_pack.pot")
        creation_date = datetime.datetime.now()
        creation_date_str = creation_date.strftime("%Y-%m-%d %H:%M")
        modified_header = HEADER.replace("CREATION_DATE", creation_date_str)
        pot_file.write(modified_header)

        messages = []
        for pack in asset_db:
            for asset_type in asset_db[pack]:
                for asset in asset_db[pack][asset_type]:
                    name = asset["name"]
                    desc = asset["desc"]

                    loc = "../{}/{}/{}".format(pack, asset_type, name)
                    loc1 = loc + ":1"
                    loc2 = loc + ":2"

                    if len(name) > 0:
                        add_message(messages, name, loc1)
                    if len(desc) > 0:
                        add_message(messages, desc, loc2)
        
        for message in messages:
            message.write(pot_file)
