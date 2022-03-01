require_relative "lib/rescue_like_a_pro/version"

Gem::Specification.new do |spec|
  spec.name        = "rescue_like_a_pro"
  spec.version     = RescueLikeAPro::VERSION
  spec.authors     = ["thomas morgan"]
  spec.email       = ["tm@iprog.com"]
  spec.homepage    = "https://github.com/zarqman/rescue_like_a_pro"
  spec.summary     = "Improve ActiveJob exception handling with inheritance, fallback handlers, more jitter options, etc."
  spec.description = "RescueLikeAPro rethinks ActiveJob's exception handling system to improve usage with class inheritance and mixins, add fallback retries exhausted and discard handlers, and improve jitter flexibility."
  spec.license     = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "https://github.com/zarqman/rescue_like_a_pro/blob/master/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "LICENSE.txt", "Rakefile", "README.md"]
  end

  spec.add_dependency "activejob", ">= 6.1"

  spec.add_development_dependency "rails", ">= 6.1.0"
  spec.add_development_dependency "minitest-reporters"
  spec.add_development_dependency "rake"
end
