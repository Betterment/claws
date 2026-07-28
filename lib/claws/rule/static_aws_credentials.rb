module Claws
  module Rule
    class StaticAwsCredentials < BaseRule
      description <<~DESC
        Avoid using long-lived AWS access keys in Github workflows. Static credentials
        can be tricky to audit and rotate, making them risky to hold onto, especially
        in the event of an incident where they may be leaked.

        Use GitHub's OIDC provider and authenticate with `role-to-assume` instead.

        For more information:
        https://github.com/betterment/claws/blob/main/README.md#staticawscredentials
      DESC

      on_workflow %(
        get_key($workflow.env, "AWS_ACCESS_KEY_ID") =~ "{{.*secrets\..*" ||
        get_key($workflow.env, "AWS_ACCESS_KEY_ID") =~ "{{.*env\..*" ||
        get_key($workflow.env, "AWS_ACCESS_KEY_ID") =~ "{{.*vars\..*" ||
        get_key($workflow.env, "AWS_ACCESS_KEY_ID") =~ "AKIA.*"
      ), highlight: "env.AWS_ACCESS_KEY_ID"

      on_workflow %(
        get_key($workflow.env, "AWS_SECRET_ACCESS_KEY") =~ "{{.*secrets\..*" ||
        get_key($workflow.env, "AWS_SECRET_ACCESS_KEY") =~ "{{.*env\..*" ||
        get_key($workflow.env, "AWS_SECRET_ACCESS_KEY") =~ "{{.*vars\..*"
      ), highlight: "env.AWS_SECRET_ACCESS_KEY"

      on_job %(
        get_key($job.env, "AWS_ACCESS_KEY_ID") =~ "{{.*secrets\..*" ||
        get_key($job.env, "AWS_ACCESS_KEY_ID") =~ "{{.*env\..*" ||
        get_key($job.env, "AWS_ACCESS_KEY_ID") =~ "{{.*vars\..*" ||
        get_key($job.env, "AWS_ACCESS_KEY_ID") =~ "AKIA.*"
      ), highlight: "env.AWS_ACCESS_KEY_ID"

      on_job %(
        get_key($job.env, "AWS_SECRET_ACCESS_KEY") =~ "{{.*secrets\..*" ||
        get_key($job.env, "AWS_SECRET_ACCESS_KEY") =~ "{{.*env\..*" ||
        get_key($job.env, "AWS_SECRET_ACCESS_KEY") =~ "{{.*vars\..*"
      ), highlight: "env.AWS_SECRET_ACCESS_KEY"

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

      on_step %(
        get_key($step.env, "AWS_ACCESS_KEY_ID") =~ "{{.*secrets\..*" ||
        get_key($step.env, "AWS_ACCESS_KEY_ID") =~ "{{.*env\..*" ||
        get_key($step.env, "AWS_ACCESS_KEY_ID") =~ "{{.*vars\..*" ||
        get_key($step.env, "AWS_ACCESS_KEY_ID") =~ "AKIA.*"
      ), highlight: "env.AWS_ACCESS_KEY_ID"

      on_step %(
        get_key($step.env, "AWS_SECRET_ACCESS_KEY") =~ "{{.*secrets\..*" ||
        get_key($step.env, "AWS_SECRET_ACCESS_KEY") =~ "{{.*env\..*" ||
        get_key($step.env, "AWS_SECRET_ACCESS_KEY") =~ "{{.*vars\..*"
      ), highlight: "env.AWS_SECRET_ACCESS_KEY"

      on_step %(
        $step.run =~ ".*AWS_ACCESS_KEY_ID.*(\{\{.*secrets\.|\{\{.*vars\.|\{\{.*env\.|AKIA)" ||
        $step.run =~ ".*export AWS_ACCESS_KEY_ID.*(\{\{.*secrets\.|\{\{.*vars\.|\{\{.*env\.)" ||
        $step.run =~ ".*GITHUB_ENV.*AWS_ACCESS_KEY_ID.*(\{\{.*secrets\.|\{\{.*vars\.|\{\{.*env\.)" ||
        $step.run =~ ".*aws configure set aws_access_key_id.*(\{\{.*secrets\.|\{\{.*vars\.|\{\{.*env\.|AKIA)"
      ), highlight: "run"

      on_step %(
        $step.run =~ ".*AWS_SECRET_ACCESS_KEY.*(\{\{.*secrets\.|\{\{.*vars\.|\{\{.*env\.)" ||
        $step.run =~ ".*export AWS_SECRET_ACCESS_KEY.*(\{\{.*secrets\.|\{\{.*vars\.|\{\{.*env\.)" ||
        $step.run =~ ".*GITHUB_ENV.*AWS_SECRET_ACCESS_KEY.*(\{\{.*secrets\.|\{\{.*vars\.|\{\{.*env\.)" ||
        $step.run =~ ".*aws configure set aws_secret_access_key.*(\{\{.*secrets\.|\{\{.*vars\.|\{\{.*env\.)"
      ), highlight: "run"
    end
  end
end
