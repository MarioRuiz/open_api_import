# OpenApiImport

[![Gem Version](https://badge.fury.io/rb/open_api_import.svg)](https://rubygems.org/gems/open_api_import)
[![Build Status](https://travis-ci.com/MarioRuiz/open_api_import.svg?branch=master)](https://github.com/MarioRuiz/open_api_import)
[![Coverage Status](https://coveralls.io/repos/github/MarioRuiz/open_api_import/badge.svg?branch=master)](https://coveralls.io/github/MarioRuiz/open_api_import?branch=master)

Import a Swagger or Open API file and create a Ruby Request Hash file including all requests and responses with all the examples. The file can be in JSON or YAML.

The Request Hash will include also the pattern (regular expressions) of the fields,  parameters, default values...

On this first preliminary version we only fully support Open API v2. Open API v3 is not fully supported yet.

The output of this gem will be following the specification of Request Hashes: https://github.com/MarioRuiz/Request-Hash

The Request Hashes generated will be able to be used with any Ruby Http Client and it is adapted even better with nice_http gem: https://github.com/MarioRuiz/nice_http

To be able to generate random requests take a look at the documentation for nice_hash gem: https://github.com/MarioRuiz/nice_hash

This is an example of a generated request hash: 

```ruby

        # operationId: addPet, method: post
        # summary: Example
        # description: Creates a new pet in the store.  Duplicates are allowed
        # required data: name
        def self.add_pet()
          {
            path: "/api/pets",
            data_required: [
              :name,
            ],
            data_examples: [
              {
                name: "",
                tag: "",
              },
            ],
            responses: {
              '200': {message: "pet response"},
              'default': {message: "unexpected error"},
            },
          }
        end


```

## Installation

Install it yourself as:

    $ gem install open_api_import


Take in consideration open_api_import gem is using the 'rufo' gem that executes in command line the `rufo` command. In case you experience any trouble with it, visit: https://github.com/ruby-formatter/rufo

## Usage

You have all the json and yaml examples that the Open API project supplies on /spec/fixtures/ folder. You can use any of those ones or your own Swagger or Open API file. To convert the Swagger or Open API file into a Request Hash:

```ruby
  require 'open_api_import'
  
  OpenApiImport.from "./spec/fixtures/v2.0/yaml/uber.yaml"

  OpenApiImport.from "my_file.json"

```

The supported HTTP methods are: `GET`, `POST`, `PUT`, `DELETE` and `PATCH`

The requests will be organized by modules generated from the content in the Swagger file. 
For example this would be generated when run this: `OpenApiImport.from "./spec/fixtures/v2.0/yaml/petstore-simple.yaml"`

```ruby
##################################################
# Swagger Petstore
# version: 1.0.0
# description:
#     A sample API that uses a petstore as an example to demonstrate features in the swagger-2.0 specification
##################################################
module Swagger
  module SwaggerPetstore
    module V1_0_0
      module Pets
        # operationId: findPetById, method: get
        # summary:
        # description:
        #     Returns a user based on a single ID, if the user does not have access to the pet
        # parameters description:
        #    id: (integer) ID of pet to fetch
        def self.find_pet_by_id(id)
          {
            path: "/api/pets/#{id}",
            method: :get,
            responses: {
...
...

```

## Parameters

The parameters can be supplied alone or with other parameters. In case a parameter is not supplied then it will be used the default value.

### create_method_name

How the name of the methods will be generated.

Accepts three different options: :path, :operation_id and :operationId. By default :operation_id. 

  path: it will be used the path and http method, for example for a GET on path: /users/list, the method name will be get_users_list

  operation_id: it will be used the operationId field but using the snake_case version, for example for listUsers: list_users

  operationId: it will be used the operationId field like it is, for example: listUsers

```ruby
  require 'open_api_import'

  OpenApiImport.from "./spec/fixtures/v2.0/yaml/petstore-simple.yaml", create_method_name: :path

```

The output will generate methods like this:

```ruby
        # operationId: findPets, method: get
        # summary:
        # description:
        #     Returns all pets from the system that the user has access to
        # parameters description:
        #    tags: (array) tags to filter by
        #    limit: (integer) maximum number of results to return
        def self.get_pets(tags: "", limit: "")
          {
            path: "/api/pets?tags=#{tags}&limit=#{limit}&",
... 
...
```

if create_method_name is :operation_id

```ruby
  require 'open_api_import'

  OpenApiImport.from "./spec/fixtures/v2.0/yaml/petstore-simple.yaml", create_method_name: :operation_id

```

The output will generate methods like this:

```ruby
        # operationId: findPets, method: get
        # summary:
        # description:
        #     Returns all pets from the system that the user has access to
        # parameters description:
        #    tags: (array) tags to filter by
        #    limit: (integer) maximum number of results to return
        def self.find_pets(tags: "", limit: "")
          {
            path: "/api/pets?tags=#{tags}&limit=#{limit}&",
... 
...
```

if create_method_name is :operationId

```ruby
  require 'open_api_import'

  OpenApiImport.from "./spec/fixtures/v2.0/yaml/petstore-simple.yaml", create_method_name: :operationId

```

The output will generate methods like this:

```ruby
        # operationId: findPets, method: get
        # summary:
        # description:
        #     Returns all pets from the system that the user has access to
        # parameters description:
        #    tags: (array) tags to filter by
        #    limit: (integer) maximum number of results to return
        def self.findPets(tags: "", limit: "")
          {
            path: "/api/pets?tags=#{tags}&limit=#{limit}&",
... 
...
```

### name_for_module

How the module names will be created.

Accepts five different options: :path, :path_file, :tags, :tags_file and :fixed. By default :path. 

  path: It will be used the first folder of the path to create the module name, for example the path /users/list will be in the module Users and all the requests from all modules in the same file.
  
  path_file: It will be used the first folder of the path to create the module name, for example the path /users/list will be in the module Users and each module will be in a new requests file.

  tags: It will be used the tags key to create the module name, for example the tags: \[users, list] will create the module UsersList and all the requests from all modules in the same file. In case the tags are equal to the beginning of the operationId then it will be removed from the method name.
  
  tags_file: It will be used the tags key to create the module name, for example the tags: \[users, list] will create the module UsersList and and each module will be in a new requests file. In case the tags are equal to the beginning of the operationId then it will be removed from the method name.

  fixed: all the requests will be under the module Requests

```ruby
  require 'open_api_import'

  OpenApiImport.from "./spec/fixtures/v2.0/yaml/petstore-simple.yaml", name_for_module: :fixed

```

It will generate just one file including all requests under the Requests module

```ruby
module Swagger
  module SwaggerPetstore
    module V1_0_0
      module Requests

        # operationId: findPets, method: get
        # summary:
        # description:
        #     Returns all pets from the system that the user has access to
        # parameters description:
        #    tags: (array) tags to filter by
        #    limit: (integer) maximum number of results to return
        def self.find_pets(tags: "", limit: "")
...
...
```

In case using :path

```ruby
  require 'open_api_import'

  OpenApiImport.from "./spec/fixtures/v2.0/yaml/petstore-simple.yaml", name_for_module: :path

```

It will generate just one file including every request under the module generated from the first folder of the path

```ruby
module Swagger
  module SwaggerPetstore
    module V1_0_0
      module Pets

        # operationId: findPetById, method: get
        # summary:
        # description:
        #     Returns a user based on a single ID, if the user does not have access to the pet
        # parameters description:
        #    id: (integer) ID of pet to fetch
        def self.find_pet_by_id(id)
...
...
```

In case using :path_file

```ruby
  require 'open_api_import'

  OpenApiImport.from "./spec/fixtures/v2.0/yaml/petstore-simple.yaml", name_for_module: :path_file

```

It will generate one file per module including every request under the module generated from the first folder of the path. Also it will be generated one file that will have all the `require_relative` for the generated request files.

This is the output of the run:

```
** Generated files that contain the code of the requests after importing the Swagger file:
  - /petstore-simple.yaml_Root.rb
  - /petstore-simple.yaml_Pets.rb
** File that contains all the requires for all Request files:
  - /petstore-simple.yaml.rb
```

In case using :tags

```ruby
  require 'open_api_import'

  OpenApiImport.from "./spec/fixtures/v2.0/yaml/uber.yaml", name_for_module: :tags, create_method_name: :path

```

It will generate just one file including every request under the module generated from the first folder of the path

```ruby
module Swagger
  module UberApi
    module V1_0_0
      module Products

        # operationId: unknown, method: get
        # summary: Product Types
        # description:
        #     The Products endpoint returns information about the Uber products offered at a given location. 
        #     The response includes the display name and other details about each product, and lists the products in the proper display order.
        # parameters description:
        #    latitude: (number) (required) Latitude component of location.
        #    longitude: (number) (required) Longitude component of location.
        def self.get_products(latitude, longitude)
...
...
```


### include_responses

If you want to add the examples of responses in the resultant file.

Accepts true or false, by default is true.

```ruby
  require 'open_api_import'

  OpenApiImport.from "./spec/fixtures/v2.0/yaml/petstore-simple.yaml", include_responses: false

```

A method that will be included in the output:

```ruby
        # operationId: findPetById, method: get
        # summary:
        # description:
        #     Returns a user based on a single ID, if the user does not have access to the pet
        # parameters description:
        #    id: (integer) ID of pet to fetch
        def self.find_pet_by_id(id)
          {
            path: "/api/pets/#{id}",
            method: :get,
          }
        end
```

In case we run this

```ruby
  require 'open_api_import'

  OpenApiImport.from "./spec/fixtures/v2.0/yaml/petstore-simple.yaml", include_responses: true

```

A method that will be included in the output:

```ruby
        # operationId: findPetById, method: get
        # summary:
        # description:
        #     Returns a user based on a single ID, if the user does not have access to the pet
        # parameters description:
        #    id: (integer) ID of pet to fetch
        def self.find_pet_by_id(id)
          {
            path: "/api/pets/#{id}",
            method: :get,
            responses: {
              '200': {
                message: "pet response",
                data: {
                  name: "string",
                  tag: "string",
                  id: 0,
                },
              },
              'default': {
                message: "unexpected error",
                data: {
                  code: 0,
                  message: "string",
                },
              },
            },
          }
        end
```

### mock_response

Add the first response on the request as mock_response to be used.

Admits true or false. By default false.

In case using nice_http gem: if NiceHttp.use_mocks = true will use it instead of getting the real response from the WS.

```ruby
  require 'open_api_import'

  OpenApiImport.from "./spec/fixtures/v2.0/yaml/petstore.yaml", mock_response: true

```

It will include this on the output file: 

```ruby
        # operationId: listPets, method: get
        # summary: List all pets
        # description:
        # parameters description:
        #    limit: (integer) How many items to return at one time (max 100)
        def self.list_pets(limit: "")
          {
            path: "/v1/pets?limit=#{limit}&",
            method: :get,
            mock_response: {
              code: "200",
              message: "A paged array of pets",
              data: [
                {
                  id: 0,
                  name: "string",
                  tag: "string",
                },
              ],
            },
...
...
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/marioruiz/open_api_import.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).