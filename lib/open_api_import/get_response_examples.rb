# frozen_string_literal: true

module LibOpenApiImport
  private

  # Retrieve the response examples from the hash
  def get_response_examples(v, remove_readonly = false)
    # TODO: take in consideration the case allOf, oneOf... schema.items.allOf[0].properties schema.items.allOf[1].properties
    # example on https://github.com/OAI/OpenAPI-Specification/blob/master/examples/v2.0/yaml/petstore-expanded.yaml
    v = v.dup
    response_example = []
    # for open api 3.0 with responses schema inside content
    if v.key?(:content) && v[:content].is_a?(Hash) && v[:content].key?(:"application/json") &&
       v[:content][:"application/json"].key?(:schema)
      v = v[:content][:"application/json"].dup
    end
    if v.key?(:examples) && v[:examples].is_a?(Hash) && v[:examples].key?(:"application/json")
      example = v[:examples][:"application/json"]
      if example.is_a?(Array)
        response_example << "["
        example.each { |item| response_example << "#{item.inspect}, " }
        response_example << "]"
      else
        response_example << example.inspect
      end
      # for open api 3.0. examples on reponses, for example: api-with-examples.yaml
    elsif v.key?(:content) && v[:content].is_a?(Hash) && v[:content].key?(:"application/json") &&
          v[:content][:"application/json"].key?(:examples)
      v[:content][:"application/json"][:examples].each_value do |tv|
        # TODO: for the moment we only take in consideration the first example of response.
        # we need to decide how to manage to do it correctly
        if tv.key?(:value)
          tresp = tv[:value]
        else
          tresp = ""
        end
        if tresp.is_a?(Array)
          response_example << "["
          tresp.each { |item| response_example << "#{item.inspect}, " }
          response_example << "]"
        else
          response_example << tresp.inspect
        end
        break # only the first one it is considered
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

      if !response_example.empty? && !(v[:schema].key?(:properties) || v[:schema].key?(:allOf)) # array, items
        response_example << "]"
      end
    elsif v.key?(:schema) && v[:schema].key?(:items) && v[:schema][:items].is_a?(Hash) && v[:schema][:items].key?(:type)
      # for the case only type supplied but nothing else for the array
      response_example << [v[:schema][:items][:type].to_s].inspect
    end
    response_example.each do |rs|
      # (@type Google) for the case in example the key is something like: @type:
      if rs.match?(/^\s*@\w+:/)
        rs.gsub!(/@(\w+):/, '\'@\1\':')
      end
    end
    response_example
  end
end
