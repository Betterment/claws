module Claws
  module Rule
    class ConfigureAwsStaticCredentials < BaseRule
      description <<~DESC
        Avoid using long-lived AWS access keys in Github workflows. Static credentials
        can be tricky to audit and rotate, making them risky to hold onto, especially
        in the event of an incident where they may be leaked.

        Use GitHub's OIDC provider and authenticate with `role-to-assume` instead.

        For more information:
        https://github.com/betterment/claws/blob/main/README.md#configureawsstaticcredentials
      DESC

      on_workflow :flag_workflow_aws_access_key_env
      on_workflow :flag_workflow_aws_secret_key_env

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

      def flag_workflow_aws_access_key_env(workflow:, job:, step:) # rubocop:disable Lint/UnusedMethodArgument
        flag_workflow_env_var(workflow, "AWS_ACCESS_KEY_ID", include_akia: true)
      end

      def flag_workflow_aws_secret_key_env(workflow:, job:, step:) # rubocop:disable Lint/UnusedMethodArgument
        flag_workflow_env_var(workflow, "AWS_SECRET_ACCESS_KEY", include_akia: false)
      end

      private

      def flag_workflow_env_var(workflow, var_name, include_akia:)
        data = workflow_data(workflow)
        env_key = data.keys.find { |k| k.to_s == "env" }
        return unless env_key

        env = data[env_key]
        return unless env.is_a? Hash

        var_key = env.keys.find { |k| k.to_s == var_name }
        return unless var_key

        value = env[var_key]
        return unless static_aws_credential_value?(value, include_akia:)

        Violation.new(
          line: var_key.line,
          description:
        )
      end

      def workflow_data(workflow)
        workflow.instance_variable_get(:@workflow)
      end

      def static_aws_credential_value?(value, include_akia: false)
        return false unless value.is_a? String

        return true if include_akia && value =~ /AKIA/

        value =~ /\{\{.*secrets\./ ||
          value =~ /\{\{.*env\./ ||
          value =~ /\{\{.*vars\./
      end
    end
  end
end
