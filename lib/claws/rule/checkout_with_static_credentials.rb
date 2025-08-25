module Claws
  module Rule
    class CheckoutWithStaticCredentials < BaseRule
      description <<~DESC
        Avoid using static credentials like deploy keys, SSH keys, or personal access
        tokens to clone other repositories. Static credentials can be tricky to audit
        and rotate, making them risky to hold onto, especially in the event of an
        incident where they may be leaked.

        Either grant your repository access directly to other repositories, or use a
        Github App to generate a short lived access token.

        For more information:
        https://github.com/betterment/claws/blob/main/README.md#checkoutwithstaticcredentials
      DESC

      on_step %(
        $step.meta.action.name == "actions/checkout" &&
        (
          get_key($step.with, "ssh-key") =~ ".*secrets..*" ||
          get_key($step.with, "ssh-key") =~ ".*env..*" ||
          get_key($step.with, "ssh-key") =~ ".*vars..*" ||
          get_key($step.with, "ssh-key") =~ ".*-----BEGIN.*"
        )
      ), highlight: "with.ssh-key"

      on_step %(
        $step.meta.action.name == "actions/checkout" &&
        (
          get_key($step.with, "token") =~ ".*secrets.*" ||
          get_key($step.with, "token") =~ ".*env..*" ||
          get_key($step.with, "token") =~ ".*vars..*" ||
          get_key($step.with, "token") =~ "gh[a-z]_.*"
        )
      ), highlight: "with.token"
    end
  end
end
