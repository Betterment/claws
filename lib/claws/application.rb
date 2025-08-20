module Claws
  class Application
    def initialize
      @detections = []
    end

    def load_detection(detection)
      @detections << detection
    end

    def analyze(filename, raw_contents)
      workflow = Workflow.load(raw_contents)

      file_ignores = workflow.ignores

      # enrich violations with snippets
      # skip violations if specifically ignored
      get_violations(filename, workflow).reject do |v|
        v.snippet = workflow.get_snippet(v.line)

        line_above = [1, v.line - 1].max
        ignores_for_line = file_ignores.fetch(line_above, [])
        ignores_for_line.include? v.name
      end
    end

    def get_violations(filename, workflow)
      violations = get_workflow_violations(filename, workflow)

      workflow.jobs.each do |_job_name, job|
        violations += get_job_violations(filename, workflow, job)

        job.fetch("steps", []).each do |step|
          violations += get_step_violations(filename, workflow, job, step)
        end
      end

      violations
    end

    def get_workflow_violations(filename, workflow)
      violations = []
      @detections.each do |detection|
        detection.on_workflow.each do |rule|
          violation = run_detection(
            filename:,
            detection:,
            rule:,
            workflow:
          )

          violations << violation if violation

          next if rule.is_a? Symbol or !rule[:debug]

          enter_debug(
            result: !violation.nil?,
            expression: rule[:expression],
            values: {
              data: detection.data,
              workflow:
            }
          )
        end
      end

      violations
    end

    def get_job_violations(filename, workflow, job)
      violations = []
      @detections.each do |detection|
        detection.on_job.each do |rule|
          violation = run_detection(
            filename:,
            detection:,
            rule:,
            workflow:,
            job:
          )

          violations << violation if violation

          next if rule.is_a? Symbol or !rule[:debug]

          enter_debug(
            result: !violation.nil?,
            expression: rule[:expression],
            values: {
              data: detection.data,
              workflow:,
              job:
            }
          )
        end
      end

      violations
    end

    def get_step_violations(filename, workflow, job, step)
      violations = []

      @detections.each do |detection|
        detection.on_step.each do |rule|
          violation = run_detection(
            filename:,
            detection:,
            rule:,
            workflow:,
            job:,
            step:
          )

          violations << violation if violation

          next if rule.is_a? Symbol or !rule[:debug]

          enter_debug(
            result: !violation.nil?,
            expression: rule[:expression],
            values: {
              data: detection.data,
              workflow:,
              job:,
              step:
            }
          )
        end
      end

      violations
    end

    private

    def run_detection(filename:, detection:, rule:, workflow:, job: nil, step: nil) # rubocop:disable Metrics/ParameterLists
      violation = if rule.is_a? Symbol
                    get_dynamic_violation(
                      detection:,
                      method: rule,
                      workflow:,
                      job:,
                      step:
                    )
                  else
                    get_static_violations(
                      detection:,
                      rule:,
                      workflow:,
                      job:,
                      step:
                    )
                  end

      if violation
        violation.file = filename
        violation.name = detection.name
      end

      violation
    end

    def get_dynamic_violation(detection:, method:, workflow:, job:, step:)
      detection.send(
        method,
        workflow:,
        job:,
        step:
      )
    end

    def get_static_violations(rule:, detection:, workflow:, job:, step:)
      result = rule[:expression].eval_with(values: {
                                             data: detection.data,
                                             workflow:,
                                             job:,
                                             step:
                                           })

      return unless result

      default_target = [step, job, workflow].find(&:itself)
      line_number = default_target.line
      line_number = get_nearest_key(default_target, rule[:highlight]).line if rule[:highlight]

      Violation.new(
        line: line_number,
        description: detection.description
      )
    end

    def enter_debug(result:, expression:, values:) # rubocop:disable Metrics/AbcSize
      @debug_values = values

      require "pry"
      puts "!!! CLAWS DEBUG !!!".red
      puts "#{expression} returned #{result}".red
      puts "Tips:"
      puts "* values available in @debug_values".green
      puts "* eval a test expression: e 'expression'".green
      puts "  * e '1 == 2'".green
      puts "  * e '$data'".green
      puts "  * e '$job.meta'".green
      puts "  * e '$job.meta.action.name in $data.automerge_actions'".green
      puts "* ^D to exit".green

      # no stack trace needed since there's no error
      binding.pry quiet: true # rubocop:disable Lint/Debugger
    end

    def e(expression)
      expr = BaseRule.parse_rule(expression)
      puts expr.eval_with(
        values: @debug_values
      ).inspect
    end

    def get_nearest_key(blob, path) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      cursor = blob
      found_key = nil
      path.split(".").each do |key|
        return found_key unless cursor.is_a? Hash or cursor.is_a? Workflow

        if cursor.include? key.to_s
          found_key = cursor.keys.filter { |k| k.to_s == key.to_s }.first
          cursor = cursor[key.to_s]
        elsif cursor.include? key.to_sym
          found_key = cursor.keys.filter { |k| k.to_sym == key.to_sym }.first
          cursor = cursor[key.to_sym]
        end
      end

      found_key
    end
  end
end
