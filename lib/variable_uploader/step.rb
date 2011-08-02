module GoodData
  module VariableUploader

    class Step

      def run(logger_param, project)
        fail "Override in the ancestor"
      end

    end
  end
end