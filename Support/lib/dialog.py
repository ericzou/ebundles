from types import NoneType
import sys
import os
import re

from tm_helpers import sh, sh_escape, to_plist, from_plist

# fix up path
tm_support_path = os.path.join(os.environ["TM_SUPPORT_PATH"], "lib")
if not tm_support_path in os.environ:
    sys.path.insert(0, tm_support_path)

dialog = os.environ["DIALOG"]

if not sys.version.startswith("2.5"):
    def all(it):
        return not bool(len([truth for truth in it if truth is False]))

def item(val):
    if isinstance(val, (unicode, str)):
        return {"title": val}
    if isinstance(val, tuple):
        return {"title": val[0]}
    elif val is None:
        return {"separator": 1}

def all_are_instance(it, typ):
    return all([(isinstance(i, typ)) for i in it])

def menu(options):
    """ Accepts a list and causes TextMate to show an inline menu.
    
    If options is a list of strings, will return the selected index.
    
    If options is a list of (key, value) tuples, will return value of the
    selected key. Note that we don't use dicts, so that key-value options
    can be ordered. If you want to use a dict, try dict.items().
    
    In either input case, a list item with value `None` causes tm_dialog to
    separator for that index.
    """
    hashed_options = False
    if not options:
        return None
    if all_are_instance(options, (unicode, str, NoneType)):
        menu = dict(menuItems=[item(val) for val in options])
    elif all_are_instance(options, (tuple, NoneType)):
        hashed_options = True
        menu = dict(menuItems=[item(pair) for pair in options])
    plist = to_plist(menu)
    cmd = 'bash -c "%s -up %s"' % (sh_escape(dialog), sh_escape(plist))
    result = from_plist(sh(cmd))
    if not 'selectedIndex' in result:
        return None
    index = int(result['selectedIndex'])
    if hashed_options:
        return options[index][1]
    return options[index]
