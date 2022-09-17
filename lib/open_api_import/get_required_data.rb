module LibOpenApiImport
  # Get required data
  private def get_required_data(body)
    data_required = []
    if body.keys.include?(:required) and body[:required].size > 0
      body[:required].each do |r|
        data_required << r.to_sym
      end
    end
    if body.key?(:allOf)
      body[:allOf].each do |r|
        if r.key?(:required)
          r[:required].each do |r2|
            data_required << r2.to_sym
          end
        end
      end
    end
    data_required.each do |key|
      if body.key?(:properties) and body[:properties][key].is_a?(Hash) and
         body[:properties][key].key?(:required) and body[:properties][key][:required].size > 0
        dr = get_required_data(body[:properties][key])
        dr.each do |k|
          data_required.push("#{key}.#{k}".to_sym)
        end
      end
    end
    return data_required
  end
end
