require 'lib/variable_uploader'

include GoodData::VariableUploader
include GoodData::VariableUploader::DSL

describe "DSL" do

  before :each do
    @plan = Plan.new do
      upload :file => 'spec/values.txt', :variable => '/gdc/1'
      upload :file => 'spec/another_values.txt', :variable => '/gdc/2'
    end
  end

  it "should generate plan" do
    @plan.steps.size.should equal 2
    @plan.steps.first.values.size.should equal 2
  end

  it "each step should have a path for values file" do
    step1 = @plan.steps.first
    step1.filename.should == "spec/values.txt"

    step2 = @plan.steps[1]
    step2.filename.should == "spec/another_values.txt"
  end

  it "should have defined the variable" do
    step1 = @plan.steps.first
    step1.variable_uri.should == "/gdc/1"

    step2 = @plan.steps[1]
    step2.variable_uri.should == "/gdc/2"
  end

end