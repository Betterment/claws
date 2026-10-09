require "equation"

class ExpressionParser
  def self.parse_expression(expression)
    get_engine.parse(rule: expression)
  end

  def self.get_engine # rubocop:disable Naming/AccessorMethodName, Metrics/AbcSize
    EquationEngine.new(
      default: {
        # workflow: workflow,
        # jobs: workflow["jobs"],
        # data: rules["data"],
      },
      methods: {
        contains: ->(haystack, needle) { !haystack.nil? and haystack.include? needle },
        contains_any: ->(haystack, needles) { !haystack.nil? and needles.any? { |n| haystack.include? n } },
        startswith: ->(string, needle) { string.to_s.start_with? needle },
        endswith: ->(string, needle) { string.to_s.end_with? needle },
        difference: ->(arr1, arr2) { arr1.difference arr2 },
        count: lambda(&:length)
      }
    )
  end
end
