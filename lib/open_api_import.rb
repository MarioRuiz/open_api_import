require_relative "open_api_import/utils"

require "oas_parser"
require "rufo"
require "nice_hash"
require "logger"

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
  #   path: It will be used the first folder of the path to create the module name, for example the path /users/list will be in the module Users and all the requests from all modules in the same file.
  #   path_file: It will be used the first folder of the path to create the module name, for example the path /users/list will be in the module Users and each module will be in a new requests file.
  #   tags: It will be used the tags key to create the module name, for example the tags: [users,list] will create the module UsersList and all the requests from all modules in the same file.
  #   tags_file: It will be used the tags key to create the module name, for example the tags: [users,list] will create the module UsersList and and each module will be in a new requests file.
  #   fixed: all the requests will be under the module Requests
  ##############################################################################################
  def self.from(swagger_file, create_method_name: :operation_id, include_responses: true, mock_response: false, name_for_module: :path)
    begin
      f = File.new("#{swagger_file}_open_api_import.log", "w")
      f.sync = true
      @logger = Logger.new f
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

      begin
        definition = OasParser::Definition.resolve(swagger_file)
      rescue Exception => stack
        message = "There was a problem parsing the Open Api document using the oas_parser gem. The execution was aborted.\n"
        message += "Visit the github for oas_parser gem for bugs and more info: https://github.com/Nexmo/oas_parser\n"
        message += "Error: #{stack.message}"
        puts message
        @logger.fatal message
        @logger.fatal stack.backtrace
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
                #todo: check if in some cases the parameters on the method can be added to the ones in the path
                #raw[met][:parameters] = raw[met][:parameters] & raw[:parameters]
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
            description_parameters = []
            data_required = []
            data_read_only = []
            data_default = []
            data_examples = []
            data_pattern = []
            responses = []

            # for the case operationId is missing
            cont[:operationId] = "unknown" unless cont.key?(:operationId)

            if create_method_name == :path
              method_name = (met.to_s + "_" + path.path.to_s).snake_case
              method_name.chop! if method_name[-1] == "_"
            elsif create_method_name == :operation_id
              if (name_for_module == :tags or name_for_module == :tags_file) and cont.key?(:tags) and cont[:tags].is_a?(Array) and cont[:tags].size>0
                metnametmp = cont[:operationId].gsub(/^#{cont[:tags].join}[\s_]*/, '')
              else
                metnametmp = cont[:operationId]
              end
              method_name = metnametmp.to_s.snake_case
            else
              if (name_for_module == :tags or name_for_module == :tags_file) and cont.key?(:tags) and cont[:tags].is_a?(Array) and cont[:tags].size>0
                method_name = cont[:operationId].gsub(/^#{cont[:tags].join}[\s_]*/, '')
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
                if cont.key?(:tags) and cont[:tags].is_a?(Array) and cont[:tags].size>0
                  module_requests = cont[:tags].join(" ").camel_case
                else
                  module_requests = "Unknown"
                end
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
            output << "# summary: #{cont[:summary]}"
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
                v[:description] = v[:description].to_s.gsub("'", %q(\\\'))
                
                
                if !response_example.empty?
                  responses << "'#{k}': { "
                  responses << "message: '#{v[:description]}', "
                  responses << "data: "
                  responses << response_example
                  responses << "},"
                  
                  if mock_response and mock_example.size==0
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
              cont[:parameters] << {in: 'body', schema: cont[:requestBody][:content][:'application/json'][:schema] }
            end

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
                  params_path << param_name
                  #params_required << param_name if p[:required].to_s=="true"
                  description_parameters << "#    #{p[:name]}: (#{type}) #{"(required)" if p[:required].to_s=="true"} #{p[:description]}"
                elsif p[:in] == "query"
                  params_query << p[:name]
                  params_required << p[:name] if p[:required].to_s=="true"
                  description_parameters << "#    #{p[:name]}: (#{type}) #{"(required)" if p[:required].to_s=="true"} #{p[:description]}"
                elsif p[:in] == "body"
                  if p.keys.include?(:schema)
                    if p[:schema].key?(:oneOf)
                      bodies = p[:schema][:oneOf]
                    elsif p[:schema].key?(:anyOf)
                      bodies = p[:schema][:anyOf]
                    elsif p[:schema].key?(:allOf)
                      bodies = p[:schema][:allOf]
                    else
                      bodies = [p[:schema]]
                    end

                    params_data = []

                    bodies.each do |body|
                      if body.keys.include?(:required) and body[:required].size > 0
                        output << "# required data: #{body[:required].join(", ")}"
                        data_required += body[:required]
                      end

                      if body.keys.include?(:properties) and body[:properties].size > 0
                        body[:properties].each { |dpk, dpv|
                          if dpv.keys.include?(:example)
                            valv = dpv[:example]
                          else
                            if dpv.type == "object"
                              valv = "{}"
                            else  
                              valv = ""
                            end
                          end
                          if dpv.keys.include?(:description)
                            description_parameters << "#    #{dpk}: (#{dpv[:type]}) #{dpv[:description]}"
                          end
                          if dpv.keys.include?(:pattern)
                            data_pattern << "#{dpk}: /#{dpv[:pattern].to_s.gsub("\\/", "\/")}/"
                          end
                          if dpv.keys.include?(:readOnly) and dpv[:readOnly] == true
                            data_read_only << dpk
                          end
                          if dpv.keys.include?(:default)
                            if dpv.type != "string"
                              data_default << "#{dpk}: #{dpv[:default]}"
                            else
                              data_default << "#{dpk}: '#{dpv[:default]}'"
                            end
                          end

                          if dpv[:type].downcase == "string"
                            valv = '"' + valv + '"'
                          else
                            #todo: consider check default and insert it
                            if valv.to_s == ""
                              valv = '"' + valv + '"'
                            end
                          end
                          params_data << "#{dpk}: #{valv}"
                        }
                        if params_data.size > 0
                          data_examples << params_data
                          params_data = []
                        end
                      end
                    end
                  end
                end
              end

              params = params_path

              unless params_query.empty?
                path_txt += "?"
                params_required.each do |pr|
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
              output << description_parameters
            end

            #for the case we still have some parameters on path that were not in 'parameters'
            if path_txt.scan(/[^#]{\w+}/).size > 0
              paramst = []
              prms = path_txt.scan(/[^#]{(\w+)}/)
              prms.each do |p|
                paramst<<p[0].to_s.snake_case
                path_txt.gsub!("{#{p[0]}}", "\#{#{p[0].to_s.snake_case}}")
              end
              paramst.concat params
              params = paramst
            end
            
            output << "def self.#{method_name} (#{params.join(", ")})"

            output << "{"

            output << "path: \"#{base_path}#{path_txt}\","

            output << "method: :#{met}," if met.to_s != ""

            unless data_required.empty?
              output << "data_required: ["
              output << ":#{data_required.uniq.join(", :")}"
              output << "],"
            end
            unless data_read_only.empty?
              output << "data_read_only: ["
              output << ":#{data_read_only.uniq.join(", :")}"
              output << "],"
            end
            unless data_default.empty?
              output << "data_default: {"
              output << data_default.join(", \n")
              output << "},"
            end

            unless data_pattern.empty?
              output << "data_pattern: {"
              output << data_pattern.uniq.join(", \n")
              output << "},"
            end

            unless data_examples.empty?
              unless data_required.empty?
                reqdata = []
                data_examples[0].each do |edata|
                  data_required.each do |rdata|
                    if edata.scan(/^#{rdata}:/).size>0 or edata.scan(/:/).size==0
                      reqdata << edata
                    end
                  end
                end
                unless reqdata.empty?
                  output << "data: {"
                  output << reqdata.join(", \n")
                  output << "},"
                end
              end

              output << "data_examples: ["
              data_examples.each do |data|
                output << "{"
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
        `rufo #{requests_file_path}`
        message = "** Requests file: #{swagger_file}.rb that contains the code of the requests after importing the Swagger file"
        puts message
        @logger.info message
      else
        unless files.key?(module_requests)
          files[module_requests] = Array.new
        end
        files[module_requests].concat(output) #for the last one

        requires_txt = ""
        message = "** Generated files that contain the code of the requests after importing the Swagger file: "
        puts message
        @logger.info message
        files.each do |mod, out_mod|
          output = output_header + out_mod + output_footer
          output_txt = output.join("\n")
          requests_file_path = file_to_convert + "_" + mod + ".rb"
          requires_txt += "require_relative '#{File.basename(swagger_file)}_#{mod}'\n"
          File.open(requests_file_path, "w") { |file| file.write(output_txt) }
          `rufo #{requests_file_path}`
          message = "  - #{requests_file_path}"
          puts message
          @logger.info message
        end

        requests_file_path = file_to_convert + ".rb"
        File.open(requests_file_path, "w") { |file| file.write(requires_txt) }
        `rufo #{requests_file_path}`
        message = "** File that contains all the requires for all Request files: \n"
        message += "   - #{requests_file_path} "
        puts message
        @logger.info message
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

  class << self
    # Retrieve the examples from the properties hash
    private def get_examples(properties)
      #todo: consider using this method also to get data examples
      example = []
      example << "{" unless properties.empty?
      properties.each do |prop, val|
        if val.key?(:properties) and !val.key?(:example) and !val.key?(:type)
          val[:type]='object'
        end
        if val.key?(:example)
          example << if val[:example].is_a?(String)
            " #{prop.to_sym}: \"#{val[:example]}\", "
          else
            " #{prop.to_sym}: #{val[:example]}, "
          end
        elsif val.key?(:type)
          format = val[:format]
          format = val[:type] if format.to_s == ""
          case val[:type].downcase
          when "string"
            example << " #{prop.to_sym}: \"#{format}\", "
          when "integer", "number"
            example << " #{prop.to_sym}: 0, "
          when "boolean"
            example << " #{prop.to_sym}: true, "
          when "array"
            if val.key?(:items) and val[:items].key?(:enum)
              if val[:items][:enum][0].is_a?(String)
                example << " #{prop.to_sym}: \"" + val[:items][:enum].sample + "\", "
              else
                example << " #{prop.to_sym}: " + val[:items][:enum].sample + ", "
              end
            else
              #todo: differ between response examples and data examples
              example << " #{prop.to_sym}: " + get_response_examples({schema: val}).join("\n") + ", "
            end
          when "object"
            #todo: differ between response examples and data examples
            res_ex = get_response_examples({schema: val})
            if res_ex.size == 0
              res_ex = "{ }"
            else
              res_ex = res_ex.join("\n")
            end
            example << " #{prop.to_sym}: " + res_ex + ", "
          else
            example << " #{prop.to_sym}: \"#{format}\", "
          end
        end
      end
      example << "}" unless properties.empty?
      example
    end

    # Retrieve the response examples from the hash
    private def get_response_examples(v)
      # TODO: take in consideration the case allOf, oneOf... schema.items.allOf[0].properties schema.items.allOf[1].properties
      # example on https://github.com/OAI/OpenAPI-Specification/blob/master/examples/v2.0/yaml/petstore-expanded.yaml
      v=v.dup
      response_example = Array.new()
      # for open api 3.0 with responses schema inside content
      if v.key?(:content) && v[:content].is_a?(Hash) && v[:content].key?(:'application/json') &&
        v[:content][:'application/json'].key?(:schema)
        v=v[:content][:'application/json'].dup
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
             (v[:schema].key?(:items) && v[:schema][:items].key?(:properties)) ||
             (v[:schema].key?(:items) && v[:schema][:items].key?(:allOf)) ||
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

        response_example += get_examples(properties) unless properties.empty?

        unless response_example.empty?
          if v[:schema].key?(:properties) || v[:schema].key?(:allOf)
            #
          else # array, items
            response_example << "]"
          end
        end
      elsif v.key?(:schema) and v[:schema].key?(:items) and v[:schema][:items].key?(:type)
        # for the case only type supplied but nothing else for the array
        response_example << "[\"#{v[:schema][:items][:type]}\"]"
      end
      return response_example
    end
  end
end
