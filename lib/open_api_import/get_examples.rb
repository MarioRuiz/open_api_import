# frozen_string_literal: true

module LibOpenApiImport
  private def get_examples(properties, type = :key_value, remove_readonly = false)
    example = []
    example << "{" unless properties.empty? or type == :only_value
    properties.each do |prop, val|
      unless remove_readonly and val.key?(:readOnly) and val[:readOnly] == true
        effective_type = val[:type]
        if val.key?(:properties) and !val.key?(:example) and !val.key?(:type)
          effective_type = "object"
        end
        if val.key?(:items) and !val.key?(:example) and !val.key?(:type)
          effective_type = "array"
        end

        effective_type = Array(effective_type).reject { |t| t == "null" }.first if effective_type.is_a?(Array)

        effective_example = val[:example]
        effective_example ||= val[:examples]&.first if val.key?(:examples) && val[:examples].is_a?(Array) && !val[:examples].empty?

        if effective_example
          if effective_example.is_a?(Array) and val.key?(:type) and val[:type] == "string"
            example << " #{prop.to_sym}: \"#{effective_example[0]}\", "
          else
            if effective_example.is_a?(String)
              escaped = effective_example.include?("'") ? effective_example : effective_example.gsub('"', "'")
              example << " #{prop.to_sym}: \"#{escaped}\", "
            elsif effective_example.is_a?(Time)
              example << " #{prop.to_sym}: \"#{effective_example}\", "
            else
              example << " #{prop.to_sym}: #{effective_example}, "
            end
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
            items_enum = if val.key?(:items) and val[:items].is_a?(Hash) and val[:items].size == 1 and val[:items].key?(:type)
                [val[:items][:type]]
              elsif val.key?(:items) and !val[:items].nil? and val[:items].key?(:enum)
                val[:items][:enum]
              else
                nil
              end

            if items_enum
              if type == :only_value
                if items_enum[0].is_a?(String)
                  example << " [\"" + items_enum[0] + "\"] "
                else
                  example << " [" + items_enum[0] + "] "
                end
              else
                if items_enum[0].is_a?(String)
                  example << " #{prop.to_sym}: [\"" + items_enum[0] + "\"], "
                else
                  example << " #{prop.to_sym}: [" + items_enum[0] + "], "
                end
              end
            else
              examplet = get_response_examples({ schema: val }, remove_readonly).join("\n")
              examplet = "[]" if examplet.empty?
              if type == :only_value
                example << examplet
              else
                example << " #{prop.to_sym}: " + examplet + ", "
              end
            end
          when "object"
            res_ex = get_response_examples({ schema: val }, remove_readonly)
            if res_ex.size == 0
              res_ex = "{ }"
            else
              res_ex = res_ex.join("\n")
            end
            example << " #{prop.to_sym}: " + res_ex + ", "
          else
            example << " #{prop.to_sym}: \"#{format}\", "
          end
        end
      end
    end
    example << "}" unless properties.empty? or type == :only_value
    example
  end
end
