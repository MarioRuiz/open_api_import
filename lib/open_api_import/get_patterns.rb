# frozen_string_literal: true

module LibOpenApiImport
  private

  def get_patterns(dpk, dpv)
    data_pattern = []
    effective_type = dpv[:type]
    effective_type = Array(effective_type).reject { |t| t == "null" }.first if effective_type.is_a?(Array)
    key = ruby_hash_key(dpk)

    if dpv.keys.include?(:pattern)
      pattern = dpv[:pattern].to_s
      pattern = pattern.gsub('\/', "/") if pattern.include?('\\\\/')
      pattern = pattern.gsub('\\x', '\\u00') if pattern.match?(/\\x[0-9ABCDEF][0-9ABCDEF]-/)
      pattern = pattern.gsub('\\x', '\\u') if pattern.include?('\\x')
      data_pattern << "#{key} #{Regexp.new(pattern).inspect}"
    elsif dpv.key?(:minLength) && dpv.key?(:maxLength)
      data_pattern << "#{key} #{ruby_symbol_literal("#{dpv[:minLength]}-#{dpv[:maxLength]}:LN$")}"
    elsif dpv.key?(:minLength) && !dpv.key?(:maxLength)
      data_pattern << "#{key} #{ruby_symbol_literal("#{dpv[:minLength]}:LN$")}"
    elsif !dpv.key?(:minLength) && dpv.key?(:maxLength)
      data_pattern << "#{key} #{ruby_symbol_literal("0-#{dpv[:maxLength]}:LN$")}"
    elsif dpv.key?(:minimum) && dpv.key?(:maximum) && (effective_type == "string")
      data_pattern << "#{key} #{ruby_symbol_literal("#{dpv[:minimum]}-#{dpv[:maximum]}:LN$")}"
    elsif dpv.key?(:minimum) && dpv.key?(:maximum)
      data_pattern << "#{key} #{dpv[:minimum].inspect}..#{dpv[:maximum].inspect}"
    elsif dpv.key?(:minimum) && !dpv.key?(:maximum)
      data_pattern << "#{key} #{dpv[:minimum].inspect}.. "
    elsif !dpv.key?(:minimum) && dpv.key?(:maximum)
      data_pattern << "#{key} 0..#{dpv[:maximum].inspect}"
    elsif dpv[:format] == "date-time"
      data_pattern << "#{key} DateTime"
    elsif effective_type == "boolean"
      data_pattern << "#{key} Boolean"
    elsif dpv.key?(:enum)
      data_pattern << "#{key} #{dpv[:enum].join("|").to_sym.inspect}"
    elsif (effective_type == "array") && dpv.key?(:items) && dpv[:items].is_a?(Hash) && dpv[:items].key?(:enum) && dpv[:items][:enum].is_a?(Array)
      data_pattern << "#{key} [#{dpv[:items][:enum].join("|").to_sym.inspect}]"
    elsif (effective_type == "array") && dpv.key?(:items) && dpv[:items].is_a?(Hash) && !dpv[:items].key?(:enum) && dpv[:items].key?(:properties)
      dpv[:items][:properties].each do |dpkk, dpvv|
        if dpk == ""
          data_pattern += get_patterns(dpkk.to_s, dpvv)
        else
          data_pattern += get_patterns("#{dpk}.#{dpkk}", dpvv)
        end
      end
    elsif (effective_type == "array") && dpv.key?(:items) && dpv[:items].is_a?(Hash) &&
          !dpv[:items].key?(:enum) && !dpv[:items].key?(:properties) && dpv[:items].key?(:type)
      result = get_patterns("", dpv[:items])
      if result.empty?
        item_type = dpv[:items][:type]
        item_type = Array(item_type).reject { |t| t == "null" }.first if item_type.is_a?(Array)
        data_pattern << "#{key} [#{item_type.to_s.to_sym.inspect}]"
      else
        data_pattern << "#{key} [ #{result.join[4..]} ]"
      end
    elsif (effective_type == "object") && dpv.key?(:properties)
      dpv[:properties].each do |dpkk, dpvv|
        if dpk == ""
          data_pattern += get_patterns(dpkk.to_s, dpvv)
        else
          data_pattern += get_patterns("#{dpk}.#{dpkk}", dpvv)
        end
      end
    end
    data_pattern.uniq!
    data_pattern
  end
end
