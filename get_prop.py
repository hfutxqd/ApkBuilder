#!/usr/bin/env python2.7

import sys
import ConfigParser

if len(sys.argv) is not 3:
    print('usage : get_prop.py [section] [option]')
    exit(-1)

config = ConfigParser.RawConfigParser()
config.read('apk_builder.properties')
if config.has_option(sys.argv[1], sys.argv[2]):
    print config.get(sys.argv[1], sys.argv[2])
else:
    print ""

