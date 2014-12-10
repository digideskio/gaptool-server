namespace :server do
  desc "Set terminable flag to true/false for the instance :instance"
  task :set_terminable, [:instance, :value] do |t, args|
    DH.set_server_data_attr args[:instance], 'terminable', (args[:value] ? "true" : "false")
  end
end
