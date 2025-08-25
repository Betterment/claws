RSpec.describe Claws::Rule::CheckoutWithStaticCredentials do
  before do
    load_detection
  end

  context "with default configuration" do
    it "flags a static ssh key via secrets" do
      violations = analyze(<<~YAML)
        on: push

        jobs:
          checkout:
            runs-on: ubuntu
            steps:
              - uses: actions/checkout@v5
                with:
                  repository: foo-corp/test-action
                  ssh-key: ${{ secrets.deploy_key }}
      YAML

      expect(violations.count).to eq(1)
      expect(violations[0].line).to eq(10)
      expect(violations[0].name).to eq("CheckoutWithStaticCredentials")
    end

    it "flags a static ssh key via repo/org vars" do
      violations = analyze(<<~YAML)
        on: push

        jobs:
          checkout:
            runs-on: ubuntu
            steps:
              - uses: actions/checkout@v5
                with:
                  repository: foo-corp/test-action
                  ssh-key: ${{ vars.deploy_key }}
      YAML

      expect(violations.count).to eq(1)
      expect(violations[0].line).to eq(10)
      expect(violations[0].name).to eq("CheckoutWithStaticCredentials")
    end

    it "flags a static ssh key via env vars" do
      violations = analyze(<<~YAML)
        on: push

        jobs:
          checkout:
            runs-on: ubuntu
            steps:
              - uses: actions/checkout@v5
                with:
                  repository: foo-corp/test-action
                  token: ${{ env.deploy_key }}
      YAML

      expect(violations.count).to eq(1)
      expect(violations[0].line).to eq(10)
      expect(violations[0].name).to eq("CheckoutWithStaticCredentials")
    end

    it "flags a static ssh key via hardcoded string" do
      violations = analyze(<<~YAML)
        on: push

        jobs:
          checkout:
            runs-on: ubuntu
            steps:
              - uses: actions/checkout@v5
                with:
                  repository: foo-corp/test-action
                  ssh-key: |
                    -----BEGIN OPENSSH PRIVATE KEY-----
                    sike... you thought
                    -----END OPENSSH PRIVATE KEY-----
      YAML

      expect(violations.count).to eq(1)
      expect(violations[0].line).to eq(10)
      expect(violations[0].name).to eq("CheckoutWithStaticCredentials")
    end

    it "flags a static PAT stored in secrets" do
      violations = analyze(<<~YAML)
        on: push

        jobs:
          checkout:
            runs-on: ubuntu
            steps:
              - uses: actions/checkout@v5
                with:
                  repository: foo-corp/test-action
                  token: ${{ secrets.secret_pat }}
      YAML

      expect(violations.count).to eq(1)
      expect(violations[0].line).to eq(10)
      expect(violations[0].name).to eq("CheckoutWithStaticCredentials")
    end

    it "flags a static PAT stored in repo/org vars" do
      violations = analyze(<<~YAML)
        on: push

        jobs:
          checkout:
            runs-on: ubuntu
            steps:
              - uses: actions/checkout@v5
                with:
                  repository: foo-corp/test-action
                  token: ${{ vars.secret_pat }}
      YAML

      expect(violations.count).to eq(1)
      expect(violations[0].line).to eq(10)
      expect(violations[0].name).to eq("CheckoutWithStaticCredentials")
    end

    it "flags a static PAT stored in env vars" do
      violations = analyze(<<~YAML)
        on: push

        jobs:
          checkout:
            runs-on: ubuntu
            steps:
              - uses: actions/checkout@v5
                with:
                  repository: foo-corp/test-action
                  token: ${{ env.some_pat }}
      YAML

      expect(violations.count).to eq(1)
      expect(violations[0].line).to eq(10)
      expect(violations[0].name).to eq("CheckoutWithStaticCredentials")
    end

    it "flags a static PAT via hardcoded string" do
      violations = analyze(<<~YAML)
        on: push

        jobs:
          checkout:
            runs-on: ubuntu
            steps:
              - uses: actions/checkout@v5
                with:
                  repository: foo-corp/test-action
                  token: "ghp_some_bogus_string"
      YAML

      expect(violations.count).to eq(1)
      expect(violations[0].line).to eq(10)
      expect(violations[0].name).to eq("CheckoutWithStaticCredentials")
    end

    it "doesn't flag an access token generated using a github app" do
      violations = analyze(<<~YAML)
        on: push

        jobs:
          checkout:
            runs-on: ubuntu
            steps:
              - name: Create GitHub App installation token
                id: app-token
                uses: actions/create-github-app-token@v2
                with:
                  app-id: ${{ vars.APP_ID }}
                  private-key: ${{ secrets.APP_PRIVATE_KEY }}

              - uses: actions/checkout@v5
                with:
                  repository: foo-corp/test-action
                  token: ${{ steps.app-token.outputs.token }}
      YAML

      expect(violations.count).to eq(0)
    end
  end
end
