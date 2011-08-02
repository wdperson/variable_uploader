module GoodData
  module VariableUploader

    class CreateUsersStep < Step

      attr_accessor :source, :domain, :sfdc_connection

      def initialize(args={})
        pp args
        @source = args[:source]
        @domain = args[:domain]
        @sfdc_connection = args[:sfdc_connection]
      end

      def run(logger_param, project)
        puts "would run Update users"
        sfdc_users = get_data
        # pp sfdc_users

        users_lookup = {}
        GoodData.get("#{project.uri}/users")["users"].each do |user|
          user = user["user"]
          users_lookup[user["content"]["email"]] = user["links"]["self"]
        end

        pp users_lookup

        x = sfdc_users.reduce([]) do |memo, u|
          memo << u unless users_lookup.has_key?(u[:Email])
          memo
        end

        puts "------------------"
        pp x.length

        # new_users_uris = []
        # sfdc_connection.each do |user_data|
          # puts "Would upload person"
          # new_user = GoodData.post("/gdc/account/#{domain}/default/users",
          #     accountSetting => {
          #       login       => users_data[:login],
          #       password    => users_data[:password],
          #       firstName   => users_data[:first_name],
          #       lastName    => users_data[:last_name]
          #     })
          # new_users_uris << new_user[:uri]
        # end

        # GoodData.post("/gdc/projects/#{project}/users", new_users_uris.map do |uri|
        #   {
        #     :user => {
        #       :content => {
        #         :status => 'ENABLED'
        #       },
        #       :links => {
        #         :self => uri
        #       }
        #     }
        #   })
        # end
      end

      def grab_data_from_sf
        csv = []
        GoodData::VariableUploader::Helper.grab({
          :module => 'User',
          :output => csv,
          :fields => [:Email, :Id, :FirstName, :LastName],
          :sfdc_connection => sfdc_connection,
          :as_hash => true
        })
        csv
      end

      def grab_data_from_file(filename)
        data = File.read(filename)
        case File.extname(filename)
        when ".json"
          JSON.parse(data)
        when ".yaml"
          YAML.parse(data)
        when ".csv"
          output = []
          FasterCSV.parse(data, :headers => true) do |row|
            output << row.to_hash
          end
          output
        else
          fail "Unrecognized format"
        end
      end

      def get_data
        if source == :Salesforce
          grab_data_from_sf
        else
          grab_data_from_file(source)
        end
      end

    end
  end
end