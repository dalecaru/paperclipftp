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
        file_size(path(style)) > 0
      end

      def to_file style = default_style
        return @queued_for_write[style] if @queued_for_write[style]
        file = Tempfile.new(path(style))
        ftp.getbinaryfile(path(style), file.path)
        file.rewind
        return file
      end

      alias_method :to_io, :to_file

      def flush_writes
        @queued_for_write.each do |style, file|
          local_file_size = file.size
          file.close
          remote_path = path(style)
          ensure_parent_folder_for(remote_path)
          log("uploading #{remote_path}")
          ftp.putbinaryfile(file.path, remote_path)
          remote_file_size = file_size(remote_path)
          raise Net::FTPError.new "Uploaded #{remote_file_size} bytes instead of #{local_file_size} bytes" unless remote_file_size == local_file_size
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
            log("deleting #{path}")
            ftp.delete(path)
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

      def ensure_parent_folder_for(remote_path)
        dir_path = File.dirname(remote_path)
        ftp.chdir("/")
        dir_path.split(File::SEPARATOR).each do |rdir|
          rdir = rdir.strip
          unless rdir.blank?
            list = ftp.ls.collect { |f| f.split.last }
            unless list.include?(rdir)
             ftp.mkdir(rdir)
            end
            ftp.chdir(rdir)
          end
        end
        ftp.chdir("/")
      end

      private

      def parse_credentials
        creds = YAML.load_file(File.join(RAILS_ROOT,"config","paperclipftp.yml"))
        creds = creds.stringify_keys
        (creds[RAILS_ENV] || creds).symbolize_keys
      end

      def file_size(remote_path)
        ftp.size(remote_path)
      rescue Net::FTPPermError => e
        #File not exists
        -1
      rescue Net::FTPReplyError => e
        ftp.close
        raise e
      end

    end
  end
end
