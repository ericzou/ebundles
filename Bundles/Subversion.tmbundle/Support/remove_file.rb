#!/usr/bin/env ruby -s

abort "Wrong arguments: use -path=«file to remove»" if $path.nil?

svn     = $svn || 'svn'
path    = $path
display = $displayname || File.basename(path)

res = %x{
  iconv -f utf-8 -t mac <<"AS"|osascript 2>/dev/console
    tell app "TextMate" to display alert "Remove File?" ¬
      message "Do you really want to remove the file “#{display}” from your working copy?" ¬
      buttons { "Cancel", "Remove" } cancel button 1 as warning
    return button returned of result
}

if res =~ /Remove/ then
  ENV['TM_SVN_REMOVE'] = path # by using an env. variable we avoid shell escaping
  puts `#{svn} remove "$TM_SVN_REMOVE"`
else
	puts "Cancel"
end
