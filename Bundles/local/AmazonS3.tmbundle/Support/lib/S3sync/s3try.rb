#!/usr/bin/env ruby 
# This software code is made available "AS IS" without warranties of any        
# kind.  You may copy, display, modify and redistribute the software            
# code either by itself or as incorporated into your code; provided that        
# you do not remove any proprietary notices.  Your use of this software         
# code is at your own risk and you waive any claim against the author
# with respect to your use of this software code. 
# (c) 2006 Gregory Bell
#
module S3sync

	$AWS_ACCESS_KEY_ID = ENV["AWS_ACCESS_KEY_ID"]           
	$AWS_SECRET_ACCESS_KEY = ENV["AWS_SECRET_ACCESS_KEY"]   
	$AWS_S3_HOST = (ENV["AWS_S3_HOST"] or "s3.amazonaws.com")
	$SSL_CERT_DIR = ENV["SSL_CERT_DIR"]
	$S3SYNC_RETRIES = (ENV["S3SYNC_RETRIES"] or 100).to_i # number of errors to tolerate 
	$S3SYNC_WAITONERROR = (ENV["S3SYNC_WAITONERROR"] or 30).to_i # seconds
	$S3SYNC_NATIVE_CHARSET = (ENV["S3SYNC_NATIVE_CHARSET"] or "ISO-8859-1")

	require 'S3'

	require 'HTTPStreaming'
	require 'S3encoder'
	CGI::exemptSlashesInEscape = true
	CGI::usePercent20InEscape = true
	CGI::useUTF8InEscape = true
	CGI::nativeCharacterEncoding = $S3SYNC_NATIVE_CHARSET
	require 'S3_s3sync_mod'

	$S3syncRetriesLeft = $S3SYNC_RETRIES.to_i
	
	def S3sync.s3trySetup 	
		
		# ---------- CONNECT ---------- #

		$S3syncConnection = S3::AWSAuthConnection.new($AWS_ACCESS_KEY_ID, $AWS_SECRET_ACCESS_KEY, $S3syncOptions['--ssl'], $AWS_S3_HOST)
		if $S3syncOptions['--ssl'] and $SSL_CERT_DIR
			$S3syncConnection.verify_mode = OpenSSL::SSL::VERIFY_PEER
			$S3syncConnection.ca_path = $SSL_CERT_DIR 
		end
	end
	
	def S3sync.S3try(command, *args)
		result = nil
		delim = $,
		$,=' '
		while $S3syncRetriesLeft > 0 do
		$stderr.puts "Trying command #{command} #{args} with #{$S3syncRetriesLeft} retries left" if $S3syncOptions['--debug']
			forceRetry = false
			begin
				result = $S3syncConnection.send(command, *args)
			rescue Errno::EPIPE
				forceRetry = true
				$stderr.puts "Broken pipe:" 
			rescue Errno::ECONNRESET
				forceRetry = true
				$stderr.puts "Connection reset:" 
			rescue Errno::ECONNABORTED
				forceRetry = true
				$stderr.puts "Connection aborted:" 
			rescue Timeout::Error
				forceRetry = true
				$stderr.puts "Connection timed out:" 
			rescue EOFError
				# i THINK this is happening like a connection reset
				forceRetry = true
				$stderr.puts "EOF error:"
			rescue OpenSSL::SSL::SSLError
				forceRetry = true
				$stderr.puts "SSL Error:"
				# kill and reset connection
				S3sync::s3trySetup 

			end
			begin
				debug("Response code: #{result.http_response.code}")
				break if ((200...300).include? result.http_response.code.to_i) and (not forceRetry)
				$stderr.puts "S3 command failed:\n#{command} #{args}"
				$stderr.puts "With result #{result.http_response.code} #{result.http_response.message}\n"
				debug(result.http_response.body)
				# only retry 500's, per amazon
				break unless ((500...600).include? result.http_response.code.to_i) or forceRetry
			rescue NoMethodError
				debug("No result available")
			end
			$S3syncRetriesLeft -= 1
			$stderr.puts "#{$S3syncRetriesLeft} retries left"
			Kernel.sleep $S3SYNC_WAITONERROR
		end
		$, = delim
		result
	end
	
end #module

