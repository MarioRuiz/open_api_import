# frozen_string_literal: true

module LibOpenApiImport
  private

  def get_examples(properties, type = :key_value, remove_readonly = false)
    example = []
    example << "{" unless properties.empty? || (type == :only_value)
    properties.each do |prop, val|
      unless remove_readonly && val.key?(:readOnly) && (val[:readOnly] == true)
        effective_type = val[:type]
        if val.key?(:properties) && !val.key?(:example) && !val.key?(:type)
          effective_type = "object"
        end
        if val.key?(:items) && !val.key?(:example) && !val.key?(:type)
          effective_type = "array"
        end

        effective_type = Array(effective_type).reject { |t| t == "null" }.first if effective_type.is_a?(Array)

        effective_example = val[:example]
        effective_example ||= val[:examples]&.first if val.key?(:examples) && val[:examples].is_a?(Array) && !val[:examples].empty?

        if effective_example
          if effective_example.is_a?(Array) && val.key?(:type) && (val[:type] == "string")
            example << " #{prop.to_sym}: \"#{effective_example[0]}\", "
          elsif effective_example.is_a?(String)
            escaped = effective_example.include?("'") ? effective_example : effective_example.gsub('"', "'")
            example << " #{prop.to_sym}: \"#{escaped}\", "
          elsif effective_example.is_a?(Time)
            example << " #{prop.to_sym}: \"#{effective_example}\", "
          else
            example << " #{prop.to_sym}: #{effective_example}, "
          end
        elsif effective_type
          format = val[:format]
          format = effective_type if format.to_s == ""
          case effective_type.downcase
          when "string"
            example << " #{prop.to_sym}: \"#{format}\", "
          when "integer"
            example << " #{prop.to_sym}: 0, "
          when "number"
            format_name = format.to_s.downcase
            number_value = if %w[float double decimal].include?(format_name)
                             "0.0"
                           else
                             "0"
                           end
            example << " #{prop.to_sym}: #{number_value}, "
          when "boolean"
            example << " #{prop.to_sym}: true, "
          when "array"
            items_enum = if val.key?(:items) && val[:items].is_a?(Hash) && (val[:items].size == 1) && val[:items].key?(:type)
                           [val[:items][:type]]
                         elsif val.key?(:items) && !val[:items].nil? && val[:items].key?(:enum)
                           val[:items][:enum]
                         end

            if items_enum
              if type == :only_value
                if items_enum[0].is_a?(String)
                  example << " [\"#{items_enum[0]}\"] "
                else
                  example << " [#{items_enum[0]}] "
                end
              elsif items_enum[0].is_a?(String)
                example << " #{prop.to_sym}: [\"#{items_enum[0]}\"], "
              else
                example << " #{prop.to_sym}: [#{items_enum[0]}], "
              end
            else
              examplet = get_response_examples({ schema: val }, remove_readonly).join("\n")
              examplet = "[]" if examplet.empty?
              if type == :only_value
                example << examplet
              else
                example << " #{prop.to_sym}: #{examplet}, "
              end
            end
          when "object"
            res_ex = get_response_examples({ schema: val }, remove_readonly)
            if res_ex.empty?
              res_ex = "{ }"
            else
              res_ex = res_ex.join("\n")
            end
            example << " #{prop.to_sym}: #{res_ex}, "
          else
            example << " #{prop.to_sym}: \"#{format}\", "
          end
        end
      end
    end
    example << "}" unless properties.empty? || (type == :only_value)
    example
  end
end
