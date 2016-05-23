require 'standalone_migrations'
require 'foreigner'

StandaloneMigrations.on_loaded do
  Foreigner.load
end
StandaloneMigrations::Tasks.load_tasks