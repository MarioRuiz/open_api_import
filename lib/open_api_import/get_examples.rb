module LibOpenApiImport
  # Retrieve the examples from the properties hash
  private def get_examples(properties, type = :key_value, remove_readonly = false)
    #todo: consider using this method also to get data examples
    example = []
    example << "{" unless properties.empty? or type == :only_value
    properties.each do |prop, val|
      unless remove_readonly and val.key?(:readOnly) and val[:readOnly] == true
        if val.key?(:properties) and !val.key?(:example) and !val.key?(:type)
          val[:type] = "object"
        end
        if val.key?(:items) and !val.key?(:example) and !val.key?(:type)
          val[:type] = "array"
        end
        if val.key?(:example)
          if val[:example].is_a?(Array) and val.key?(:type) and val[:type] == "string"
            example << " #{prop.to_sym}: \"#{val[:example][0]}\", " # only the first example
          else
            if val[:example].is_a?(String)
              val[:example].gsub!('"', "'") unless val.include?("'")
              example << " #{prop.to_sym}: \"#{val[:example]}\", "
            elsif val[:example].is_a?(Time)
              example << " #{prop.to_sym}: \"#{val[:example]}\", "
            else
              example << " #{prop.to_sym}: #{val[:example]}, "
            end
          end
        elsif val.key?(:type)
          format = val[:format]
          format = val[:type] if format.to_s == ""
          case val[:type].downcase
          when "string"
            example << " #{prop.to_sym}: \"#{format}\", "
          when "integer", "number"
            example << " #{prop.to_sym}: 0, "
          when "boolean"
            example << " #{prop.to_sym}: true, "
          when "array"
            if val.key?(:items) and val[:items].size == 1 and val[:items].is_a?(Hash) and val[:items].key?(:type)
              val[:items][:enum] = [val[:items][:type]]
            end

            if val.key?(:items) and val[:items].key?(:enum)
              #before we were getting in all these cases a random value from the enum, now we are getting the first position by default
              #the reason is to avoid confusion later in case we want to compare two swaggers and verify the changes
              if type == :only_value
                if val[:items][:enum][0].is_a?(String)
                  example << " [\"" + val[:items][:enum][0] + "\"] "
                else
                  example << " [" + val[:items][:enum][0] + "] "
                end
              else
                if val[:items][:enum][0].is_a?(String)
                  example << " #{prop.to_sym}: [\"" + val[:items][:enum][0] + "\"], "
                else
                  example << " #{prop.to_sym}: [" + val[:items][:enum][0] + "], "
                end
              end
            else
              #todo: differ between response examples and data examples
              examplet = get_response_examples({ schema: val }, remove_readonly).join("\n")
              examplet = '[]' if examplet.empty?
              if type == :only_value
                example << examplet
              else
                example << " #{prop.to_sym}: " + examplet + ", "
              end              

            end
          when "object"
            #todo: differ between response examples and data examples
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
