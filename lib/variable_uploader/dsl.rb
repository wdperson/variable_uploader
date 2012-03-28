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
          @server = options[:server]
          instance_eval(&block)
          run
        end

        def run
          # GoodData.logger = Logger.new(STDOUT)
          GoodData.connect(@login, @password, @server, {
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

          @steps << VariableStep.new(options[:file], options[:variable], options[:label], options)
        end

        alias :upload :update_variable

      end

    end
  end
end
