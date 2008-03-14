#! /usr/bin/env ruby
module BBCode
	@@imageformats = 'png|bmp|jpg|gif'
	@@tags = {
		# tag name => [regex, replace, description, example]
		'Bold' => [
			/\[b\](.*?)\[\/b\]/,
			'<strong>\1</strong>',
			'Embolden text',
			'Look [b]here[/b]',
			:bold],
		'Italics' => [
			/\[i\](.*?)\[\/i\]/,
			'<em>\1</em>',
			'Italicize or emphasize text',
			'Even my [i]cat[/i] was chasing the mailman!',
			:italics],
		'Underline' => [
			/\[u\](.*?)\[\/u\]/,
			'<u>\1</u>',
			'Underline',
			'Use it for [u]important[/u] things or something',
			:underline],
		'Strikeout' => [
			/\[s\](.*?)\[\/s\]/,
			'<s>\1</s>',
			'Strikeout',
			'[s]nevermind[/s]',
			:strikeout],
		
		'Delete' => [
			/\[del\](.*?)\[\/del\]/,
			'<del>\1</del>',
			'Deleted text',
			'[del]deleted text[/del]',
			:delete],
		'Insert' => [
			/\[ins\](.*?)\[\/ins\]/,
			'<ins>\1</ins>',
			'Inserted Text',
			'[ins]inserted text[/del]',
			:insert],
		
		'Ordered List' => [
			/\[ol\](.*?)\[\/ol\]/m,
			'<ol>\1</ol>',
			'Ordered list',
			'My favorite people (alphabetical order): [ol][li]Jenny[/li][li]Alex[/li][li]Beth[/li][/ol]',
			:orderedlist],
		'Unordered List' => [
			/\[ul\](.*?)\[\/ul\]/m,
			'<ul>\1</ul>',
			'Unordered list',
			'My favorite people (order of importance): [ul][li]Jenny[/li][li]Alex[/li][li]Beth[/li][/ul]',
			:unorderedlist],
		'List Item' => [
			/\[li\](.*?)\[\/li\]/,
			'<li>\1</li>',
			'List item',
			'See ol or ul',
			:listitem],
		'List Item (alternative)' => [
			/\[\*\](.*?)$/,
			'<li>\1</li>',
			nil, nil,
			:listitem],
		
		'Definition List' => [
			/\[dl\](.*?)\[\/dl\]/m,
			'<dl>\1</dl>',
			'List of terms/items and their definitions',
			'[dl][dt]Fusion Reactor[/dt][dd]Chamber that provides power to your... nerd stuff[/dd][dt]Mass Cannon[/dt][dd]A gun of some sort[/dd][/dl]',
			:definelist],
		'Definition Term' => [
			/\[dt\](.*?)\[\/dt\]/,
			'<dt>\1</dt>',
			nil, nil,
			:defineterm],
		'Definition Definition' => [
			/\[dd\](.*?)\[\/dd\]/,
			'<dd>\1</dd>',
			nil, nil,
			:definition],
		
		'Quote' => [
			/\[quote=(.*?)\](.*?)\[\/quote\]/m,
			'<fieldset>
	<legend>\1</legend>
	<blockquote>\2</blockquote>
</fieldset>',
			nil, nil,
			:quote],
		'Quote (Sourceless)' => [
			/\[quote\](.*?)\[\/quote\]/m,
			'<fieldset>
	<blockquote>\1</blockquote>
</fieldset>',
			nil, nil,
			:quote],
		
		'Link' => [
			/\[url=(.*?)\](.*?)\[\/url\]/,
			'<a href="\1">\2</a>',
			'Hyperlink to somewhere else',
			'Maybe try looking on [url=http://google.com]Google[/url]?',
			nil, nil,
			:link],
		'Link (Implied)' => [
			/\[url\](.*?)\[\/url\]/,
			'<a href="\1">\1</a>',
			nil, nil,
			:link],
		# I'll fix this later or something
#		'Link (Automatic)' => [
#			/http:\/\/(.*?)[^<\/a>]/,
#			'<a href="\1">\1</a>'],
		
		'Image' => [
			/\[img\]([^\[\]].*?)\.(#{@@imageformats})\[\/img\]/i,
			'<img src="\1.\2" alt="" />',
			'Display an image',
			'Check out this crazy cat: [img]http://catsweekly.com/crazycat.jpg[/img]',
			:image],
		'Image (Alternative)' => [
			/\[img=([^\[\]].*?)\.(#{@@imageformats})\]/i,
			'<img src="\1.\2" alt="" />',
			nil, nil,
			:image],
		'Break' => [
		/\n/,
		'<br>',
		nil,nil,
		:break]
	}
	def self.to_html(text, method, tags)
		case method
			when :enable
				@@tags.each_value { |t|
					text.gsub!(t[0], t[1]) if tags.include?(t[4])
				}
			when :disable
				# this works nicely because the default is disable and the default set of tags is [] (so none disabled) :)
				@@tags.each_value { |t|
					text.gsub!(t[0], t[1]) unless tags.include?(t[4])
				}
		end
		text
	end
	def self.tags
		@@tags.each { |tn, ti|
			# yields the tag name, a description of it and example
			yield tn, ti[2], ti[3] if ti[2]
		}
	end
end

class String
	def bbcode_to_html(method = :disable, *tags)
		BBCode.to_html(self, method, tags)
	end
	def bbcode_to_html!(method = :disable, *tags)
		self.replace(BBCode.to_html(self, method, tags))
	end
end