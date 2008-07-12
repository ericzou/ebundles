require "fileutils"

module TextMate
  class << self
    # 
    # Calling TextMate.save ensures that one of the following hold true:
    #  1. If TM_FILEPATH is writeable, then the current document is saved.
    #     In this case, TM_FILEPATH, TM_FILENAME, TM_DISPLAYNAME are left as is.
    #  2. If TM_FILEPATH is not writeable, then the contents of the current
    #     document will be saved in a temporary file.
    #     In this case:
    #       TM_FILEPATH, TM_FILENAME reflect the temporary file.
    #       TM_ORIG_FILEPATH and TM_ORIG_FILENAME will reflect the original unwriteable file.
    #       TM_DISPLAYNAME will be annotated by (M) to show that the file has not been saved.
    #  3. If TM_FILEPATH is unset, the current document has never been saved.  
    #     The current document's content will be saved in a temporary file.
    #     In this case: 
    #       TM_FILEPATH, TM_FILENAME reflect the temporary file.
    #       TM_FILE_IS_UNTITLED will be set to “true”
    #       TM_DISPLAYNAME will be set to “untitled”
    #  There is a funny case where if a new file file has been created with `mate` but has
    #  not yet been saved.  In this case TM_FILEPATH is set, but no file exists at that
    #  path.  If the directory is writeable, we touch the file and fall through to the 
    #  above cases.  If the directory is unwritable, we fall through without action.
    #    
    # Note that this method calls STDIN.read.  If you want to access the contents of the
    # current document after you've called this method, do File.read(ENV['TM_FILEPATH']).

    def save_current_document()
      
      doc, dst = STDIN.read, ENV['TM_FILEPATH']
      ENV['TM_DISPLAYNAME'] = ENV['TM_FILENAME']
      
      unless dst.nil?
        FileUtils.touch(dst) unless File.exists?(dst) or not File.writable?(File.dirname(dst))
        return if File.exists?(dst) and File.read(dst) == doc
      end
      
      if dst.nil?
        ENV['TM_FILEPATH']         = dst = TextMate::IO.tempfile("tmp").path
        ENV['TM_FILENAME']         = File.basename dst
        ENV['TM_FILE_IS_UNTITLED'] = "true"
        ENV['TM_DISPLAYNAME']      = 'untitled'        
      elsif not File.writable? dst
        ENV['TM_ORIG_FILEPATH']    = dst
        ENV['TM_ORIG_FILENAME']    = File.basename dst
        ENV['TM_FILEPATH']         = dst = TextMate::IO.tempfile("tmp").path
        ENV['TM_FILENAME']         = File.basename dst
        ENV['TM_DISPLAYNAME']     += ' (M)'
      end
      
      begin
        open(dst, 'w') { |io| io << doc }
      rescue Errno::EACCES
        # we already checked writable? so this is a real issue
      end
    end
  end
end