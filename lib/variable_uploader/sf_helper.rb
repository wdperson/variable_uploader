module GoodData
  module VariableUploader
    module Helper

      def Helper.grab(options)
        sf_module = options[:module] || fail("Specify SFDC module")
        fields = options[:fields]
        binding = options[:sfdc_connection]
        output = options[:output]
        as_hash = options[:as_hash]

        fields = fields.split(', ') if fields.kind_of? String
        values = fields.map {|v| v.to_sym}

        query = "SELECT #{values.join(', ')} from #{sf_module}"
        answer = binding.query({:queryString => query})

        output << values unless as_hash
        answer[:queryResponse][:result][:records].each do |row|
          if as_hash
            output << row
          else
            output << row.values_at(*values)
          end
        end

        more_locator = answer[:queryResponse][:result][:queryLocator]

        while more_locator do
          answer_more = binding.queryMore({:queryLocator => more_locator})
          answer_more[:queryMoreResponse][:result][:records].each do |row|
            if as_hash
              output << row
            else
              output << row.values_at(*values)
            end
          end
          more_locator = answer_more[:queryMoreResponse][:result][:queryLocator]
        end
      end

    end
  end
end
