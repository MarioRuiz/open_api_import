# frozen_string_literal: true

module LibOpenApiImport
  private

  def get_required_data(body)
    data_required = []
    if body.key?(:required) && body[:required].size.positive?
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
    nested_required = []
    data_required.each do |key|
      if body.key?(:properties) && body[:properties][key].is_a?(Hash) &&
         body[:properties][key].key?(:required) && body[:properties][key][:required].size.positive?
        dr = get_required_data(body[:properties][key])
        dr.each do |k|
          nested_required << :"#{key}.#{k}"
        end
      end
    end
    data_required.concat(nested_required)
    data_required
  end
end
