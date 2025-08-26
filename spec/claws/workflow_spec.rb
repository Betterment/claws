RSpec.describe Workflow do
  context "trigger normalizing" do
    it "a hash of triggers remains untouched" do
      workflow = described_class.load(<<~YAML)
        on:
          pull_request:
          push:
            branches: main

        jobs:
          deploy:
            steps:
              - id: merge this pull request
                name: automerge
                uses: "pascalgn/automerge-action@v0.15.5"
      YAML

      expect(workflow.meta["triggers"]).to eq(%w[pull_request push])
    end

    it "an array of triggers remains untouched" do
      workflow = described_class.load(<<~YAML)
        on: [pull_request, pull_request_target]

        jobs:
          deploy:
            steps:
              - id: merge this pull request
                name: automerge
                uses: "pascalgn/automerge-action@v0.15.5"
      YAML

      expect(workflow.meta["triggers"]).to eq(%w[pull_request pull_request_target])
    end

    it "a single string is normalized to an array" do
      workflow = described_class.load(<<~YAML)
        on:
          pull_request

        jobs:
          deploy:
            steps:
              - id: merge this pull request
                name: automerge
                uses: "pascalgn/automerge-action@v0.15.5"
      YAML

      expect(workflow.meta["triggers"]).to eq(["pull_request"])
    end
  end

  context "line information" do
    it "can find the line number of various types" do
      workflow = described_class.load(<<~YAML)
        on:
          pull_request

        jobs:
          deploy:
            steps:
              - id: merge this pull request
                name: automerge
                uses: "pascalgn/automerge-action@v0.15.5"
                with:
                  type_string: "string"
                  type_bool: true
                  type_integer: 1
                  type_nil: null
                  type_float: 1.2
      YAML

      values = { workflow:, job: workflow.jobs["deploy"], step: workflow.jobs["deploy"]["steps"][0] }
      expect(BaseRule.parse_rule('$step.with.type_string == "string"').eval_with(values:)).to eq true
      expect(BaseRule.parse_rule("$step.with.type_bool == true").eval_with(values:)).to eq true
      expect(BaseRule.parse_rule("$step.with.type_integer == 1").eval_with(values:)).to eq true
      expect(BaseRule.parse_rule("$step.with.type_nil == nil").eval_with(values:)).to eq true
      expect(BaseRule.parse_rule("$step.with.type_float == 1.2").eval_with(values:)).to eq true
    end
  end

  context "built in function - get_key" do
    it "extracts the key from a map" do
      workflow = described_class.load(<<~YAML)
        on:
          pull_request

        jobs:
          deploy:
            steps:
              - name: checkout
                uses: actions/checkout@v6
                with:
                  key: value
      YAML

      values = { workflow:, job: workflow.jobs["deploy"], step: workflow.jobs["deploy"]["steps"][0] }
      expect(BaseRule.parse_rule('get_key($step.with, "key")').eval_with(values:)).to eq "value"
    end

    it "returns nil if the key isn't found" do
      workflow = described_class.load(<<~YAML)
        on:
          pull_request

        jobs:
          deploy:
            steps:
              - name: checkout
                uses: actions/checkout@v6
                with:
                  key: value
      YAML

      values = { workflow:, job: workflow.jobs["deploy"], step: workflow.jobs["deploy"]["steps"][0] }
      expect(BaseRule.parse_rule('get_key($step.with, "nonexistent")').eval_with(values:)).to eq nil
    end

    it "returns nil if the input map is nil" do
      workflow = described_class.load(<<~YAML)
        on:
          pull_request

        jobs:
          deploy:
            steps:
              - name: checkout
                uses: actions/checkout@v6
      YAML

      values = { workflow:, job: workflow.jobs["deploy"], step: workflow.jobs["deploy"]["steps"][0] }
      expect(BaseRule.parse_rule('get_key($step.with, "nonexistent")').eval_with(values:)).to eq nil
    end
  end
end
