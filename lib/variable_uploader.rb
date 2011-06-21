require 'fastercsv'
require 'gooddata'
require 'pp'
require 'logger'

module GoodData
  module VariableUploader

    class Variable
      attr_accessor :uri
    end

    class Step

      attr_reader :variable_uri, :filename, :display_form_uri, :logger

      def initialize(filename, variable_uri, label_uri)
        @filename = filename
        @variable_uri = variable_uri
        @display_form_uri = label_uri
      end

      def values
        return @values unless @values.nil?
        get_values
      end

      def get_values
        data = FasterCSV.read(filename)
        vals = {}
        data.each do |line|
          vals.has_key?(line.first) ? vals[line.first].concat(line[1..-1]) : vals[line.first] = line[1..-1]
        end
        @values = vals
      end

      def run(variable_logger, project)
        @logger = variable_logger
        # get variable
        variable = GoodData::MdObject[variable_uri]
        
        logger.debug("Updating variable #{variable.title}") if logger
        attribute = GoodData::MdObject[variable.content["attribute"]]
        
        # get display form
        default_label = get_default_display_form(attribute)

        elements_lookup = create_elements_lookup(default_label)
        users_lookup = create_users_lookup(project)

        # Create the values to be created
        expressions_by_user = create_expressions_for_update(users_lookup, elements_lookup)
        
        
        # Create the current values
        updated, new_el = gather_updates(project, variable, expressions_by_user)
        
        logger.debug("New values #{new_el.size}") if logger
        logger.debug("Updated values #{updated.size}") if logger

        data_to_send = []
        (updated + new_el).each do |user|
          data_to_send << {
            :expression => "[#{attribute.uri}] IN (#{user[:values].map {|v| "[#{v}]"}.join(", ")})",
            :level      => "user",
            :prompt     => variable.uri,
            :related    => user[:user],
            :type       => "filter"
          } unless user[:values].empty?
        end
        
        updated.each do |update|
          GoodData.delete(update[:uri])
        end
        
        GoodData.post("/gdc/md/#{project.obj_id}/variables/user", ({:variables => data_to_send}))
      end

      private
      
      def create_expressions_for_update(users_lookup, elements_lookup)
        expressions_by_user = {}
        get_values.each do |key, value|
          if users_lookup.has_key?(key)
            expressions_by_user[users_lookup[key]] = value.inject([]) do |all, val|
              if elements_lookup.has_key?(val)
                all << elements_lookup[val]
              else
                @logger.warn("Value #{val} for #{key} will not be used.")
                all
              end
            end
          else
            @logger.warn("Values for #{key} will not be used. User not found in project.")
          end
        end
        expressions_by_user
      end
      
      def create_users_lookup(project)
        users_lookup = {}
        GoodData.get("#{project.uri}/users")["users"].each do |user|
          user = user["user"]
          users_lookup[user["content"]["email"]] = user["links"]["self"]
        end
        users_lookup
      end

      def get_default_display_form(attribute)
        if display_form_uri.nil?
          labels = attribute.content["displayForms"].collect do |df|
            GoodData::MdObject[df["meta"]["uri"]]
          end
          labels.detect do |label|
            label.content["default"] == 1
          end
        else
          GoodData::MdObject[display_form_uri]
        end
      end

      def create_elements_lookup(default_label)
        elements = GoodData.get(default_label.links["elements"])
        # pp elements
        elements_lookup = {}

        elements["attributeElements"]["elements"].each do |element|
          elements_lookup[element["title"]] = element["uri"]
        end
        elements_lookup
      end

      def gather_updates(project, variable, expressions_by_user)
        search = GoodData::post("/gdc/md/#{project.obj_id}/variables/search", {"variablesSearch" => {
          "variables" => [variable.uri],
          "context" => []
        }})
        current_expressions_by_user = {}
        search["variables"].each do |var|
          current_expressions_by_user[var["related"]] = {
            :values => var['objects'].find_all {|obj| obj["category"] == "attributeElement"}.collect {|obj| obj["uri"]},
            :uri => var["uri"]
          }
        end
        
        # Compare and work only with new or changed, deleted
        updated = []
        new_el = []
        expressions_by_user.each do |profile_uri, values|
          a = current_expressions_by_user[profile_uri]
          b = values
          
          if a.nil?
            new_el << {:user => profile_uri, :values => values}
          else
            user = {:user => profile_uri, :values => values, :uri => a[:uri]}
            updated << user unless ((a[:values] | b) - (a[:values] & b)).empty?
          end
        end
        [updated, new_el]
      end
    end

    module DSL

      class Project

        attr_reader :steps

        def self.update(options = {}, &block)
          self.new(options, &block)
        end

        def initialize(options = {}, &block)
          @login = options[:login]
          @password = options[:pass]
          @pid = options[:pid]
          @steps = []
          instance_eval(&block)
          run
        end

        def run
          # GoodData.logger = Logger.new(STDOUT)
          GoodData.connect(@login, @password)
          p = GoodData.use(@pid)
          
          logger = Logger.new(STDOUT)
          
          steps.each do |step|
            step.run(logger, p)
          end
        end

        def upload(options={})
          raise "Specify file name or values" if (options[:values].nil? && options[:file].nil?)
          raise "Variable needs to be defined" if options[:variable].nil?

          # if options[:values]
            # raise "Values need to be of type Hash" unless options[:values].kind_of? Hash
            # @steps << Step.new(options[:values], Variable.new)
          # else
          @steps << Step.new(options[:file], options[:variable], options[:label])
          # end
        end
      end

    end
  end
end
