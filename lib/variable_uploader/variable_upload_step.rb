module GoodData
  module VariableUploader

    class VariableStep < Step

      ALL = '(all)'
      NOT = 'not'
      NOT_IN = 'not in'
      IN = 'in'

      attr_reader :variable_uri, :filename, :display_form_uri, :logger

      def initialize(filename, variable_uri, label_uri)
        @filename = filename
        @variable_uri = variable_uri
        @display_form_uri = label_uri
      end

      def run(logger_param, project)
        @logger = logger_param
        # get variable
        variable = GoodData::MdObject[variable_uri]
    
        logger.debug("Updating variable #{variable.title}")
        attribute = GoodData::MdObject[variable.content["attribute"]]
    
        # get display form
        default_label = get_default_display_form(attribute)

        elements_lookup = create_elements_lookup(default_label)
        users_lookup = create_users_lookup(project)

        # Create the values to be created
        expressions_by_user = create_expressions_for_update(users_lookup, elements_lookup)
    
    
        # Create the current values
        updated, new_el = gather_updates(project, variable, expressions_by_user)
    
        logger.debug("New values #{new_el.size}")
        logger.debug("Updated values #{updated.size}")

        data_to_send = []
        (updated + new_el).each do |user|
          maql_expression = user[:values] == [ALL] ? "TRUE" : "[#{attribute.uri}] #{user[:type]} (#{user[:values].map {|v| "[#{v}]"}.join(", ")})"
          pp maql_expression
          data_to_send << {
            :expression => maql_expression,
            :level      => "user",
            :prompt     => variable.uri,
            :related    => user[:user],
            :type       => "filter"
          } unless user[:values].empty?
        end
    
        # pp data_to_send
    
        updated.each do |update|
          GoodData.delete(update[:uri])
        end
    
        GoodData.post("/gdc/md/#{project.obj_id}/variables/user", ({:variables => data_to_send}))
      end

      private

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
        logger.debug("Found #{vals.size} user defined rules in file #{filename}")
        @values = vals
      end

      def create_expressions_for_update(users_lookup, elements_lookup)
        expressions_by_user = {}
        get_values.each do |key, value|
          if users_lookup.has_key?(key)
            expressions_by_user[users_lookup[key]] = {}
            # puts "-------> #{value.first}"
            expressions_by_user[users_lookup[key]][:type] = value.first === NOT ? NOT_IN : IN
            expressions_by_user[users_lookup[key]][:values] = value.inject([]) do |all, val|
              if val == ALL
                all << val
              elsif val == NOT
                # do nothing, not is not a value
                all
              elsif elements_lookup.has_key?(val)
                all << elements_lookup[val]
              else
                @logger.warn("Value #{val} for #{key} will not be used. The value could not be found through the label")
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
            :expression => var["expression"],
            :uri => var["uri"],
            :type => var["tree"]["type"]
          }
        end

        # Compare and work only with new or changed, deleted
        updated = []
        new_el = []
        expressions_by_user.each do |profile_uri, values|
          a = current_expressions_by_user[profile_uri]
          a_type = a[:type]
          b_type = values[:type]
          b = values[:values]

          # puts "---- #{a_type}"
          # pp a
          # puts "---- #{b_type}"
          # pp b
          # puts "----"

          if a.nil?
            new_el << {:user => profile_uri, :values => b} unless b.empty?
          else
            user = {:user => profile_uri, :values => b, :uri => a[:uri], :type => b_type }
            are_same = false
            are_same = true if are_same == false && (a[:expression] == "TRUE" && b == [ALL])
            are_same = true if ((a[:values] | b) - (a[:values] & b)).empty? && a_type === b_type && a[:expression] != "TRUE"

            # puts "#{a[:values]} -- #{b}, #{are_same}"
            # puts "#{a[:expression]} -- #{b}, #{are_same}"
            updated << user unless are_same
          end
        end
        return updated, new_el
      end
    end
  end
end