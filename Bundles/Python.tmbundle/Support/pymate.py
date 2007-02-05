# encoding: latin-1

# copyright (c) Domenico Carbotta, 2005
# with enhancements and precious input by Brad Miller and Jeroen van der Ham
# wrap function shamelessly taken from the ASPN Python Cookbook
# this script is released under the GNU General Public License


__version__ = (0, 1, 0, 'beta')


import sys
import os
import threading
# import EasyDialogs
# import MacOS
import pymate_output as pmout
import tmproj


subs = [('&', '&amp;'),
        ('<', '&lt;'),
        ('>', '&gt;'),
            # by default, tabs are rendered as 8 spaces
            # I _really_ do like four spaces instead
        ('\t', ' ' * 4)]


def wrap(text, width):
    '''
        A word-wrap function that preserves existing line breaks
        and most spaces in the text. Expects that existing line
        breaks are posix newlines (\n).
        Written by Mike Brown for the ASPN Python Cookbook
    '''
    return reduce(lambda line, word, width=width: '%s%s%s' %
            (line,
                ' \n'[(len(line)-line.rfind('\n')-1
                     + len(word.split('\n',1)[0]
                          ) >= width)],
            word), text.split(' '))


def sanitize(string):
    '''
        Substitutes HTML entities for &, < and > (thus assuring us that no
        output from the script is interpreted as HTML tags or entities).
    '''
    
    for sub_from, sub_to in subs:
        string = string.replace(sub_from, sub_to)
    
    return string


def raw_input_replacement(prompt=''):
    '''
        A replacement for raw_input() which displays a graphical input dialog.
    '''
    try:
        rv = EasyDialogs.AskString(prompt)
    except MacOS.Error:
        # python is not allowed to interact with user.
        # raise EOFError like every noninteractive shell does.
        raise EOFError
    if rv == '\x04':
        # user typed ^D, which by all means is an EOF ;)
        raise EOFError
    else:
        return rv


def input_replacement(prompt=''):
    '''
        A replacement for input() which displays a graphical input dialog.
    '''
    # XXX doesn't work -- cannot find a way to gain access to the current
    # environment of the script
    if prompt != '':
        prompt += '\n\n'
    prompt += 'Please note that in the current version PyMate cannot gain '
    prompt += 'access to the scripts environment; you can only enter '
    prompt += 'expressions involving literals.'
    rv = raw_input_wrapper(wrap(prompt, 100))
    return eval(rv, globals(), locals())


def disabled_input_replacement(prompt=''):
    '''
        Signals that the current version of PyMate cannot replace input().
    '''
    raise EOFError, ('When running under PyMate input() is disabled. ' +
            'Use eval(raw_input()) instead.')


class HTMLSafeStream:
    
    close_what = None
    output = ''
    TheLock = threading.Lock()
    
    def __init__(self, before='', after='', limit=0):
        self.before = str(before)
        self.after = str(after)
        self.limit = limit
    
    def write(self, string):
        HTMLSafeStream.TheLock.acquire()
        
        if HTMLSafeStream.close_what is None:
            # it's the first write ever.
            # open our context
            HTMLSafeStream.output += self.before
            # register our context closing string
            HTMLSafeStream.close_what = self.after
        
        elif HTMLSafeStream.close_what != self.after:
            # another context is already open.
            # close previous context by writing what's specified in the
            # other HTMLSafeStream's after field
            if HTMLSafeStream.output[-1] != '\n':
                HTMLSafeStream.output += '\n'
            HTMLSafeStream.output += HTMLSafeStream.close_what
            # open our context
            HTMLSafeStream.output += self.before
            # register our context closing string
            HTMLSafeStream.close_what = self.after
        
        HTMLSafeStream.output += sanitize(string)
        
        HTMLSafeStream.TheLock.release()
    
    # @staticmethod
    def flush(limit=80):
        HTMLSafeStream.TheLock.acquire()
        
        # close the current context
        if HTMLSafeStream.close_what is not None:
            HTMLSafeStream.output += HTMLSafeStream.close_what
            HTMLSafeStream.close_what = ''
        
        # split and wrap lines, then print them
        print >> sys.__stdout__, wrap(HTMLSafeStream.output, limit)
        HTMLSafeStream.output = ''
        
        HTMLSafeStream.TheLock.release()
    
    flush = staticmethod(flush)


def main(script_name):
    '''
        Main entry point to the program.
    '''
    
    try:
        script = open(script_name)
    except IOError, msg:
        print '<title>PyMate</title>'
        print '<strong>IOError:</strong>', msg
        return
        
    py_version = 'Python %s (PyMate %d.%d.%d %s)' % (
            (sys.version,) + __version__)
    py_version += '''
<small>Please remember that PyMate is still in an early beta stage...
Send all your bug reports to <a
href="mailto:domenico.carbotta@gmail.com">the author</a> :)</small>
'''
    script_name_short = os.path.basename(script_name)
    print pmout.preface % (py_version, script_name_short)
    
    # the environment in which the script will run
    script_env = {}
        
    # the script should run in the __main__ namespace
    script_env['__name__'] = '__main__'
    # we signal our presence
    script_env['__pymate'] = True
    # override raw_input() and input() in order to display a graphical prompt
    script_env['raw_input'] = raw_input_replacement
    # input() cannot access the script namespace, but it *almost* works
    script_env['input'] = input_replacement
    # in case you don't like it...
    # script_env['input'] = disabled_input_replacement
    
    # script should be able to load modules from its directory
    # we overwrite our path since we won't load any other modules
    # and we don't want script to look for modules from our directory!
    sys.path[0] = os.path.dirname(script_name)
        
    # we clean traces of our presence from sys.argv[]
    sys.argv.pop(0)
    
    # let's cd the scripts' directory
    os.chdir(os.path.dirname(script_name))
    
    # we sanitize stdout and stderr, replacing them with two instances of
    # our 'html-safe' streams
    sys.stdout = HTMLSafeStream(limit=80)
    sys.stderr = HTMLSafeStream('<em>', '</em>', limit=80)
    
    try:
        
        # run python run!
        exec script in script_env
        
    except:
        # flush script's output
        HTMLSafeStream.flush()
        
        # we don't want html sanitization on our own output!
        sys.stdout = sys.__stdout__
        sys.stderr = sys.__stderr__
        
        # retrieving exception data...
        e_class, e_obj, tb = sys.exc_info()
        
        # retrieving exception name
        e_name = str(e_class)
        if e_name.startswith('exceptions.'):
            # undecorated exception name
            e_name = e_name.split('.')[-1]
        
        # traceback lenght is useful for checking wheter a SyntaxError
        # occurred in the main file or in an exec statement
        tb_len = 0
        tbx = tb.tb_next
        while (tbx is not None):
            tbx = tbx.tb_next
            tb_len += 1
        del tbx
        
        # exception arguments
        if len(e_obj.args) != 0:
            e_args = ': ' + ', '.join(map(str, e_obj.args))
        else:
            e_args = '.'

        # if the exception was SystemExit, it's a normal condition        
        if e_class is SystemExit:
            print '<strong>Script terminated raising SystemExit%s</strong>' \
                    % e_args
            print pmout.normal_end
            return

        # when we get a syntax error in a regular script,
        # the traceback is not interesting but we want to format
        # differently the exception parameters            
        if e_class is SyntaxError and tb_len == 0:
            e_args = (' in <a href="txmt://open?url=file://%s&line=%d">' +
                    '%s</a> at line %d')
            
            if e_obj.filename in (None, '<string>'):
                filename = '/tmp/Unknown location'
                short_filename = '<em>unknown location</em>'
            else:
                filename = e_obj.filename
                short_filename = os.path.basename(e_obj.filename)
                    
            e_args = e_args % (filename, e_obj.lineno,
                    short_filename, e_obj.lineno)
            print pmout.syntax % (e_name, e_args)
            return
        
        print pmout.exception_preface % (e_name, e_args)
        
        # we discard the first traceback element, since it refers to us
        tb = tb.tb_next
        
        # try to build a TMProj object representing the current project
        # defaulting to None
        try:
            current_project = tmproj.TMProj()
        except tmproj.Error:
            current_project = None
            script_dir = os.path.dirname(script_name)
        
        while tb is not None:

            # extract the file name from the current traceback
            filename = tb.tb_frame.f_code.co_filename
            short_filename = os.path.basename(filename)
                            
            # extract the function name from the current traceback
            func_name = tb.tb_frame.f_code.co_name
            if func_name == '?':
                func_name = '<em>module body</em>'            
            
            if not os.path.exists(filename):
                print pmout.tbitem_binary % locals()
            
            else:         
                # as suggested by Jeroen: mark files which don't belong to the
                # current project.
            
                if current_project is None:
                    # the script is being run from a "standalone" window (i.e.
                    # there's no open project).
                    # if the script doesn't reside in the same directory,
                    # a  or a parent directory of the script being run
                    # it's "far"
                    file_dir = os.path.dirname(filename)
                    is_near = (script_dir == file_dir or
                            script_dir.startswith(file_dir) or
                            file_dir.startswith(script_dir))
                else:
                    # there's an open project. see tmproj module for info.
                    is_near = filename in current_project
            
                if is_near:
                    template = pmout.tbitem_near
                else:
                    template = pmout.tbitem_far
            
                lineno = tb.tb_lineno
            
                print template % locals()
            
            # advance to the next traceback object
            tb = tb.tb_next
        
        print pmout.exception_end
    
    else:
        # flush script's output
        HTMLSafeStream.flush()
        
        # we don't want html sanitization on our own output!
        sys.stdout = sys.__stdout__
        sys.stderr = sys.__stderr__
        
        print '<strong>Script terminated with success.</strong>'
        print pmout.normal_end


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print 'Usage: python pymate.py <script>'
    else:
        main(sys.argv[1])
