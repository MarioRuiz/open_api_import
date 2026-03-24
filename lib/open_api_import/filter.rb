module LibOpenApiImport
  private def filter(hash, keys, nested = false)
    result = {}
    keys = [keys] unless keys.is_a?(Array)
    if nested
      result = hash.nice_filter(keys)
    else
      keys.each do |k|
        if k.is_a?(Symbol) and hash.key?(k)
          if hash[k].is_a?(Hash)
            result[k] = {}
          else
            result[k] = hash[k]
          end
        elsif k.is_a?(Symbol) and k.to_s.include?(".") and hash.key?((k.to_s.scan(/(\w+)\./).join).to_sym)
          kn = k.to_s.split(".")
          vn = kn[1].to_sym
          result[kn.first.to_sym] ||= {}
          result[kn.first.to_sym][vn] = filter(hash[kn.first.to_sym], vn).values[0]
        elsif k.is_a?(Hash) and hash.key?(k.keys[0])
          result[k.keys[0]] ||= {}
          result[k.keys[0]][k.values[0]] = filter(hash[k.keys[0]], k.values[0]).values[0]
        end
      end
    end
    result
  end
end
