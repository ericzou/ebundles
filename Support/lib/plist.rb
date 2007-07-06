#--
##############################################################
# Copyright 2006, Ben Bleything <ben@bleything.net> and      #
# Patrick May <patrick@hexane.org>                           #
#                                                            #
# Distributed under the MIT license.                         #
##############################################################
#++
# = Plist
#
# This is the main file for plist.  Everything interesting happens in Plist and Plist::Emit.

require 'base64'
require 'cgi'
require 'stringio'

require "#{ENV['TM_SUPPORT_PATH']}/lib/plist/parser"
require "#{ENV['TM_SUPPORT_PATH']}/lib/plist/generator"

module Plist
  VERSION = '3.0.0'
end
