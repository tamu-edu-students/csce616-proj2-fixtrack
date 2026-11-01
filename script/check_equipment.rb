require "simplecov"

SimpleCov.start "rails" do
  command_name "equipment-model-controller"
end

ARGV.replace([ "spec/models/equipment_spec.rb", "spec/controllers/equipment_controller_spec.rb" ])
load Gem.bin_path("rspec-core", "rspec")
