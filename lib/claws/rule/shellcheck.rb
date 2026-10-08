require "open3"

module Claws
  module Rule
    class Shellcheck < BaseRule
      description <<~DESC
        This shell script did not pass Shellcheck.

        For more information:
        https://github.com/betterment/claws/blob/main/README.md#shellcheck
      DESC

      on_step :shellcheck

      def shellcheck(workflow:, job:, step:) # rubocop:disable Lint/UnusedMethodArgument, Metrics/AbcSize
        unless File.exist? shellcheck_bin
          warn "Couldn't find shellcheck binary (#{shellcheck_bin}).\n"
          warn "Make sure it's installed and configure `shellcheck_bin` appropriately."
          exit 1
        end

        return if step["run"].nil?

        shell = if step["shell"].nil?
                  identify_shell(step["run"])
                else
                  step["shell"]
                end

        return if shell.nil?

        exit_status, stdout, = analyze_script(step["run"], shell)

        return unless exit_status == 1

        Violation.new(
          line: step.keys.filter { |x| x == "run" }.first.line,
          description: "Shellcheck found some issues with this shell script:\n#{stdout}"
        )
      end

      private

      def sanitize_script(script)
        mapping = {}

        new_script = script.gsub(/\$\{\{\s*(.*?)\s*\}\}/) do
          inner_content = ::Regexp.last_match(1).strip
          placeholder_name = "GITHUB_ACTION_PLACEHOLDER_#{inner_content.gsub(/[^a-zA-Z0-9]/, "_").upcase}"

          mapping[placeholder_name] = "${{ #{inner_content} }}"
          "$#{placeholder_name}"
        end

        [new_script.to_s, mapping]
      end

      def unsanitize_script(script, mapping)
        mapping.each do |k, v|
          script = script.gsub(k, v)
        end

        script
      end

      def analyze_script(script, shell)
        sanitized_script, variables = *sanitize_script(script)

        # scripts are piped in via stdin, so sourced files can never be followed
        # https://www.shellcheck.net/wiki/SC1090
        # https://www.shellcheck.net/wiki/SC1091
        Open3.popen3(
          shellcheck_bin, "-", "-s", shell, "-e", "SC1090,SC1091"
        ) do |stdin, stdout, stderr, wait_thr|
          stdin.write(sanitized_script)
          stdin.close

          stdout_buffer = stdout.read
          stderr_buffer = stderr.read

          stderr.close
          stdout.close

          return [
            wait_thr.value.exitstatus,
            unsanitize_script(stdout_buffer, variables),
            unsanitize_script(stderr_buffer, variables)
          ]
        end
      end

      def identify_shell(command)
        return "bash" unless command.lines.first.start_with? "#!"

        supported_shells.select do |shell|
          command.lines.first.start_with? "#!/bin/#{shell}"
        end.first
      end

      def supported_shells
        %w[bash sh dash ksh]
      end

      def shellcheck_bin
        configuration.fetch(
          "shellcheck_bin",
          "/opt/homebrew/bin/shellcheck"
        )
      end
    end
  end
end
