class OpenApiImport
    ##############################################################################################
    # Import a Swagger or Open API file and create a Ruby Request Hash file including all requests and responses.
    # The http methods that will be treated are: 'get','post','put','delete', 'patch'.
    # @param swagger_file [String]. Path and file name. Could be absolute or relative to project root folder.
    # @param include_responses [Boolean]. (default: true) if you want to add the examples of responses in the resultant file.
    # @param mock_response [Boolean]. (default:false) Add the first response on the request as mock_response to be used.
    #   In case using nice_http gem: if NiceHttp.use_mocks = true will use it instead of getting the real response from the WS.
    # @param create_method_name [Symbol]. (:path, :operation_id, :operationId) (default: operation_id). How the name of the methods will be generated.
    #   path: it will be used the path and http method, for example for a GET on path: /users/list, the method name will be get_users_list
    #   operation_id: it will be used the operationId field but using the snake_case version, for example for listUsers: list_users
    #   operationId: it will be used the operationId field like it is, for example: listUsers
    # @param name_for_module [Symbol]. (:path, :path_file, :fixed, :tags, :tags_file) (default: :path). How the module names will be created.
    # @param create_constants [Boolean]. (default: false) For required arguments, it will create keyword arguments assigning by default a constant.
    # @param silent [Boolean]. (default: false) It will display only errors.
    #   path: It will be used the first folder of the path to create the module name, for example the path /users/list will be in the module Users and all the requests from all modules in the same file.
    #   path_file: It will be used the first folder of the path to create the module name, for example the path /users/list will be in the module Users and each module will be in a new requests file.
    #   tags: It will be used the tags key to create the module name, for example the tags: [users,list] will create the module UsersList and all the requests from all modules in the same file.
    #   tags_file: It will be used the tags key to create the module name, for example the tags: [users,list] will create the module UsersList and and each module will be in a new requests file.
    #   fixed: all the requests will be under the module Requests
    ##############################################################################################
    def self.from(swagger_file, create_method_name: :operation_id, include_responses: true, mock_response: false, name_for_module: :path, silent: false, create_constants: false)
      begin
        f = File.new("#{swagger_file}_open_api_import.log", "w")
        f.sync = true
        @logger = Logger.new f
        puts "Logs file: #{swagger_file}_open_api_import.log" unless silent
      rescue StandardError => e
        warn "Not possible to create the Logger file"
        warn e
        @logger = Logger.new nil
      end
  
      begin
        @logger.info "swagger_file: #{swagger_file}, include_responses: #{include_responses}, mock_response: #{mock_response}\n"
        @logger.info "create_method_name: #{create_method_name}, name_for_module: #{name_for_module}\n"
  
        file_to_convert = if swagger_file["./"].nil?
            swagger_file
          else
            Dir.pwd.to_s + "/" + swagger_file.gsub("./", "")
          end
        unless File.exist?(file_to_convert)
          raise "The file #{file_to_convert} doesn't exist"
        end
  
        file_errors = file_to_convert + ".errors.log"
        File.delete(file_errors) if File.exist?(file_errors)
        import_errors = ""
        required_constants = []
  
        begin
          definition = OasParser::Definition.resolve(swagger_file)
        rescue Exception => stack
          message = "There was a problem parsing the Open Api document using the oas_parser_reborn gem. The execution was aborted.\n"
          message += "Visit the github for oas_parser_reborn gem for bugs and more info: https://github.com/MarioRuiz/oas_parser_reborn\n"
          message += "Error: #{stack.message}"
          puts message
          @logger.fatal message
          @logger.fatal stack.backtrace.join("\n")
          exit!
        end
  
        raw = definition.raw.deep_symbolize_keys
  
        if raw.key?(:openapi) && (raw[:openapi].to_f > 0)
          raw[:swagger] = raw[:openapi]
        end
        if raw[:swagger].to_f < 2.0
          raise "Unsupported Swagger version. Only versions >= 2.0 are valid."
        end
  
        base_host = ""
        base_path = ""
  
        base_host = raw[:host] if raw.key?(:host)
        base_path = raw[:basePath] if raw.key?(:basePath)
        module_name = raw[:info][:title].camel_case
        module_version = "V#{raw[:info][:version].to_s.snake_case}"
  
        output = []
        output_header = []
        output_header << "#" * 50
        output_header << "# #{raw[:info][:title]}"
        output_header << "# version: #{raw[:info][:version]}"
        output_header << "# description: "
        raw[:info][:description].to_s.split("\n").each do |d|
          output_header << "#     #{d}" unless d == ""
        end
        output_header << "#" * 50
  
        output_header << "module Swagger"
        output_header << "module #{module_name}"
        output_header << "module #{module_version}"
        output_header << "module Requests" if name_for_module == :fixed
  
        files = {}
  
        module_requests = ""
  
        definition.paths.each do |path|
          raw = path.raw.deep_symbolize_keys
  
          if raw.key?(:parameters)
            raw.each do |met, cont|
              if met != :parameters
                if raw[met].key?(:parameters)
                  #in case parameters for all methods in path is present
                  raw[met][:parameters] = raw[met][:parameters] + raw[:parameters]
                else
                  raw[met][:parameters] = raw[:parameters]
                end
              end
            end
            raw.delete(:parameters)
          end
  
          raw.each do |met, cont|
            if %w[get post put delete patch].include?(met.to_s.downcase)
              params = []
              params_path = []
              params_query = []
              params_required = []
              params_data = []
              description_parameters = []
              data_form = []
              data_required = []
              #todo: add nested one.true.three to data_read_only
              data_read_only = []
              data_default = []
              data_examples = []
              data_pattern = []
              responses = []
  
              # for the case operationId is missing
              cont[:operationId] = "undefined" unless cont.key?(:operationId)
  
              if create_method_name == :path
                method_name = (met.to_s + "_" + path.path.to_s).snake_case
                method_name.chop! if method_name[-1] == "_"
              elsif create_method_name == :operation_id
                if (name_for_module == :tags or name_for_module == :tags_file) and cont.key?(:tags) and cont[:tags].is_a?(Array) and cont[:tags].size > 0
                  metnametmp = cont[:operationId].gsub(/^#{cont[:tags].join}[\s_]*/, "")
                  cont[:tags].join.split(" ").each do |tag|
                    metnametmp.gsub!(/^#{tag}[\s_]*/i, "")
                  end
                  metnametmp = met if metnametmp == ""
                else
                  metnametmp = cont[:operationId]
                end
                method_name = metnametmp.to_s.snake_case
              else
                if (name_for_module == :tags or name_for_module == :tags_file) and cont.key?(:tags) and cont[:tags].is_a?(Array) and cont[:tags].size > 0
                  method_name = cont[:operationId].gsub(/^#{cont[:tags].join}[\s_]*/, "")
                  cont[:tags].join.split(" ").each do |tag|
                    method_name.gsub!(/^#{tag}[\s_]*/i, "")
                  end
                  method_name = met if method_name == ""
                else
                  method_name = cont[:operationId]
                end
              end
              path_txt = path.path.dup.to_s
              if [:path, :path_file, :tags, :tags_file].include?(name_for_module)
                old_module_requests = module_requests
                if [:path, :path_file].include?(name_for_module)
                  # to remove version from path fex: /v1/Customer
                  path_requests = path_txt.gsub(/^\/v[\d\.]*\//i, "")
                  # to remove version from path fex: /1.0/Customer
                  path_requests = path_requests.gsub(/^\/[\d\.]*\//i, "")
                  if (path_requests == path_txt) && (path_txt.scan("/").size == 1)
                    # no folder in path
                    module_requests = "Root"
                  else
                    res_path = path_requests.scan(/(\w+)/)
                    module_requests = res_path[0][0].camel_case
                  end
                else
                  if cont.key?(:tags) and cont[:tags].is_a?(Array) and cont[:tags].size > 0
                    module_requests = cont[:tags].join(" ").camel_case
                  else
                    module_requests = "Undefined"
                  end
                end
  
                # to remove from method_name: v1_list_regions and add it to module
                if /^(?<vers>v\d+)/i =~ method_name
                  method_name.gsub!(/^#{vers}_?/, "")
                  module_requests = (vers.capitalize + module_requests).camel_case unless module_requests.start_with?(vers)
                end
  
                if old_module_requests != module_requests
                  output << "end" unless old_module_requests == "" or name_for_module == :path_file or name_for_module == :tags_file
                  if name_for_module == :path or name_for_module == :tags
                    # to add the end for the previous module unless is the first one
                    output << "module #{module_requests}"
                  else #:path_file, :tags_file
                    if old_module_requests != ""
                      unless files.key?(old_module_requests)
                        files[old_module_requests] = Array.new
                      end
                      files[old_module_requests].concat(output)
                      output = Array.new
                    end
                    output << "module #{module_requests}" unless files.key?(module_requests) # don't add in case already existed
                  end
                end
              end
  
              output << ""
              output << "# operationId: #{cont[:operationId]}, method: #{met}"
              output << "# summary: #{cont[:summary].split("\n").join("\n#          ")}" if cont.key?(:summary)
              if !cont[:description].to_s.split("\n").empty?
                output << "# description: "
                cont[:description].to_s.split("\n").each do |d|
                  output << "#     #{d}" unless d == ""
                end
              else
                output << "# description: #{cont[:description]}"
              end
  
              mock_example = []
  
              if include_responses && cont.key?(:responses) && cont[:responses].is_a?(Hash)
                cont[:responses].each do |k, v|
                  response_example = []
                  response_example = get_response_examples(v)
  
                  data_pattern += get_patterns("", v[:schema]) if v.key?(:schema)
                  data_pattern.uniq!
                  v[:description] = v[:description].to_s.gsub("'", %q(\\\'))
                  if !response_example.empty?
                    responses << "'#{k}': { "
                    responses << "message: '#{v[:description]}', "
                    responses << "data: "
                    responses << response_example
                    responses << "},"
                    if mock_response and mock_example.size == 0
                      mock_example << "code: '#{k}',"
                      mock_example << "message: '#{v[:description]}',"
                      mock_example << "data: "
                      mock_example << response_example
                    end
                  else
                    responses << "'#{k}': { message: '#{v[:description]}'}, "
                  end
                end
              end
              # todo: for open api 3.0 add the new Link feature: https://swagger.io/docs/specification/links/
              # todo: for open api 3.0 is not getting the required params in all cases
  
              # for the case open api 3 with cont.requestBody.content.'applicatin/json'.schema
              # example: petstore-expanded.yaml operationId=addPet
              if cont.key?(:requestBody) and cont[:requestBody].key?(:content) and
                 cont[:requestBody][:content].key?(:'application/json') and cont[:requestBody][:content][:'application/json'].key?(:schema)
                cont[:parameters] = [] unless cont.key?(:parameters)
                cont[:parameters] << { in: "body", schema: cont[:requestBody][:content][:'application/json'][:schema] }
              end
  
              data_examples_all_of = false
              if cont.key?(:parameters) && cont[:parameters].is_a?(Array)
                cont[:parameters].each do |p|
                  if p.keys.include?(:schema) and p[:schema].include?(:type)
                    type = p[:schema][:type]
                  elsif p.keys.include?(:type)
                    type = p[:type]
                  else
                    type = ""
                  end
  
                  if p[:in] == "path"
                    if create_method_name == :operationId
                      param_name = p[:name]
                      path_txt.gsub!("{#{param_name}}", "\#{#{param_name}}")
                    else
                      param_name = p[:name].to_s.snake_case
                      path_txt.gsub!("{#{p[:name]}}", "\#{#{param_name}}")
                    end
                    unless params_path.include?(param_name)
                      if create_constants
                        params_path << "#{param_name}: #{param_name.upcase}"
                        required_constants << param_name.upcase
                      else
                        params_path << param_name
                      end
                      #params_required << param_name if p[:required].to_s=="true"
                      @logger.warn "Description key is missing for #{met} #{path.path} #{p[:name]}" if p[:description].nil?
                      description_parameters << "#    #{p[:name]}: (#{type}) #{"(required)" if p[:required].to_s == "true"} #{p[:description].to_s.split("\n").join("\n#\t\t\t")}"
                    end
                  elsif p[:in] == "query"
                    params_query << p[:name]
                    params_required << p[:name] if p[:required].to_s == "true"
                    @logger.warn "Description key is missing for #{met} #{path.path} #{p[:name]}" if p[:description].nil?
                    description_parameters << "#    #{p[:name]}: (#{type}) #{"(required)" if p[:required].to_s == "true"} #{p[:description].to_s.split("\n").join("\n#\t\t\t")}"
                  elsif p[:in] == "formData" or p[:in] == "formdata"
                    #todo: take in consideration: default, required
                    #todo: see if we should add the required as params to the method and not required as options
                    #todo: set on data the required fields with the values from args
  
                    description_parameters << "#    #{p[:name]}: (#{p[:type]}) #{p[:description].split("\n").join("\n#\t\t\t")}"
  
                    case p[:type]
                    when /^string$/i
                      data_form << "#{p[:name]}: ''"
                    when /^boolean$/i
                      data_form << "#{p[:name]}: true"
                    when /^number$/i
                      data_form << "#{p[:name]}: 0"
                    when /^integer$/i
                      data_form << "#{p[:name]}: 0"
                    else
                      puts "! on formData not supported type #{p[:type]}"
                    end
                  elsif p[:in] == "body"
                    if p.keys.include?(:schema)
                      if p[:schema].key?(:oneOf)
                        bodies = p[:schema][:oneOf]
                      elsif p[:schema].key?(:anyOf)
                        bodies = p[:schema][:anyOf]
                      elsif p[:schema].key?(:allOf)
                        data_examples_all_of, bodies = get_data_all_of_bodies(p)
                        bodies.unshift(p[:schema]) if p[:schema].key?(:required) or p.key?(:required) #todo: check if this 'if' is necessary
                        data_examples_all_of = true # because we are on data and allOf already
                      else
                        bodies = [p[:schema]]
                      end
  
                      params_data = []
        
                      bodies.each do |body|
                        data_required += get_required_data(body)                        
                        all_properties = []
                        all_properties << body[:properties] if body.keys.include?(:properties) and body[:properties].size > 0
                        if body.key?(:allOf)
                          body[:allOf].each do |item|
                            all_properties << item[:properties] if item.key?(:properties)
                          end
                        end

                        all_properties.each do |props|  
                          props.each { |dpk, dpv|
                            if dpv.keys.include?(:example)
                              if dpv[:example].is_a?(Array) and dpv.type != "array"
                                valv = dpv[:example][0]
                              else
                                valv = dpv[:example].to_s
                              end
                            else
                              if dpv.type == "object"
                                if dpv.key?(:properties)
                                  valv = get_examples(dpv[:properties], :key_value, true).join("\n")
                                else
                                  valv = "{}"
                                end
                              elsif dpv.type == "array"
                                if dpv.key?(:items)
                                  valv = get_examples({ dpk => dpv }, :only_value)
                                  valv = valv.join("\n")
                                else
                                  valv = "[]"
                                end
                              else
                                valv = ""
                              end
                            end
  
                            if dpv.keys.include?(:description)
                              description_parameters << "#    #{dpk}: (#{dpv[:type]}) #{dpv[:description].split("\n").join("\n#\t\t\t")}"
                            end
  
                            data_pattern += get_patterns(dpk, dpv)
                            data_pattern.uniq!
                            dpkeys = []
                            data_pattern.reject! do |dp|
                              dpkey = dp.scan(/^'[\w\.]+'/)
  
                              if dpkeys.include?(dpkey)
                                true
                              else
                                dpkeys << dpkey
                                false
                              end
                            end
  
                            if dpv.keys.include?(:readOnly) and dpv[:readOnly] == true
                              data_read_only << dpk
                            end
                            if dpv.keys.include?(:default)
                              if dpv[:default].nil?
                                data_default << "#{dpk}: nil"
                              elsif dpv.type != "string"
                                data_default << "#{dpk}: #{dpv[:default]}"
                              else
                                data_default << "#{dpk}: '#{dpv[:default]}'"
                              end
                            end
  
                            #todo: consider check default and insert it
                            #todo: remove array from here and add the option to get_examples for the case thisisthekey: ['xxxx']
                            if dpv.key?(:type) and dpv[:type] != "array"
                              params_data << get_examples({ dpk => dpv }, :only_value, true).join
                              params_data[-1].chop!.chop! if params_data[-1].to_s[-2..-1] == ", "
                              params_data.pop if params_data[-1].match?(/^\s*$/im)
                            else
                              if valv.to_s == ""
                                valv = '""'
                              elsif valv.include?('"')
                                valv.gsub!('"', "'") unless valv.include?("'")
                              end
                              params_data << "#{dpk}: #{valv}"
                            end
                          }
                          if params_data.size > 0
                            if data_examples_all_of == true and data_examples.size > 0
                              data_examples[0] += params_data
                            else
                              data_examples << params_data
                            end
                            params_data = []
                          end
                        end
                      end

                      unless data_required.empty?
                        data_required.uniq!
                        output << "# required data: #{data_required.inspect}" 
                      end
                    end
                  elsif p[:in] == "header"
                    #todo: see how we can treat those cases
                  else
                    puts "! not imported data with :in:#{p[:in]} => #{p.inspect}"
                  end  
                end

                params = params_path
  
                unless params_query.empty?
                  path_txt += "?"
                  params_required.each do |pr|
                    if create_constants
                      if params_query.include?(pr)
                        if create_method_name == :operationId
                          path_txt += "#{pr}=\#{#{pr}}&"
                          params << "#{pr}: #{pr.upcase}"
                          required_constants << pr.upcase
                        else
                          path_txt += "#{pr}=\#{#{pr.to_s.snake_case}}&"
                          params << "#{pr.to_s.snake_case}: #{pr.to_s.snake_case.upcase}"
                          required_constants << pr.to_s.snake_case.upcase
                        end
                      end
                    else
                      if params_query.include?(pr)
                        if create_method_name == :operationId
                          path_txt += "#{pr}=\#{#{pr}}&"
                          params << "#{pr}"
                        else
                          path_txt += "#{pr}=\#{#{pr.to_s.snake_case}}&"
                          params << "#{pr.to_s.snake_case}"
                        end
                      end
                    end
                  end
                  params_query.each do |pq|
                    unless params_required.include?(pq)
                      if create_method_name == :operationId
                        path_txt += "#{pq}=\#{#{pq}}&"
                        params << "#{pq}: ''"
                      else
                        path_txt += "#{pq}=\#{#{pq.to_s.snake_case}}&"
                        params << "#{pq.to_s.snake_case}: ''"
                      end
                    end
                  end
                end
              end
  
              if description_parameters.size > 0
                output << "# parameters description: "
                output << description_parameters.uniq
              end
  
              #for the case we still have some parameters on path that were not in 'parameters'
              if path_txt.scan(/[^#]{\w+}/).size > 0
                paramst = []
                prms = path_txt.scan(/[^#]{(\w+)}/)
                prms.each do |p|
                  #if create_constants
                  #  paramst<<"#{p[0].to_s.snake_case}: #{p[0].to_s.snake_case.upcase}"
                  #  required_constants << p[0].to_s.snake_case.upcase
                  #else
                  paramst << p[0].to_s.snake_case
                  #end
                  path_txt.gsub!("{#{p[0]}}", "\#{#{p[0].to_s.snake_case}}")
                end
                paramst.concat params
                params = paramst
              end
              params.uniq!
              output << "def self.#{method_name} (#{params.join(", ")})"
  
              output << "{"
  
              output << "name: \"#{module_requests}.#{method_name}\","
  
              output << "path: \"#{base_path}#{path_txt}\","
  
              output << "method: :#{met}," if met.to_s != ""
  
              unless data_required.empty?
                output << "data_required: ["
                output << ":'#{data_required.uniq.join("', :'")}'"
                output << "],"
              end
              unless data_read_only.empty?
                output << "data_read_only: ["
                output << ":'#{data_read_only.uniq.join("', :'")}'"
                output << "],"
              end
              unless data_default.empty?
                output << "data_default: {"
                data_default.uniq!
                output << data_default.join(", \n")
                output << "},"
              end
  
              unless data_pattern.empty?
                output << "data_pattern: {"
                output << data_pattern.uniq.join(", \n")
                output << "},"
              end
  
              unless data_form.empty?
                data_examples << data_form
              end

              unless data_examples.empty?
                unless data_required.empty?
                  reqdata = []
                  begin
                    data_examples[0].uniq!
                    data_ex = eval("{#{data_examples[0].join(", ")}}")
                  rescue SyntaxError  
                    data_ex = {}
                    @logger.warn "Syntax error: #{met} for path: #{path.path} evaluating data_examples[0] => #{data_examples[0].inspect}"
                  rescue
                    data_ex = {}
                    @logger.warn "Syntax error: #{met} for path: #{path.path} evaluating data_examples[0] => #{data_examples[0].inspect}"
                  end
                  if (data_required.grep(/\./)).empty?
                    reqdata = filter(data_ex, data_required) #not nested
                  else
                    reqdata = filter(data_ex, data_required, true) #nested
                  end
                  unless reqdata.empty?
                    reqdata.uniq!
                    phsd = pretty_hash_symbolized(reqdata)
                    phsd[0] = "data: {"
                    output += phsd
                  end
                end
                unless data_read_only.empty? or !data_required.empty?
                  reqdata = []
                  #remove read only fields from :data
                  data_examples[0].each do |edata|
                    read_only = false
                    data_read_only.each do |rdata|
                      if edata.scan(/^#{rdata}:/).size > 0
                        read_only = true
                        break
                      elsif edata.scan(/:/).size == 0
                        break
                      end
                    end
                    reqdata << edata unless read_only
                  end
                  unless reqdata.empty?
                    reqdata.uniq!
                    output << "data: {"
                    output << reqdata.join(", \n")
                    output << "},"
                  end
                end
  
                output << "data_examples: ["
                data_examples.each do |data|
                  output << "{"
                  data.uniq!
                  output << data.join(", \n")
                  output << "}, "
                end
                output << "],"
              end
  
              unless mock_example.empty?
                output << "mock_response: {"
                output << mock_example
                output << "},"
              end
  
              unless responses.empty?
                output << "responses: {"
                output << responses
                output << "},"
              end
  
              output << "}"
              output << "end"
            else
              @logger.warn "Not imported method: #{met} for path: #{path.path} since it is not supported by OpenApiImport"
            end
          end
        end
        output_footer = []
  
        output_footer << "end" unless (module_requests == "") && ([:path, :path_file, :tags, :tags_file].include?(name_for_module))
        output_footer << "end" << "end" << "end"
  
        if files.size == 0
          output = output_header + output + output_footer
          output_txt = output.join("\n")
          requests_file_path = file_to_convert + ".rb"
          File.open(requests_file_path, "w") { |file| file.write(output_txt) }
          res_rufo = `rufo #{requests_file_path}`
          message = "** Requests file: #{swagger_file}.rb that contains the code of the requests after importing the Swagger file"
          puts message unless silent
          @logger.info message
          @logger.error "       Error formating with rufo" unless res_rufo.to_s.match?(/\AFormat:.+$\s*\z/)
          @logger.error "       Syntax Error: #{`ruby -c #{requests_file_path}`}" unless `ruby -c #{requests_file_path}`.include?("Syntax OK")
        else
          unless files.key?(module_requests)
            files[module_requests] = Array.new
          end
          files[module_requests].concat(output) #for the last one
  
          requires_txt = ""
          message = "** Generated files that contain the code of the requests after importing the Swagger file: "
          puts message unless silent
          @logger.info message
          files.each do |mod, out_mod|
            output = output_header + out_mod + output_footer
            output_txt = output.join("\n")
            requests_file_path = file_to_convert + "_" + mod + ".rb"
            requires_txt += "require_relative '#{File.basename(swagger_file)}_#{mod}'\n"
            File.open(requests_file_path, "w") { |file| file.write(output_txt) }
            res_rufo = `rufo #{requests_file_path}`
            message = "  - #{requests_file_path}"
            puts message unless silent
            @logger.info message
            @logger.error "       Error formating with rufo" unless res_rufo.to_s.match?(/\AFormat:.+$\s*\z/)
            @logger.error "       Syntax Error: #{`ruby -c #{requests_file_path}`}" unless `ruby -c #{requests_file_path}`.include?("Syntax OK")
          end
  
          requests_file_path = file_to_convert + ".rb"
          if required_constants.size > 0
            rconsts = "# Required constants\n"
            required_constants.uniq!
            required_constants.each do |rq|
              rconsts += "#{rq} ||= ENV['#{rq}'] ||=''\n"
            end
            rconsts += "\n\n"
          else
            rconsts = ""
          end
  
          File.open(requests_file_path, "w") { |file| file.write(rconsts + requires_txt) }
          res_rufo = `rufo #{requests_file_path}`
          message = "** File that contains all the requires for all Request files: \n"
          message += "   - #{requests_file_path} "
          puts message unless silent
          @logger.info message
          @logger.error "       Error formating with rufo" unless res_rufo.to_s.match?(/\AFormat:.+$\s*\z/)
          @logger.error "       Syntax Error: #{`ruby -c #{requests_file_path}`}" unless `ruby -c #{requests_file_path}`.include?("Syntax OK")
        end
  
        begin
          res = eval(output_txt)
        rescue Exception => stack
          import_errors += "\n\nResult evaluating the ruby file generated: \n" + stack.to_s
        end
  
        if import_errors.to_s != ""
          File.open(file_errors, "w") { |file| file.write(import_errors) }
          message = "* It seems there was a problem importing the Swagger file #{file_to_convert}\n"
          message += "* Take a look at the detected errors at #{file_errors}\n"
          warn message
          @logger.fatal message
          return false
        else
          return true
        end
      rescue StandardError => stack
        puts stack.message
        @logger.fatal stack.message
        @logger.fatal stack.backtrace
        puts stack.backtrace
      end
    end
  end
  