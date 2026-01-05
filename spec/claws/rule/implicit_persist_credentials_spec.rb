RSpec.describe Claws::Rule::ImplicitPersistCredentials do
  before do
    load_detection
  end

  context "with default configuration" do
    it "flags a checkout with no explicit setting for persist-credentials" do
      violations = analyze(<<~YAML)
        name: Check out the current repository

        on: [pull_request]

        jobs:
          build:
            steps:
            - uses: actions/checkout@v6
            - run: |
                rake setup
                rake spec
      YAML

      expect(violations.count).to eq(1)
      expect(violations[0].line).to eq(8)
      expect(violations[0].name).to eq("ImplicitPersistCredentials")
    end

    it "doesn't flag a checkout if persist-credentials is set to true" do
      violations = analyze(<<~YAML)
        name: Check out the current repository

        on: [pull_request]

        jobs:
          build:
            steps:
            - uses: actions/checkout@v6
              with:
                persist-credentials: false
            - run: |
                rake setup
                rake spec
      YAML

      expect(violations.count).to eq(0)
    end

    it "doesn't flag a checkout if persist-credentials is set to false" do
      violations = analyze(<<~YAML)
        name: Check out the current repository

        on: [pull_request]

        jobs:
          build:
            steps:
            - uses: actions/checkout@v6
              with:
                persist-credentials: false
            - run: |
                rake setup
                rake spec
      YAML

      expect(violations.count).to eq(0)
    end

    it "flags a checkout if persist-credentials is set to a non-boolean" do
      violations = analyze(<<~YAML)
        name: Check out the current repository

        on: [pull_request]

        jobs:
          build:
            steps:
            - uses: actions/checkout@v6
              with:
                persist-credentials: hello
            - run: |
                rake setup
                rake spec
      YAML

      expect(violations.count).to eq(1)
      expect(violations[0].line).to eq(8)
      expect(violations[0].name).to eq("ImplicitPersistCredentials")
    end
  end
end
