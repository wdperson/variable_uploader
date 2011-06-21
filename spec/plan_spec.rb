require 'lib/variable_uploader'

include GoodData::VariableUploader
include GoodData::VariableUploader::DSL

describe "Step" do

  before :each do
    @step = Step.new("spec/values.txt", "/gdc/1")

    # @variable = double('Manager variable')
    # @variable.stub(:uri).and_return('/gdc/variable/123')
    # 
    # @step = Step.new({
    #   "john@example.com" => [1,2,4]
    # }, @variable)
  end

  it "should be able to return the values as is" do
    @step.values
    values.class.should be Hash
    values.has_key?("john@example.com").should be
    values["john@example.com"].should == [1,2,4]
  end

end