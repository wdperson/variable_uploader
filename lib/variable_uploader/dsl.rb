module GoodData
  module VariableUploader
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
          GoodData.connect(@login, @password, nil, {
            :timeout => 0
          })
          p = GoodData.use(@pid)

          logger = Logger.new('variable_uploader.log', 10, 1024000)

          steps.each do |step|
            step.run(logger, p)
          end
        end

        def update_variable(options={})
          raise "Specify file name or values" if (options[:values].nil? && options[:file].nil?)
          raise "Variable needs to be defined" if options[:variable].nil?

          @steps << VariableStep.new(options[:file], options[:variable], options[:label])
        end

        def update_users(options={})
          # raise "Specify file name" if options[:file].nil?
          binding = RForce::Binding.new 'https://www.salesforce.com/services/Soap/u/20.0'
          # binding.login 'ps+greenlightsearch@gooddata.com', 'GoodData2011' + 'vs6WF0Mt9DIRm4TQn5In7QLD'
          binding.login 'ps+scribe@gooddata.com', 'wqOsWVJc2AdYr0FeVqrX1Ru8YqTgHekXOSV'
          
          @steps << CreateUsersStep.new(options.merge({
              :sfdc_connection => binding
          }))
        end

      end

    end
  end
end