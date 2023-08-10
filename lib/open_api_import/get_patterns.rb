module LibOpenApiImport
  # Get patterns
  private def get_patterns(dpk, dpv)
    data_pattern = []
    if dpv.keys.include?(:pattern)
      #todo: control better the cases with back slashes
      if dpv[:pattern].include?('\\\\/')
        #for cases like this: ^[^\.\\/:*?"<>|][^\\/:*?"<>|]{0,13}[^\.\\/:*?"<>|]?$
        data_pattern << "'#{dpk}': /#{dpv[:pattern].to_s.gsub('\/', "/")}/"
      elsif dpv[:pattern].match?(/\\x[0-9ABCDEF][0-9ABCDEF]\-/)
        data_pattern << "'#{dpk}': /#{dpv[:pattern].to_s.gsub('\\x', '\\u00')}/"
      elsif dpv[:pattern].include?('\\x')
        data_pattern << "'#{dpk}': /#{dpv[:pattern].to_s.gsub('\\x', '\\u')}/"
      else
        data_pattern << "'#{dpk}': /#{dpv[:pattern].to_s}/"
      end
    elsif dpv.key?(:minLength) and dpv.key?(:maxLength)
      data_pattern << "'#{dpk}': :'#{dpv[:minLength]}-#{dpv[:maxLength]}:LN$'"
    elsif dpv.key?(:minLength) and !dpv.key?(:maxLength)
      data_pattern << "'#{dpk}': :'#{dpv[:minLength]}:LN$'"
    elsif !dpv.key?(:minLength) and dpv.key?(:maxLength)
      data_pattern << "'#{dpk}': :'0-#{dpv[:maxLength]}:LN$'"
    elsif dpv.key?(:minimum) and dpv.key?(:maximum) and dpv[:type] == "string"
      data_pattern << "'#{dpk}': :'#{dpv[:minimum]}-#{dpv[:maximum]}:LN$'"
    elsif dpv.key?(:minimum) and dpv.key?(:maximum)
      data_pattern << "'#{dpk}': #{dpv[:minimum]}..#{dpv[:maximum]}"
    elsif dpv.key?(:minimum) and !dpv.key?(:maximum)
      if RUBY_VERSION >= "2.6.0"
        data_pattern << "'#{dpk}': #{dpv[:minimum]}.. "
      else
        data_pattern << "#'#{dpk}': #{dpv[:minimum]}.. # INFINITE only working on ruby>=2.6.0"
      end
    elsif !dpv.key?(:minimum) and dpv.key?(:maximum)
      data_pattern << "'#{dpk}': 0..#{dpv[:maximum]}"
    elsif dpv[:format] == "date-time"
      data_pattern << "'#{dpk}': DateTime"
    elsif dpv[:type] == "boolean"
      data_pattern << "'#{dpk}': Boolean"
    elsif dpv.key?(:enum)
      data_pattern << "'#{dpk}': :'#{dpv[:enum].join("|")}'"
    elsif dpv[:type] == "array" and dpv.key?(:items) and dpv[:items].is_a?(Hash) and dpv[:items].key?(:enum) and dpv[:items][:enum].is_a?(Array)
      #{:title=>"Balala", :type=>"array", :items=>{:type=>"string", :enum=>["uno","dos"], :example=>"uno"}}
      data_pattern << "'#{dpk}': [:'#{dpv[:items][:enum].join("|")}']"
    elsif dpv[:type] == "array" and dpv.key?(:items) and dpv[:items].is_a?(Hash) and !dpv[:items].key?(:enum) and dpv[:items].key?(:properties)
      #{:title=>"Balala", :type=>"array", :items=>{title: 'xxxx, properties: {server: {enum:['ibm','msa','pytan']}}}
      dpv[:items][:properties].each do |dpkk, dpvv|
        if dpk == ""
          data_pattern += get_patterns("#{dpkk}", dpvv)
        else
          data_pattern += get_patterns("#{dpk}.#{dpkk}", dpvv)
        end
      end
    elsif dpv[:type] == "array" and dpv.key?(:items) and dpv[:items].is_a?(Hash) and
          !dpv[:items].key?(:enum) and !dpv[:items].key?(:properties) and dpv[:items].key?(:type)
      #{:title=>"labels", :description=>"Labels specified for the file system", :type=>"array", :items=>{:type=>"string", :enum=>["string"]}}
      data_pattern << "'#{dpk}': [ #{get_patterns("", dpv[:items]).join[4..-1]} ]"
    elsif dpv[:type] == "object" and dpv.key?(:properties)
      dpv[:properties].each do |dpkk, dpvv|
        if dpk == ""
          data_pattern += get_patterns("#{dpkk}", dpvv)
        else
          data_pattern += get_patterns("#{dpk}.#{dpkk}", dpvv)
        end
      end
    end
    data_pattern.uniq!
    return data_pattern
  end
end
