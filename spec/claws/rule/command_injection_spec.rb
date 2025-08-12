RSpec.describe Claws::Rule::CommandInjection do
  before do
    load_detection
  end

  context "with default configuration" do
    it "flags a step that contains a command injection vulnerability" do
      violations = analyze(<<~YAML)
        name: Greeting

        on:
          workflow_dispatch:
            inputs:
              name:
                description: 'Who I should say hello to?'
                required: true

        jobs:
          greet:
            runs-on: ubuntu-latest
            steps:
              - name: Checkout
                uses: actions/checkout@v1
              - name: Greet
                run: ./scripts/greet.sh "${{ github.event.inputs.name }}"
      YAML

      expect(violations.count).to eq(1)
      expect(violations[0].line).to eq(17)
      expect(violations[0].name).to eq("CommandInjection")
    end

    it "flags a step with github expression without spaces" do
      violations = analyze(<<~YAML)
        name: Pull Request Number

        on:
          pull_request:

        jobs:
          greet:
            runs-on: ubuntu-latest
            steps:
              - name: Checkout
                uses: actions/checkout@v1
              - name: Show PR Number
                # This expression does not contain a space between the enclosing brace and its contents
                run: echo "PR number is ${{github.event.pull_request.number}}"
      YAML

      expect(violations.count).to eq(1)
    end

    it "doesn't flag a step if it executes a command safely" do
      violations = analyze(<<~YAML)
        name: Greeting

        on:
          workflow_dispatch:
            inputs:
              name:
                description: 'Who I should say hello to?'
                required: true

        jobs:
          greet:
            runs-on: ubuntu-latest
            steps:
              - name: Checkout
                uses: actions/checkout@v1
              - name: Greet
                run: ./scripts/greet.sh "$NAME"
                env:
                  NAME: ${{ github.event.inputs.name }}
      YAML

      expect(violations.count).to eq(0)
    end

    it "doesn't flag non-inputs usages of github.event" do
      violations = analyze(<<~YAML)
        name: Greeting

        on:
          workflow_dispatch:
            inputs:
              name:
                description: 'Who I should say hello to?'
                required: true

        jobs:
          greet:
            runs-on: ubuntu-latest
            steps:
              - name: Checkout
                uses: actions/checkout@v1
              - name: Greet
                run: ./scripts/greet.sh "${{ github.event_name }}"
      YAML

      expect(violations.count).to eq(0)
    end
  end
end
