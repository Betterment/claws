RSpec.describe Claws::Rule::StaticAwsCredentials do
  before do
    load_detection
  end

  context "with default configuration" do
    it "flags static aws credentials via secrets" do
      violations = analyze(<<~YAML)
        on: push

        jobs:
          push-relations:
            runs-on: ubuntu-latest
            steps:
              - name: Configure prod aws credentials
                uses: aws-actions/configure-aws-credentials@v4
                with:
                  aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
                  aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
                  role-to-assume: arn:aws:iam::1234:role/the-role-that-lets-us-use-s3
                  aws-region: us-east-1
      YAML

      expect_rule_violations(
        violations,
        name: "StaticAwsCredentials",
        lines: [11]
      )
    end

    it "flags static aws credentials via repo/org vars" do
      violations = analyze(<<~YAML)
        on: push

        jobs:
          deploy:
            runs-on: ubuntu-latest
            steps:
              - uses: aws-actions/configure-aws-credentials@v4
                with:
                  aws-access-key-id: ${{ vars.AWS_ACCESS_KEY_ID }}
                  aws-secret-access-key: ${{ vars.AWS_SECRET_ACCESS_KEY }}
                  aws-region: us-east-1
      YAML

      expect_rule_violations(
        violations,
        name: "StaticAwsCredentials",
        lines: [10]
      )
    end

    it "flags static aws credentials via env vars" do
      violations = analyze(<<~YAML)
        on: push

        jobs:
          deploy:
            runs-on: ubuntu-latest
            steps:
              - uses: aws-actions/configure-aws-credentials@v4
                with:
                  aws-access-key-id: ${{ env.AWS_ACCESS_KEY_ID }}
                  aws-secret-access-key: ${{ env.AWS_SECRET_ACCESS_KEY }}
                  aws-region: us-east-1
      YAML

      expect_rule_violations(
        violations,
        name: "StaticAwsCredentials",
        lines: [10]
      )
    end

    it "doesn't flag when only the access key id is static" do
      violations = analyze(<<~YAML)
        on: push

        jobs:
          deploy:
            runs-on: ubuntu-latest
            steps:
              - uses: aws-actions/configure-aws-credentials@v4
                with:
                  aws-access-key-id: AKIAIOSFODNN7EXAMPLE
                  aws-secret-access-key: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
                  aws-region: us-east-1
      YAML

      expect(violations.count).to eq(0)
    end

    it "flags workflow-level env vars" do
      violations = analyze(<<~YAML)
        on: push

        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}

        jobs:
          deploy:
            runs-on: ubuntu-latest
            steps:
              - run: aws sts get-caller-identity
      YAML

      expect_rule_violations(
        violations,
        name: "StaticAwsCredentials",
        lines: [5]
      )
    end

    it "flags job-level env vars" do
      violations = analyze(<<~YAML)
        on: push

        jobs:
          deploy:
            runs-on: ubuntu-latest
            env:
              AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
              AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
            steps:
              - run: aws sts get-caller-identity
      YAML

      expect_rule_violations(
        violations,
        name: "StaticAwsCredentials",
        lines: [8]
      )
    end

    it "flags step-level env vars" do
      violations = analyze(<<~YAML)
        on: push

        jobs:
          deploy:
            runs-on: ubuntu-latest
            steps:
              - run: aws s3 ls
                env:
                  AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
                  AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      YAML

      expect_rule_violations(
        violations,
        name: "StaticAwsCredentials",
        lines: [10]
      )
    end

    it "flags export in a run step" do
      violations = analyze(<<~YAML)
        on: push

        jobs:
          deploy:
            runs-on: ubuntu-latest
            steps:
              - run: |
                  export AWS_ACCESS_KEY_ID=${{ secrets.AWS_ACCESS_KEY_ID }}
                  export AWS_SECRET_ACCESS_KEY=${{ secrets.AWS_SECRET_ACCESS_KEY }}
                  aws s3 ls
      YAML

      expect_rule_violations(
        violations,
        name: "StaticAwsCredentials",
        lines: [7]
      )
    end

    it "flags aws configure in a run step" do
      violations = analyze(<<~YAML)
        on: push

        jobs:
          deploy:
            runs-on: ubuntu-latest
            steps:
              - run: |
                  aws configure set aws_access_key_id ${{ secrets.AWS_ACCESS_KEY_ID }}
                  aws configure set aws_secret_access_key ${{ secrets.AWS_SECRET_ACCESS_KEY }}
                  aws sts get-caller-identity
      YAML

      expect_rule_violations(
        violations,
        name: "StaticAwsCredentials",
        lines: [7]
      )
    end

    it "doesn't flag role-to-assume" do
      violations = analyze(<<~YAML)
        on: push

        permissions:
          id-token: write
          contents: read

        jobs:
          deploy:
            runs-on: ubuntu-latest
            steps:
              - uses: aws-actions/configure-aws-credentials@v4
                with:
                  role-to-assume: arn:aws:iam::123456789012:role/github-actions-role
                  role-session-name: GitHub_to_AWS_via_FederatedOIDC
                  aws-region: us-east-1
              - run: aws sts get-caller-identity
      YAML

      expect(violations.count).to eq(0)
    end

    it "doesn't flag creds from step outputs" do
      violations = analyze(<<~YAML)
        on: push

        jobs:
          deploy:
            runs-on: ubuntu-latest
            steps:
              - id: aws-creds
                run: echo "not checked here"

              - run: aws s3 ls
                env:
                  AWS_ACCESS_KEY_ID: ${{ steps.aws-creds.outputs.access-key-id }}
                  AWS_SECRET_ACCESS_KEY: ${{ steps.aws-creds.outputs.secret-access-key }}
      YAML

      expect(violations.count).to eq(0)
    end

    it "doesn't flag export when secrets reference another variable on the same line" do
      violations = analyze(<<~YAML)
        on: push

        jobs:
          deploy:
            runs-on: ubuntu-latest
            steps:
              - run: |
                  export AWS_SECRET_ACCESS_KEY=${{ steps.aws-creds.outputs.secret-access-key }} SOMETHING_ELSE=${{ secrets.something_unrelated }}
                  aws sts get-caller-identity
      YAML

      expect(violations.count).to eq(0)
    end

    it "doesn't flag export from env in a run step" do
      violations = analyze(<<~YAML)
        on: push

        jobs:
          deploy:
            runs-on: ubuntu-latest
            steps:
              - run: |
                  export AWS_ACCESS_KEY_ID=${{ env.AWS_ACCESS_KEY_ID }}
                  export AWS_SECRET_ACCESS_KEY=${{ env.AWS_SECRET_ACCESS_KEY }}
                  aws sts get-caller-identity
      YAML

      expect(violations.count).to eq(0)
    end

    it "doesn't flag unrelated actions" do
      violations = analyze(<<~YAML)
        on: push

        jobs:
          deploy:
            runs-on: ubuntu-latest
            steps:
              - uses: actions/checkout@v4
                with:
                  token: ${{ secrets.AWS_ACCESS_KEY_ID }}
      YAML

      expect(violations.count).to eq(0)
    end
  end
end
