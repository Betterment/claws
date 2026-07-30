require "claws"

module ClawsHelper
  def load_detection
    detection = described_class.new(configuration: detection_config)
    @app = Claws::Application.new
    @app.load_detection(detection)
  end

  def analyze(input_yaml)
    @app.analyze("workflow.yml", input_yaml)
  end

  def detection_config
    return configuration if defined? configuration

    {}
  end

  def expect_rule_violations(violations, name:, lines:)
    expect(violations.count).to eq(lines.length)
    expect(violations.map(&:name).uniq).to eq([name])
    expect(violations.map(&:line).sort).to eq(lines.sort)
  end
end
