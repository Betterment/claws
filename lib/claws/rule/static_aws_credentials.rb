module Claws
  module Rule
    class StaticAwsCredentials < BaseRule
      description <<~DESC
        Avoid using long-lived AWS secret access keys in Github workflows. Static
        credentials can be tricky to audit and rotate, making them risky to hold
        onto, especially in the event of an incident where they may be leaked.

        Use GitHub's OIDC provider and authenticate with `role-to-assume` instead.

        For more information:
        https://github.com/betterment/claws/blob/main/README.md#staticawscredentials
      DESC

      on_workflow %(
        get_key($workflow.env, "AWS_SECRET_ACCESS_KEY") =~ "{{.*secrets\..*" ||
        get_key($workflow.env, "AWS_SECRET_ACCESS_KEY") =~ "{{.*env\..*" ||
        get_key($workflow.env, "AWS_SECRET_ACCESS_KEY") =~ "{{.*vars\..*" ||
        get_key($workflow.env, "AWS_SECRET_ACCESS_KEY") =~ "^[A-Za-z0-9/+=]+$"
      ), highlight: "env.AWS_SECRET_ACCESS_KEY"

      on_job %(
        get_key($job.env, "AWS_SECRET_ACCESS_KEY") =~ "{{.*secrets\..*" ||
        get_key($job.env, "AWS_SECRET_ACCESS_KEY") =~ "{{.*env\..*" ||
        get_key($job.env, "AWS_SECRET_ACCESS_KEY") =~ "{{.*vars\..*" ||
        get_key($job.env, "AWS_SECRET_ACCESS_KEY") =~ "^[A-Za-z0-9/+=]+$"
      ), highlight: "env.AWS_SECRET_ACCESS_KEY"

      on_step %(
        $step.meta.action.name == "aws-actions/configure-aws-credentials" &&
        (
          get_key($step.with, "aws-secret-access-key") =~ "{{.*secrets\..*" ||
          get_key($step.with, "aws-secret-access-key") =~ "{{.*env\..*" ||
          get_key($step.with, "aws-secret-access-key") =~ "{{.*vars\..*" ||
          get_key($step.with, "aws-secret-access-key") =~ "^[A-Za-z0-9/+=]+$"
        )
      ), highlight: "with.aws-secret-access-key"

      on_step %(
        get_key($step.env, "AWS_SECRET_ACCESS_KEY") =~ "{{.*secrets\..*" ||
        get_key($step.env, "AWS_SECRET_ACCESS_KEY") =~ "{{.*env\..*" ||
        get_key($step.env, "AWS_SECRET_ACCESS_KEY") =~ "{{.*vars\..*" ||
        get_key($step.env, "AWS_SECRET_ACCESS_KEY") =~ "^[A-Za-z0-9/+=]+$"
      ), highlight: "env.AWS_SECRET_ACCESS_KEY"

      on_step %(
        $step.run =~ "AWS_SECRET_ACCESS_KEY=['\\x22]?\\$\\{\\{\\s*(secrets\\.|vars\\.)" ||
        $step.run =~ "aws configure set aws_secret_access_key\\s+\\$\\{\\{\\s*(secrets\\.|vars\\.)" ||
        $step.run =~ "AWS_SECRET_ACCESS_KEY=['\\x22]?[A-Za-z0-9/+=]+" ||
        $step.run =~ "aws configure set aws_secret_access_key\\s+[A-Za-z0-9/+=]+"
      ), highlight: "run"
    end
  end
end
