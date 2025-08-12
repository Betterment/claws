module Claws
  module Rule
    class CommandInjection < BaseRule
      description <<~DESC
        This step executes commands with user input which may allow an attacker to execute code in the context of this step, exposing source code or credentials. Consider moving user input into an environment variable instead of directly placing it into the shell command.

        For more information:
        https://github.com/betterment/claws/blob/main/README.md#commandinjection
      DESC

      on_step '$step.run =~ ".*{{.*(github\.event|inputs)\..*}}.*"', highlight: "run"
    end
  end
end
