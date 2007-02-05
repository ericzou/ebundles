#  This software code is made available "AS IS" without warranties of any
#  kind.  You may copy, display, modify and redistribute the software
#  code either by itself or as incorporated into your code; provided that
#  you do not remove any proprietary notices.  Your use of this software
#  code is at your own risk and you waive any claim against Amazon
#  Digital Services, Inc. or its affiliates with respect to your use of
#  this software code. (c) 2006 Amazon Digital Services, Inc. or its
#  affiliates.
#  
# This software code is made available "AS IS" without warranties of any        
# kind.  You may copy, display, modify and redistribute the software            
# code either by itself or as incorporated into your code; provided that        
# you do not remove any proprietary notices.  Your use of this software         
# code is at your own risk and you waive any claim against SilvaSoft, Inc.
# with respect to your use of this software code. 
# (c) 2006 SilvaSoft, Inc.
#
# This software code is made available "AS IS" without warranties of any        
# kind.  You may copy, display, modify and redistribute the software            
# code either by itself or as incorporated into your code; provided that        
# you do not remove any proprietary notices.  Your use of this software         
# code is at your own risk and you waive any claim against the author
# with respect to your use of this software code. 
# (c) 2006 Gregory Bell
#
require 'S3'
require 'HTTPStreaming'

# The purpose of this file is to overlay the S3 library from AWS
# to add some functionality
# (without changing the file itself or requiring a specific version)
# It still isn't perfectly robust, i.e. if radical changes are made
# to the underlying lib this stuff will need updating.

module S3
	class AWSAuthConnection
	
		# add support for streaming the response body to an IO stream
		alias __make_request__ make_request
		def make_request(method, path, headers={}, data='', metadata={}, streamOut=nil)
			@http.start unless @http.started?
			req = method_to_request_class(method).new("/#{path}")
			
			set_headers(req, headers)
			set_headers(req, metadata, METADATA_PREFIX)
			set_headers(req, {'Connection' => 'keep-alive', 'Keep-Alive' => '300'})
			
			set_aws_auth_header(req, @aws_access_key_id, @aws_secret_access_key)
			if req.request_body_permitted?
			  return @http.request(req, data, streamOut)
			else
			  return @http.request(req, nil, streamOut)
			end
		end

		# a "get" operation that sends the body to an IO stream
		def get_stream(bucket, key, headers={}, streamOut=nil)
			return GetResponse.new(make_request('GET', "#{bucket}/#{CGI::escape key}", headers, '', {}, streamOut))
		end
		
	    # head - added by dominic@gmail.com
		def head(bucket, key=nil, headers={})
		  if key == nil
			return GetResponse.new(make_request('HEAD',"#{bucket}", headers))
		  else 
			return GetResponse.new(make_request('HEAD',"#{bucket}/#{CGI::escape key}", headers))
		  end
		end
		
		# allow ssl validation
		def verify_mode=(val)
			@http.verify_mode = val
		end
		def ca_path=(val)
			@http.ca_path = val
		end

	end
end
