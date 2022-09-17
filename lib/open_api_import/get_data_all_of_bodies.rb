module LibOpenApiImport
  private def get_data_all_of_bodies(p)
    bodies = []
    data_examples_all_of = false
    if p.is_a?(Array)
      q = p
    elsif p.key?(:schema) and p[:schema].key?(:allOf)
      q = p[:schema][:allOf]
    else
      q = [p]
    end
    q.each do |pt|
      if pt.is_a?(Hash) and pt.key?(:allOf)
        bodies += get_data_all_of_bodies(pt[:allOf])[1]
        data_examples_all_of = true
      else
        bodies << pt
      end
    end
    return data_examples_all_of, bodies
  end
end
