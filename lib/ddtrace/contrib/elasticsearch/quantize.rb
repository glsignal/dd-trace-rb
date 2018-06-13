module Datadog
  module Contrib
    module Elasticsearch
      # Quantize contains ES-specific resource quantization tools.
      module Quantize
        PLACEHOLDER = '?'.freeze
        EXCLUDE_KEYS = [].freeze
        SHOW_KEYS = [:_index, :_type, :_id].freeze
        DEFAULT_OPTIONS = {
          exclude: EXCLUDE_KEYS,
          show: SHOW_KEYS,
          placeholder: PLACEHOLDER
        }.freeze

        # Taken from https://github.com/DataDog/dd-trace-java/blob/master/dd-trace-ot/src/main/java/datadog/opentracing/decorators/URLAsResourceName.java#L16
        # Matches any path segments with numbers in them. (exception for versioning: "/v1/")
        CAPTURE_PATH_SEGMENTS_WITH_NUMBERS_REGEXP = %r{(?<=/)(?![vV]\d\{1,2\}/)(?:[^/\d\?]*[\d]+[^/\?]*)}
        QUERY_STRING_REGEXP = /\?.*$/

        module_function

        def format_url(url)
          url.gsub(QUERY_STRING_REGEXP, ''.freeze)
             .gsub(CAPTURE_PATH_SEGMENTS_WITH_NUMBERS_REGEXP, PLACEHOLDER)
        end

        def format_body(body, options = {})
          format_body!(body, options)
        rescue StandardError
          options[:placeholder] || PLACEHOLDER
        end

        def format_body!(body, options = {})
          options = merge_options(DEFAULT_OPTIONS, options)

          # Determine if bulk query or not, based on content
          statements = body.end_with?("\n") ? body.split("\n") : [body]

          # Parse each statement and quantize them.
          statements.collect do |string|
            reserialize_json(string, options[:placeholder]) do |obj|
              Datadog::Quantization::Hash.format(obj, options)
            end
          end.join("\n")
        end

        def merge_options(original, additional)
          {}.tap do |options|
            # Show
            # If either is :all, value becomes :all
            options[:show] = if original[:show] == :all || additional[:show] == :all
                               :all
                             else
                               (original[:show] || []).dup.concat(additional[:show] || []).uniq
                             end

            # Exclude
            options[:exclude] = (original[:exclude] || []).dup.concat(additional[:exclude] || []).uniq
          end
        end

        # Parses a JSON object from a string, passes its value
        # to the block provided, and dumps its result back to JSON.
        # If JSON parsing fails, it prints fail_value.
        def reserialize_json(string, fail_value = PLACEHOLDER)
          return string unless block_given?
          begin
            JSON.dump(yield(JSON.parse(string)))
          rescue JSON::ParserError
            # If it can't parse/dump, don't raise an error.
            fail_value
          end
        end
      end
    end
  end
end
