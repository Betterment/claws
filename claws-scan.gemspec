# frozen_string_literal: true

require_relative "lib/claws/version"

Gem::Specification.new do |spec|
  spec.name = "claws-scan"
  spec.version = Claws::VERSION
  spec.authors = ["Omar"]
  spec.email = ["omar@betterment.com"]

  spec.summary = "Analyzes your Github Actions"
  spec.description = "Analyzes your Github Actions"
  spec.homepage = "https://github.com/Betterment/claws"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/Betterment/claws"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:test|spec|features|.github)/|\.(?:git|circleci)|appveyor)})
      # (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|circleci)|appveyor)})
    end
  end
  spec.bindir = "bin"
  spec.executables = spec.files.grep(%r{\Abin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "equation", "~> 0.6"
  spec.add_dependency "pry"
  spec.add_dependency "slop", "~> 4.9"
  spec.add_dependency "treetop"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
