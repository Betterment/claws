module Claws
  module Rule
    class CommandInjection < BaseRule
      description <<~DESC
        This step executes commands with user input which may allow an attacker to execute code in the context of this step, exposing source code or credentials. Consider moving user input into an environment variable instead of directly placing it into the shell command.

        For more information:
        https://github.com/betterment/claws/blob/main/README.md#commandinjection
      DESC

      # only ${{ }} is expanded by the runner; bare {{ }} (e.g. gh-aw prompt templates) is literal text.
      # (?:(?!\}\}).)* keeps the match inside a single expression while still allowing a lone } like format('{0}', ...)
      on_step '$step.run =~ "\$\{\{(?:(?!\}\}).)*(github\.event|inputs)\."', highlight: "run"
    end
  end
end
