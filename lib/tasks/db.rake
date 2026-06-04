# lib/tasks/db.rake
Rake::Task["db:setup"].clear

namespace :db do
  task :setup => :environment do
    Rake::Task["db:create"].invoke

    ActiveRecord::Base.connection.disable_referential_integrity do
      load Rails.root.join("db/schema.rb")
    end

    Rake::Task["db:seed"].invoke
  end
end