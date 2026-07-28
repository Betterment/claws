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

      expect(violations.count).to eq(2)
      expect(violations.map(&:name).uniq).to eq(["StaticAwsCredentials"])
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

      expect(violations.count).to eq(2)
      expect(violations[0].name).to eq("StaticAwsCredentials")
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

      expect(violations.count).to eq(2)
      expect(violations[0].name).to eq("StaticAwsCredentials")
    end

    it "flags a hardcoded aws access key id" do
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

      expect(violations.count).to eq(1)
      expect(violations[0].name).to eq("StaticAwsCredentials")
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

      expect(violations.count).to eq(2)
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

      expect(violations.count).to eq(2)
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

      expect(violations.count).to eq(2)
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

      expect(violations.count).to eq(2)
    end

    it "flags writing aws creds to GITHUB_ENV" do
      violations = analyze(<<~YAML)
        on: push

        jobs:
          deploy:
            runs-on: ubuntu-latest
            steps:
              - run: |
                  echo "AWS_ACCESS_KEY_ID=${{ secrets.AWS_ACCESS_KEY_ID }}" >> $GITHUB_ENV
                  echo "AWS_SECRET_ACCESS_KEY=${{ secrets.AWS_SECRET_ACCESS_KEY }}" >> $GITHUB_ENV
                  aws sts get-caller-identity
      YAML

      expect(violations.count).to eq(2)
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

      expect(violations.count).to eq(2)
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
