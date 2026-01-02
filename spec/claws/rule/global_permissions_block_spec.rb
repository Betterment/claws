RSpec.describe Claws::Rule::GlobalPermissionsBlock do
  before do
    load_detection
  end

  context "with default configuration" do
    it "flags a workflow with a top level permissions block if there is more than one job" do
      violations = analyze(<<~YAML)
        name: publish docs

        on:
          push:
            branches:
              - main

        permissions:
          contents: read
          pages: write
          id-token: write

        jobs:
          build:
            runs-on: ubuntu-latest
            steps:
              - name: Checkout
                uses: actions/checkout@v6

          deploy:
            needs: build
            runs-on: ubuntu-latest
            environment:
              name: github-pages
            steps:
              - name: Deploy to GitHub Pages
                id: deployment
                uses: actions/deploy-pages@v4
      YAML

      expect(violations.count).to eq(1)
      expect(violations[0].line).to eq(8)
      expect(violations[0].name).to eq("GlobalPermissionsBlock")
    end

    it "does not flag a workflow with a top level permissions block if there is just one job" do
      violations = analyze(<<~YAML)
        name: pretend to publish docs

        on:
          push:
            branches:
              - main

        permissions:
          contents: read
          pages: write
          id-token: write

        jobs:
          build:
            runs-on: ubuntu-latest
            steps:
              - name: Checkout
                uses: actions/checkout@v6
      YAML

      expect(violations.count).to eq(0)
    end

    it "does not flag a workflow if there is no top level permissions block" do
      violations = analyze(<<~YAML)
        name: publish docs

        on:
          push:
            branches:
              - main

        jobs:
          permissions:
            contents: read
            pages: write
            id-token: write

          build:
            runs-on: ubuntu-latest
            steps:
              - name: Checkout
                uses: actions/checkout@v6

          deploy:
            needs: build
            runs-on: ubuntu-latest
            environment:
              name: github-pages
            steps:
              - name: Deploy to GitHub Pages
                id: deployment
                uses: actions/deploy-pages@v4
      YAML

      expect(violations.count).to eq(0)
    end
  end
end
