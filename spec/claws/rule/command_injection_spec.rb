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
                run: ./scripts/greet.sh "${{join(github.event.inputs.name)}}"
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

    it "flags an expression containing a lone closing brace" do
      violations = analyze(<<~YAML)
        name: Greeting

        on:
          issues:

        jobs:
          greet:
            runs-on: ubuntu-latest
            steps:
              - name: Greet
                run: echo "${{ format('Title - {0}', github.event.issue.title) }}"
      YAML

      expect(violations.count).to eq(1)
    end

    it "flags an expression in the middle of a multiline script" do
      violations = analyze(<<~YAML)
        name: Greeting

        on:
          issues:

        jobs:
          greet:
            runs-on: ubuntu-latest
            steps:
              - name: Greet
                run: |
                  echo "starting"
                  echo "${{ github.event.issue.title }}"
                  echo "done"
      YAML

      expect(violations.count).to eq(1)
    end

    it "doesn't flag template syntax that isn't a github expression" do
      # gh-aw lock files render prompts with handlebars-style {{#if}} blocks;
      # the runner never expands these, so they can't inject into the shell
      violations = analyze(<<~YAML)
        name: CI Fixer

        on:
          pull_request:
            types:
              - labeled

        jobs:
          activation:
            runs-on: ubuntu-latest
            steps:
              - name: Create prompt
                env:
                  GH_AW_EXPR_463A214A: ${{ github.event.pull_request.number }}
                run: |
                  cat << 'GH_AW_PROMPT_EOF'
                  {{#if github.event.pull_request.number || (github.aw.context.item_type == 'pull_request' && github.aw.context.item_number)}}
                  - **pull-request-number**: #__GH_AW_EXPR_463A214A__
                  {{/if}}
                  GH_AW_PROMPT_EOF
      YAML

      expect(violations.count).to eq(0)
    end

    it "doesn't flag text between two unrelated expressions" do
      violations = analyze(<<~YAML)
        name: Greeting

        on:
          push:

        jobs:
          greet:
            runs-on: ubuntu-latest
            steps:
              - name: Greet
                run: echo "${{ matrix.os }}" > inputs.txt && echo "${{ matrix.version }}"
      YAML

      expect(violations.count).to eq(0)
    end
  end
end
