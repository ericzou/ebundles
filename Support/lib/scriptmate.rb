SUPPORT_LIB = ENV['TM_SUPPORT_PATH'] + '/lib/'
require SUPPORT_LIB + 'escape'
require SUPPORT_LIB + 'web_preview'
require SUPPORT_LIB + 'io'

require 'cgi'
require 'fcntl'
require 'tempfile'

$KCODE = 'u'
require 'jcode'

$SCRIPTMATE_VERSION = "$Revision: 9894 $"

def my_popen3(*cmd) # returns [stdin, stdout, strerr, pid]
  pw = IO::pipe   # pipe[0] for read, pipe[1] for write
  pr = IO::pipe
  pe = IO::pipe

  pid = fork{
    pw[1].close
    STDIN.reopen(pw[0])
    pw[0].close

    pr[0].close
    STDOUT.reopen(pr[1])
    pr[1].close

    pe[0].close
    STDERR.reopen(pe[1])
    pe[1].close

    exec(*cmd)
  }

  pw[0].close
  pr[1].close
  pe[1].close

  pw[1].sync = true

  [pw[1], pr[0], pe[0], pid]
end

def cmd_mate(cmd)
  # cmd can be either a string or a list of strings to be passed to Popen3
  # this command will write the output of the `cmd` on STDOUT, formatted in
  # HTML.
  c = UserCommand.new(cmd)
  m = CommandMate.new(c)
  m.emit_html
end

class UserCommand
  attr_reader :display_name, :path
  def initialize(cmd)
    @cmd = cmd
  end
  def run
    stdin, stdout, stderr, pid = my_popen3(@cmd)
    return stdout, stderr, nil, pid
  end
  def to_s
    @cmd.to_s
  end
  def cleanup; end
end

class CommandMate
    def initialize (command)
      # the object `command` needs to implement a method `run`.  `run` should
      # return an array of three file descriptors [stdout, stderr, stack_dump].
      @error = ""
      @command = command
      STDOUT.sync = true
      @mate = self.class.name
    end
  protected
    def filter_stdout(str)
      # strings from stdout are passed through this method before being printed
      htmlize(str).gsub(/\<br\>/, "<br>\n")
    end
    def filter_stderr(str)
      # strings from stderr are passwed through this method before printing
      "<span style='color: red'>#{htmlize str}</span>".gsub(/\<br\>/, "<br>\n")
    end
    def emit_header
      puts html_head(:window_title => "#{@command}", :page_title => "#{@command}", :sub_title => "")
      puts "<pre>"
    end
    def emit_footer
      puts "</pre>"
      html_footer
    end
  public
    def emit_html
      stdout, stderr, stack_dump, @pid = @command.run
      %w[INT TERM].each do |signal|
        trap(signal) do
          begin
            Process.kill("KILL", @pid)
            sleep 0.5
            Process.kill("TERM", @pid)
          rescue
            # process doesn't exist anymore
          end
        end
      end
      emit_header()
      TextMate::IO.exhaust(:out => stdout, :err => stderr, :stack => stack_dump) do |str, type|
        case type
          when :out   then print filter_stdout(str)
          when :err   then puts filter_stderr(str)
          when :stack then @error << str
        end
      end
      emit_footer()
      Process.waitpid(@pid)
      @command.cleanup
    end
end


def String.random_alphanumeric(size=16)
  s = ""
  size.times { s << (i = Kernel.rand(62); i += ((i < 10) ? 48 : ((i < 36) ? 55 : 61 ))).chr }
  s
end

class UserScript
  attr_reader :display_name, :path, :warning
  def initialize(content)
    
    @warning = ''
    @content = content
    @hashbang = $1 if @content =~ /\A#!(.*)$/
    
    saved = true
    if ENV.has_key? 'TM_FILEPATH' then
      @path = ENV['TM_FILEPATH']
      @display_name = File.basename(@path)
      saved = false
    end
    
    @temp_path = nil
    if not saved or not ENV.has_key? 'TM_FILEPATH'
      saved = true
      @display_name = "untitled" + default_extension
      @path = random_file_name
      # store @path as @temp_path so we don't accidentally unlink
      # an non-temporary file.
      @temp_path = @path 
      begin
        f = open(@path, 'w')
        ENV["TM_SCRIPT_IS_UNTITLED"] = "true"
        f.write @content
      rescue Errno::EACCES
        saved = false
        @warning += "\nCould not open temp file, writing script on stdin..."
      ensure
        f.close
      end
    end
    
    if not saved
      raise Exception("Could not save file or write to temporary directory.")
    end
  end
  
  def random_file_name
    p = "/tmp/tm_script" + String.random_alphanumeric(4) + default_extension()
    while File.exists? p
      p  = "/tmp/tm_script" + String.random_alphanumeric(4) + default_extension()
    end
    p
  end
  
  public
    
    def cleanup
      File.unlink(@temp_path) if @temp_path and File.exists? @temp_path
    end
    
    def executable
      # return the path to the executable that will run @content.
    end
    def args
      # return any arguments to be fed to the executable
      []
    end
    def filter_cmd(cmd)
      # this method is called with this list:
      #     [executable, args, e_sh(@path), ARGV.to_a ].flatten
      cmd
    end
    def version_string
      # return the version string of the executable.
    end
    def default_extension
      # return the extension to use if the script has not yet been saved
    end
    def run
      rd, wr = IO.pipe
      rd.fcntl(Fcntl::F_SETFD, 1)
      ENV['TM_ERROR_FD'] = wr.to_i.to_s
      Dir.chdir(File.dirname(@path)) if @path != "-"
      cmd = filter_cmd([executable, args, e_sh(@path), ARGV.to_a ].flatten)
      stdin, stdout, stderr, pid = my_popen3(cmd.join(" "))
      # if @path == "-"
      #   Thread.new { stdin.write @content; stdin.close }
      # end
      wr.close
      [ stdout, stderr, rd, pid ]
    end
end

class ScriptMate < CommandMate

  protected
    def emit_header
      puts html_head(:window_title => "#{@command.display_name} — #{@mate}", :page_title => "#{@mate}", :sub_title => "#{@command.lang}")
      puts <<-HTML
<!-- scriptmate javascripts -->
<script type="text/javascript" charset="utf-8">
function press(evt) {
   if (evt.keyCode == 67 && evt.ctrlKey == true) {
      TextMate.system("kill -s INT #{@pid}; sleep 0.5; kill -s TERM #{@pid}", null);
   }
}
document.body.addEventListener('keydown', press, false);

function copyOutput(link) {
  output = document.getElementById('_scriptmate_output').innerText;
  cmd = TextMate.system('__CF_USER_TEXT_ENCODING=$UID:0x8000100:0x8000100 /usr/bin/pbcopy', function(){});
  cmd.write(output);
  cmd.close();
  link.innerText = 'output copied to clipboard';
}
</script>
<!-- end javascript -->
HTML
      puts <<-HTML
  <style type="text/css">
    /* =================== */
    /* = ScriptMate Styles = */
    /* =================== */

    div.scriptmate {
    }

    div.scriptmate > div {
    	/*border-bottom: 1px dotted #666;*/
    	/*padding: 1ex;*/
    }

    div.scriptmate pre em
    {
    	/* used for stderr */
    	font-style: normal;
    	color: #FF5600;
    }

    div.scriptmate div#exception_report
    {
    /*	background-color: rgb(210, 220, 255);*/
    }

    div.scriptmate p#exception strong
    {
    	color: #E4450B;
    }

    div.scriptmate p#traceback
    {
    	font-size: 8pt;
    }

    div.scriptmate blockquote {
    	font-style: normal;
    	border: none;
    }


    div.scriptmate table {
    	margin: 0;
    	padding: 0;
    }

    div.scriptmate td {
    	margin: 0;
    	padding: 2px 2px 2px 5px;
    	font-size: 10pt;
    }

    div.scriptmate a {
    	color: #FF5600;
    }
    
    div#exception_report pre.snippet {
      margin:4pt;
      padding:4pt;
    }
  </style>
  <strong class="warning" style="float:left; color:#B4AF00;">#{@command.warning}</strong>
  <div class="scriptmate #{@mate.downcase}">
  <div class="controls" style="text-align:right;">
    <a style="text-decoration: none;" href="#" onclick="copyOutput(document.getElementById('_script_output'))">copy output</a>
  </div>
  <!-- first box containing version info and script output -->
  <pre>
<strong>#{@mate} r#{$SCRIPTMATE_VERSION[/\d+/]} running #{@command.version_string}</strong>
<strong>>>> #{@command.display_name}</strong>

<div id="_scriptmate_output" style="white-space: normal; -khtml-nbsp-mode: space; -khtml-line-break: after-white-space;"> <!-- Script output -->
  HTML
    end

    def emit_footer
      puts '</div></pre></div>'
      puts @error unless @error == ""
      puts '<div id="exception_report" class="framed">Program exited.</div>'
      html_footer
    end
end
