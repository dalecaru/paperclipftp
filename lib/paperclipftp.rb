module Paperclip
  module Storage
    module Ftp
      def self.extended base
      	require 'net/ftp'
      	base.instance_eval do
      	  @ftp_credentials = parse_credentials
  	    end
      end
      
      def ftp
      	if @ftp.nil? || @ftp.closed?
      	  @ftp = Net::FTP.new(@ftp_credentials[:host], @ftp_credentials[:username], @ftp_credentials[:password])
  	    end
  	    @ftp
      end
      
      def exists?(style = default_style)
      	move_to_remote_path(File.dirname(path(style)))
      	ftp.size(File.basename(path(style))) > 0 ? true : false
      rescue Net::FTPPermError => e
      	#File not exists
      	false
      rescue Net::FTPReplyError => e
      	ftp.close
      	raise e
      end

      def to_file style = default_style
      	@queued_for_write[style] || "ftp://#{path(style)}"
      end
      alias_method :to_io, :to_file

      def flush_writes
      	@queued_for_write.each do |style, file|
          file.close
          move_to_remote_path(File.dirname(path(style)))
          log("uploading #{path(style)}")
          ftp.putbinaryfile(file.path, File.basename(path(style)))
        end
        @queued_for_write = {}
      rescue Net::FTPReplyError => e
      	raise e
      rescue Net::FTPPermError => e
      	raise e
      ensure
      	ftp.close
      end

      def flush_deletes
      	@queued_for_delete.each do |path|
          begin
            move_to_remote_path(File.dirname(path))
            log("deleting #{path}")
            ftp.delete(File.basename(path))
          rescue Net::FTPPermError, Net::FTPReplyError
          end
        end
        @queued_for_delete = []
      rescue Net::FTPReplyError => e
      	raise e
      rescue Net::FTPPermError => e
      	raise e
      ensure
      	ftp.close 
      end
      
      def move_to_remote_path(rpath)
      	ftp.chdir("/")
      	rpath.split(File::SEPARATOR).each do |rdir|
      	  rdir = rdir.strip
      	  unless rdir.blank?
      	  	list = ftp.ls.collect { |f| f.split.last }
      	    unless list.include?(rdir)
      	     ftp.mkdir(rdir)
  	  	    end
  	  	    ftp.chdir(rdir)
  	  	  end
 	    end
      end
      
      def parse_credentials
      	creds = YAML.load_file(File.join(RAILS_ROOT,"config","paperclipftp.yml"))
      	creds = creds.stringify_keys
        (creds[RAILS_ENV] || creds).symbolize_keys
      end
      private :parse_credentials
      
	end
  end
end