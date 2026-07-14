module Claws
  module Rule
    class ConfigureAwsStaticCredentials < BaseRule
      description <<~DESC
        Avoid using long-lived AWS access keys with `aws-actions/configure-aws-credentials`.
        Static credentials can be tricky to audit and rotate, making them risky to hold
        onto, especially in the event of an incident where they may be leaked.

        Use GitHub's OIDC provider and authenticate with `role-to-assume` instead.

        For more information:
        https://github.com/betterment/claws/blob/main/README.md#configureawsstaticcredentials
      DESC

      on_step %(
        $step.meta.action.name == "aws-actions/configure-aws-credentials" &&
        (
          get_key($step.with, "aws-access-key-id") =~ "{{.*secrets\..*" ||
          get_key($step.with, "aws-access-key-id") =~ "{{.*env\..*" ||
          get_key($step.with, "aws-access-key-id") =~ "{{.*vars\..*" ||
          get_key($step.with, "aws-access-key-id") =~ "AKIA.*"
        )
      ), highlight: "with.aws-access-key-id"

      on_step %(
        $step.meta.action.name == "aws-actions/configure-aws-credentials" &&
        (
          get_key($step.with, "aws-secret-access-key") =~ "{{.*secrets\..*" ||
          get_key($step.with, "aws-secret-access-key") =~ "{{.*env\..*" ||
          get_key($step.with, "aws-secret-access-key") =~ "{{.*vars\..*"
        )
      ), highlight: "with.aws-secret-access-key"
    end
  end
end
