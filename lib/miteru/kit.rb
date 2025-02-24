# frozen_string_literal: true

require "cgi"
require "uuidtools"
require "uri"

module Miteru
  class Kit
    VALID_EXTENSIONS = Miteru.configuration.valid_extensions
    VALID_MIME_TYPES = Miteru.configuration.valid_mime_types

    # @return [String]
    attr_reader :url

    # @return [String]
    attr_reader :source

    # @return [Integer, nil]
    attr_reader :status

    # @return [Integer, nil]
    attr_reader :content_length

    # @return [String, nil]
    attr_reader :mime_type

    # @return [Hash, nil]
    attr_reader :headers

    def initialize(url, source)
      @url = url
      @source = source

      @content_length = nil
      @mime_type = nil
      @status = nil
      @headers = nil
    end

    def valid?
      # make a HEAD request for the validation
      before_validation

      valid_ext? && reachable? && valid_mime_type? && valid_content_length?
    end

    def extname
      return ".tar.gz" if url.end_with?("tar.gz")

      File.extname(url)
    end

    def basename
      @basename ||= File.basename(url)
    end

    def filename
      @filename ||= CGI.unescape(basename)
    end

    def filepath_to_download
      "#{base_dir}/#{filename_to_download}"
    end

    def downloaded?
      File.exist?(filepath_to_download)
    end

    def filesize
      return nil unless downloaded?

      File.size filepath_to_download
    end

    def filename_with_size
      return filename unless filesize

      kb = (filesize.to_f / 1024.0).ceil
      "#{filename}(#{kb}KB)"
    end

    def id
      @id ||= UUIDTools::UUID.random_create.to_s
    end

    def hostname
      @hostname ||= URI(url).hostname
    end

    def decoded_url
      @decoded_url ||= URI.decode_www_form_component(url)
    end

    private

    def filename_to_download
      "#{id}#{extname}"
    end

    def base_dir
      @base_dir ||= Miteru.configuration.download_to
    end

    def valid_ext?
      VALID_EXTENSIONS.include? extname
    end

    def before_validation
      res = HTTPClient.head(url)
      @content_length = res.content_length
      @mime_type = res.content_type.mime_type.to_s
      @status = res.status
      @headers = res.headers.to_h
    rescue StandardError
      # do nothing
    end

    def reachable?
      status&.success?
    end

    def valid_mime_type?
      VALID_MIME_TYPES.include? mime_type
    end

    def valid_content_length?
      content_length.to_i > 0
    end
  end
end
