# frozen_string_literal: true

require "digest"
require "time"

module Http
  module Endpoints
    class Authors
      PATH = File.expand_path("../../../AUTHORS", __dir__)
      MAX_AGE = 86_400

      def initialize(path = PATH)
        @body = File.read(path)
        @etag = %(W/"#{Digest::SHA256.hexdigest(@body)}")
        @last_modified = Time.at(File.mtime(path).to_i).utc
      end

      def call(env)
        return [304, cache_headers, []] if fresh?(env)

        [200, cache_headers.merge("content-type" => "text/plain; charset=utf-8"), [@body]]
      end

      private

      def cache_headers
        {
          "cache-control" => "public, max-age=#{MAX_AGE}",
          "etag" => @etag,
          "last-modified" => @last_modified.httpdate
        }
      end

      def fresh?(env)
        if_none_match = env["HTTP_IF_NONE_MATCH"]
        return etag_matches?(if_none_match) if if_none_match

        if_modified_since = env["HTTP_IF_MODIFIED_SINCE"]
        return false unless if_modified_since

        Time.httpdate(if_modified_since) >= @last_modified
      rescue ArgumentError
        false
      end

      def etag_matches?(header)
        tags = header.split(",").map { |tag| tag.strip.delete_prefix("W/") }
        tags.include?("*") || tags.include?(@etag.delete_prefix("W/"))
      end
    end
  end
end
