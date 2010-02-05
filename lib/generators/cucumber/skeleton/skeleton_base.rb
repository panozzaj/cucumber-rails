module Cucumber
  module SkeletonBase

    DEFAULT_SHEBANG = File.join(Config::CONFIG['bindir'], Config::CONFIG['ruby_install_name'])

    # Checks and prints the limitations
    def check_upgrade_limitations
      if File.exist?('features/step_definitions/webrat_steps.rb')
        STDERR.puts "Please remove features/step_definitions/webrat_steps.rb\n" + 
        "See upgrading instructions for 0.2.0 in History.txt"
        exit(1)
      end

      if File.exist?('features/support/version_check.rb')
        STDERR.puts "Please remove features/support/version_check.rb\n" + 
        "See upgrading instructions for 0.2.0 in History.txt"
        exit(1)
      end
    end

    # Creates templates
    def create_templates(m = self)
      m.template 'config/cucumber.yml.erb', 'config/cucumber.yml'
      m.template 'environments/cucumber.rb.erb', 'config/environments/cucumber.rb'
    end

    def create_scripts(m = self, rails2 = false)
      if rails2
        m.file 'script/cucumber', 'script/cucumber', {
          :chmod => 0755, :shebang => options[:shebang] == DEFAULT_SHEBANG ? nil : options[:shebang]
        }
      else
        m.copy_file 'script/cucumber', 'script/cucumber'
        m.chmod     'script/cucumber', 0755
      end
    end

    def create_step_definitions(m = self, rails2 = false)
      if rails2
        m.directory 'features/step_definitions'
      else
        m.empty_directory 'features/step_definitions'
      end

      m.template "step_definitions/#{driver}_steps.rb.erb", 'features/step_definitions/web_steps.rb'
      if language != 'en'
        m.template "step_definitions/web_steps_#{language}.rb.erb", "features/step_definitions/web_steps_#{language}.rb"
      end
    end

    def create_feature_support(m = self, rails2 = false)
      if rails2
        m.directory 'features/support'
        m.file      'support/paths.rb', 'features/support/paths.rb'
      else
        m.empty_directory 'features/support'
        m.copy_file 'support/paths.rb', 'features/support/paths.rb'
      end
      
      if spork?
        m.template 'support/rails_spork.rb.erb', 'features/support/env.rb'
      else
        m.template 'support/rails.rb.erb',       'features/support/env.rb'
      end
    end

    def create_tasks(m = self, rails2 = false)
      if rails2
        m.directory 'lib/tasks'
      else
        m.empty_directory 'lib/tasks'
      end
      
      m.template 'tasks/cucumber.rake.erb', 'lib/tasks/cucumber.rake'
    end

    def create_database(m = self)
      m.gsub_file 'config/database.yml', /test:.*\n/, "test: &TEST\n"
      unless File.read('config/database.yml').include? 'cucumber:'
        m.gsub_file 'config/database.yml', /\z/, "\ncucumber:\n  <<: *TEST"
      end
    end

    def print_instructions
      require 'cucumber/formatter/ansicolor'
      extend Cucumber::Formatter::ANSIColor

      if @default_driver
        puts <<-WARNING

  #{yellow_cukes(15)} 

                #{yellow_cukes(1)}   D R I V E R   A L E R T    #{yellow_cukes(1)}

  You didn't explicitly generate with --capybara or --webrat, so I looked at
  your gems and saw that you had #{green(@default_driver.to_s)} installed, so I went with that. 
  If you want something else, be specific about it. Otherwise, relax.

  #{yellow_cukes(15)} 

  WARNING
      end

      if @default_framework
        puts <<-WARNING

  #{yellow_cukes(15)} 

            #{yellow_cukes(1)}   T E S T   F R A M E W O R K   A L E R T    #{yellow_cukes(1)}

  You didn't explicitly generate with --rspec or --testunit, so I looked at
  your gems and saw that you had #{green(@default_framework.to_s)} installed, so I went with that. 
  If you want something else, be specific about it. Otherwise, relax.

  #{yellow_cukes(15)} 

  WARNING
      end
    end

    protected

    def detect_current_driver
      detect_in_env([['capybara', :capybara], ['webrat', :webrat ]])
    end

    def detect_default_driver
      @default_driver = first_loadable([['capybara', :capybara], ['webrat', :webrat ]])
      raise "I don't know which driver you want. Use --capybara or --webrat, or gem install capybara or webrat." unless @default_driver
      @default_driver
    end

    def detect_current_framework
      detect_in_env([['spec', :rspec], ['test/unit', :testunit]])
    end

    def detect_default_framework
      @default_framework = first_loadable([['spec', :rspec], ['test/unit', :testunit]])
      raise "I don't know what test framework you want. Use --rspec or --testunit, or gem install rspec or test-unit." unless @default_framework
      @default_framework
    end

    def spork?
      options[:spork]
    end

    def embed_file(source, indent='')
      IO.read(File.join(self.class.source_root, source)).gsub(/^/, indent)
    end

    def embed_template(source, indent='')
      template = File.join(self.class.source_root, source)
      ERB.new(IO.read(template), nil, '-').result(binding).gsub(/^/, indent)
    end

    def version
      IO.read(File.join(self.class.gem_root, 'VERSION')).chomp
    end

    def first_loadable(libraries)
      require 'rubygems'
      libraries.each do |library|
        begin
          require library[0]
          return library[1]
        rescue LoadError => ignore
        end
      end
      return nil
    end

    def detect_in_env(choices)
      env = File.file?("features/support/env.rb") ? IO.read("features/support/env.rb") : ''
      choices.each do |choice|
        detected = choice[1] if env =~ /#{choice[0]}/n
        return detected if detected
      end
      return nil
    end

  end
end