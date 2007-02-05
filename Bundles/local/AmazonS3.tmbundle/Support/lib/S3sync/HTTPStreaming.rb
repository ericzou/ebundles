# This software code is made available "AS IS" without warranties of any        
# kind.  You may copy, display, modify and redistribute the software            
# code either by itself or as incorporated into your code; provided that        
# you do not remove any proprietary notices.  Your use of this software         
# code is at your own risk and you waive any claim against the author
# with respect to your use of this software code. 
# (c) 2006 Gregory Bell
#

# The purpose of this file is to overlay the net/http library 
# to add some functionality
# (without changing the file itself or requiring a specific version)
# It still isn't perfectly robust, i.e. if radical changes are made
# to the underlying lib this stuff will need updating.

require 'net/http'

module Net

	$HTTPStreamingDebug = false

	# Allow request body to be an IO stream
	# Allow an IO stream argument to stream the response body out
	class HTTP
		alias _HTTPStremaing_request request
		
		def request(req, body = nil, streamResponseBodyTo = nil, &block)
			if not block_given? and streamResponseBodyTo and streamResponseBodyTo.respond_to?(:write)
				$stderr.puts "Response using streaming" if $HTTPStreamingDebug
				# this might be a retry, we should make sure the stream is at its beginning
				streamResponseBodyTo.rewind if streamResponseBodyTo.respond_to?(:rewind) 
				block = proc do |res|
					res.read_body do |chunk|
						streamResponseBodyTo.write(chunk)
					end
				end
			end
			if body != nil && body.respond_to?(:read)
				$stderr.puts "Request using streaming" if $HTTPStreamingDebug
				# this might be a retry, we should make sure the stream is at its beginning
				body.rewind if body.respond_to?(:rewind) 
				req.body_stream = body
				return _HTTPStremaing_request(req, nil, &block)
			else
				return _HTTPStremaing_request(req, body, &block)
			end
		end
	end

end #module
