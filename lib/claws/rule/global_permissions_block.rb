module Claws
  module Rule
    class GlobalPermissionsBlock < BaseRule
      description <<~DESC
        Permissions should be set at the job level, not globally at the workflow level.
        Because jobs will often need varying permissions, it's better to specify a set
        of permissions for each individual job, minimizing potential misuse from
        untrusted code in a job with permissions it never needed in the first place.

        This rule will flag workflows that have multiple jobs and a root level
        permissions block. If there is a root level permissions block but just one job,
        it will not be flagged.

        For more information:
        https://github.com/betterment/claws/blob/main/README.md#globalpermissionsblock
      DESC

      on_workflow :test_root_level_permissions

      def test_root_level_permissions(workflow:, job:, step:) # rubocop:disable Lint/UnusedMethodArgument
        root_permission_block_line = workflow.keys.filter { |x| x == "permissions" }.first&.line
        return if root_permission_block_line.nil?

        job_count = workflow["jobs"]&.count || 0
        return if job_count < 2

        Violation.new(
          line: root_permission_block_line,
          description:
        )
      end
    end
  end
end
