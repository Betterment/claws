class BaseRule
  attr_accessor :on_workflow, :on_job, :on_step, :configuration

  def self.parse_rule(rule) # rubocop:disable Metrics/AbcSize
    ExpressionParser.parse_expression(rule).tap do |expression|
      expression.instance_eval do
        def ctx # rubocop:disable Metrics/AbcSize
          @ctx ||= Context.new(
            default: {},
            methods: {
              contains: ->(haystack, needle) { !haystack.nil? and haystack.include? needle },
              contains_any: ->(haystack, needles) { !haystack.nil? and needles.any? { |n| haystack.include? n } },
              startswith: ->(string, needle) { string.to_s.start_with? needle },
              endswith: ->(string, needle) { string.to_s.end_with? needle },
              difference: ->(arr1, arr2) { arr1.difference arr2 },
              intersection: ->(arr1, arr2) { arr1.intersection arr2 },
              get_key: ->(arr, key) { arr.fetch(key, nil) },
              count: ->(n) { n.length }
            }
          )
        end

        def eval_with(values: {})
          value(
            ctx: ctx.tap { |c| c.transient_symbols = values }
          )
        end

        def inspect
          to_s
        end

        def to_s
          "<Expression '#{input}'>"
        end
      end
    end
  end

  def self.name(value)
    define_method(:name) { value }
  end

  def self.description(value)
    define_method(:description) { value }
  end

  def self.on_workflow(value, highlight: nil, debug: false)
    (@on_workflow ||= []) << extract_value(value, highlight:, debug:)
  end

  def self.on_job(value, highlight: nil, debug: false)
    highlight = highlight.to_s unless highlight.nil?
    (@on_job ||= []) << extract_value(value, highlight:, debug:)
  end

  def self.on_step(value, highlight: nil, debug: false)
    highlight = highlight.to_s unless highlight.nil?
    (@on_step ||= []) << extract_value(value, highlight:, debug:)
  end

  def self.extract_value(value, highlight: nil, debug: false)
    case value
    when String
      { expression: parse_rule(value), highlight:, debug: }
    when Symbol
      value
    else
      raise "Hook must receive either a String (rule) or Symbol (method name), not: #{value.class}"
    end
  end

  def initialize(configuration: nil)
    @on_workflow = self.class.instance_variable_get(:@on_workflow) || []
    @on_job = self.class.instance_variable_get(:@on_job) || []
    @on_step = self.class.instance_variable_get(:@on_step) || []
    @configuration = configuration
  end

  def name
    self.class.to_s.split("::").last
  end

  def inspect
    to_s
  end

  def to_s
    "<Rule #{name} (#{@on_workflow.length} Workflow Rules; #{@on_job.length} Job Rules; #{@on_step.length} Step Rules)>"
  end

  def data
    {}
  end
end
