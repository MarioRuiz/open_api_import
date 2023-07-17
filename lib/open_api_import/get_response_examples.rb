module LibOpenApiImport
  # Retrieve the response examples from the hash
  private def get_response_examples(v, remove_readonly = false)
    # TODO: take in consideration the case allOf, oneOf... schema.items.allOf[0].properties schema.items.allOf[1].properties
    # example on https://github.com/OAI/OpenAPI-Specification/blob/master/examples/v2.0/yaml/petstore-expanded.yaml
    v = v.dup
    response_example = Array.new()
    # for open api 3.0 with responses schema inside content
    if v.key?(:content) && v[:content].is_a?(Hash) && v[:content].key?(:'application/json') &&
       v[:content][:'application/json'].key?(:schema)
      v = v[:content][:'application/json'].dup
    end
    if v.key?(:examples) && v[:examples].is_a?(Hash) && v[:examples].key?(:'application/json')
      if v[:examples][:'application/json'].is_a?(String)
        response_example << v[:examples][:'application/json']
      elsif v[:examples][:'application/json'].is_a?(Hash)
        exs = v[:examples][:'application/json'].to_s
        exs.gsub!(/:(\w+)=>/, "\n\\1: ")
        response_example << exs
      elsif v[:examples][:'application/json'].is_a?(Array)
        response_example << "["
        v[:examples][:'application/json'].each do |ex|
          exs = ex.to_s
          if ex.is_a?(Hash)
            exs.gsub!(/:(\w+)=>/, "\n\\1: ")
          end
          response_example << (exs + ", ")
        end
        response_example << "]"
      end
      # for open api 3.0. examples on reponses, for example: api-with-examples.yaml
    elsif v.key?(:content) && v[:content].is_a?(Hash) && v[:content].key?(:'application/json') &&
          v[:content][:'application/json'].key?(:examples)
      v[:content][:'application/json'][:examples].each do |tk, tv|
        #todo: for the moment we only take in consideration the first example of response.
        # we need to decide how to manage to do it correctly
        if tv.key?(:value)
          tresp = tv[:value]
        else
          tresp = ""
        end
        if tresp.is_a?(String)
          response_example << tresp
        elsif tresp.is_a?(Hash)
          exs = tresp.to_s
          exs.gsub!(/:(\w+)=>/, "\n\\1: ")
          response_example << exs
        elsif tresp.is_a?(Array)
          response_example << "["
          tresp.each do |ex|
            exs = ex.to_s
            if ex.is_a?(Hash)
              exs.gsub!(/:(\w+)=>/, "\n\\1: ")
            end
            response_example << (exs + ", ")
          end
          response_example << "]"
        end
        break #only the first one it is considered
      end
    elsif v.key?(:schema) && v[:schema].is_a?(Hash) &&
          (v[:schema].key?(:properties) ||
           (v[:schema].key?(:items) && v[:schema][:items].is_a?(Hash) && v[:schema][:items].key?(:properties)) ||
           (v[:schema].key?(:items) && v[:schema][:items].is_a?(Hash) && v[:schema][:items].key?(:allOf)) ||
           v[:schema].key?(:allOf))
      properties = {}
      if v[:schema].key?(:properties)
        properties = v[:schema][:properties]
      elsif v[:schema].key?(:allOf)
        v[:schema][:allOf].each do |pr|
          properties.merge!(pr[:properties]) if pr.key?(:properties)
        end
      elsif v[:schema][:items].key?(:properties)
        properties = v[:schema][:items][:properties]
        response_example << "["
      elsif v[:schema][:items].key?(:allOf)
        v[:schema][:items][:allOf].each do |pr|
          properties.merge!(pr[:properties]) if pr.key?(:properties)
        end
        response_example << "["
      end

      response_example += get_examples(properties, :key_value, remove_readonly) unless properties.empty?

      unless response_example.empty?
        if v[:schema].key?(:properties) || v[:schema].key?(:allOf)
          #
        else # array, items
          response_example << "]"
        end
      end
    elsif v.key?(:schema) and v[:schema].key?(:items) and v[:schema][:items].is_a?(Hash) and v[:schema][:items].key?(:type)
      # for the case only type supplied but nothing else for the array
      response_example << "[\"#{v[:schema][:items][:type]}\"]"
    end
    response_example.each do |rs|
      #(@type Google) for the case in example the key is something like: @type:
      if rs.match?(/^\s*@\w+:/)
        rs.gsub!(/@(\w+):/, '\'@\1\':')
      end
    end
    return response_example
  end
end
