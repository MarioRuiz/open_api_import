# frozen_string_literal: true

module LibOpenApiImport
  private def get_patterns(dpk, dpv)
    data_pattern = []
    effective_type = dpv[:type]
    effective_type = Array(effective_type).reject { |t| t == "null" }.first if effective_type.is_a?(Array)

    if dpv.keys.include?(:pattern)
      if dpv[:pattern].include?('\\\\/')
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
    elsif dpv.key?(:minimum) and dpv.key?(:maximum) and effective_type == "string"
      data_pattern << "'#{dpk}': :'#{dpv[:minimum]}-#{dpv[:maximum]}:LN$'"
    elsif dpv.key?(:minimum) and dpv.key?(:maximum)
      data_pattern << "'#{dpk}': #{dpv[:minimum]}..#{dpv[:maximum]}"
    elsif dpv.key?(:minimum) and !dpv.key?(:maximum)
      if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("2.6.0")
        data_pattern << "'#{dpk}': #{dpv[:minimum]}.. "
      else
        data_pattern << "#'#{dpk}': #{dpv[:minimum]}.. # INFINITE only working on ruby>=2.6.0"
      end
    elsif !dpv.key?(:minimum) and dpv.key?(:maximum)
      data_pattern << "'#{dpk}': 0..#{dpv[:maximum]}"
    elsif dpv[:format] == "date-time"
      data_pattern << "'#{dpk}': DateTime"
    elsif effective_type == "boolean"
      data_pattern << "'#{dpk}': Boolean"
    elsif dpv.key?(:enum)
      data_pattern << "'#{dpk}': :'#{dpv[:enum].join("|")}'"
    elsif effective_type == "array" and dpv.key?(:items) and dpv[:items].is_a?(Hash) and dpv[:items].key?(:enum) and dpv[:items][:enum].is_a?(Array)
      data_pattern << "'#{dpk}': [:'#{dpv[:items][:enum].join("|")}']"
    elsif effective_type == "array" and dpv.key?(:items) and dpv[:items].is_a?(Hash) and !dpv[:items].key?(:enum) and dpv[:items].key?(:properties)
      dpv[:items][:properties].each do |dpkk, dpvv|
        if dpk == ""
          data_pattern += get_patterns("#{dpkk}", dpvv)
        else
          data_pattern += get_patterns("#{dpk}.#{dpkk}", dpvv)
        end
      end
    elsif effective_type == "array" and dpv.key?(:items) and dpv[:items].is_a?(Hash) and
          !dpv[:items].key?(:enum) and !dpv[:items].key?(:properties) and dpv[:items].key?(:type)
      result = get_patterns("", dpv[:items])
      if result.empty?
        item_type = dpv[:items][:type]
        item_type = Array(item_type).reject { |t| t == "null" }.first if item_type.is_a?(Array)
        data_pattern << "'#{dpk}': [:'#{item_type}']"
      else
        data_pattern << "'#{dpk}': [ #{result.join[4..-1]} ]"
      end
    elsif effective_type == "object" and dpv.key?(:properties)
      dpv[:properties].each do |dpkk, dpvv|
        if dpk == ""
          data_pattern += get_patterns("#{dpkk}", dpvv)
        else
          data_pattern += get_patterns("#{dpk}.#{dpkk}", dpvv)
        end
      end
    end
    data_pattern.uniq!
    data_pattern
  end
end
