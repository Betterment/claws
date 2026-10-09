RSpec.describe Claws::Rule::Shellcheck do
  before do
    load_detection
    allow(File).to receive(:exist?).and_return(true)
  end

  context "with default configuration" do
    let(:shellcheck_no_finding) { [0, nil, nil] }
    let(:shellcheck_finding) { [1, "^-- SC2086 (info): Double quote to prevent globbing and word splitting.", nil] }

    it "does not execute shellcheck if there is no run command" do
      allow(Open3).to receive(:popen3)

      violations = analyze(<<~YAML)
        on: [push, pull_request, pull_request_target]
        jobs:
          test:
            runs-on: ubuntu-latest
            steps:
            - uses: actions/checkout@v3
      YAML

      expect(Open3).not_to have_received(:popen3)
      expect(violations.count).to eq(0)
    end

    it "flags a command shellcheck would flag" do
      allow(Open3).to receive(:popen3).and_return(shellcheck_finding)

      violations = analyze(<<~YAML)
        on: [push, pull_request, pull_request_target]
        jobs:
          test:
            runs-on: ubuntu-latest
            steps:
            - uses: actions/checkout@v3
            - uses: ruby/setup-ruby@v1
            - run: |
                #!/bin/bash

                x=$(whoami)
                echo Hello, $x
      YAML

      expect(Open3).to have_received(:popen3).with(
        "/opt/homebrew/bin/shellcheck", "-", "-s", "bash", "-e", "SC1090,SC1091"
      )
      expect(violations.count).to eq(1)
      expect(violations[0].line).to eq(8)
      expect(violations[0].name).to eq("Shellcheck")
    end

    it "exits with an error if shellcheck can't be found" do
      allow(Open3).to receive(:popen3).and_return(shellcheck_finding)
      allow(File).to receive(:exist?).and_return(false)

      expect do
        analyze(<<~YAML)
          on: [push, pull_request, pull_request_target]
          jobs:
            test:
              runs-on: ubuntu-latest
              steps:
              - uses: actions/checkout@v3
              - uses: ruby/setup-ruby@v1
              - run: |
                  #!/bin/bash

                  x=$(whoami)
                  echo Hello, $x
        YAML
      end.to raise_error(SystemExit) { |error|
        expect(error.status).to eq(1)
      }.and output(%r{Couldn't find shellcheck binary \(/opt/homebrew/bin/shellcheck\)}).to_stderr

      expect(Open3).not_to have_received(:popen3)
    end

    it "doesn't run shellcheck if the shell cannot be identified" do
      allow(Open3).to receive(:popen3)

      violations = analyze(<<~YAML)
        on: [push, pull_request, pull_request_target]
        jobs:
          test:
            runs-on: ubuntu-latest
            steps:
            - uses: actions/checkout@v3
            - uses: ruby/setup-ruby@v1
            - run: |
                #!/bin/zsh

                echo 'Shellcheck does not support zsh!'
      YAML

      expect(Open3).not_to have_received(:popen3)
      expect(violations.count).to eq(0)
    end

    it "runs shellcheck with -s sh if given a sh script" do
      allow(Open3).to receive(:popen3).and_return(shellcheck_no_finding)

      violations = analyze(<<~YAML)
        on: [push, pull_request, pull_request_target]
        jobs:
          test:
            runs-on: ubuntu-latest
            steps:
            - uses: actions/checkout@v3
            - uses: ruby/setup-ruby@v1
            - run: |
                #!/bin/sh

                echo 'Hi!'
      YAML

      expect(Open3).to have_received(:popen3).with(
        "/opt/homebrew/bin/shellcheck", "-", "-s", "sh", "-e", "SC1090,SC1091"
      )
      expect(violations.count).to eq(0)
    end

    it "doesn't flag a command shellcheck would not flag" do
      allow(Open3).to receive(:popen3).and_return(shellcheck_no_finding)

      violations = analyze(<<~YAML)
        on: [push, pull_request, pull_request_target]
        jobs:
          test:
            runs-on: ubuntu-latest
            steps:
            - uses: actions/checkout@v3
            - uses: ruby/setup-ruby@v1
            - run: |
                #!/bin/bash

                x=$(whoami)
                echo "Hello, $x"
      YAML

      expect(Open3).to have_received(:popen3).with(
        "/opt/homebrew/bin/shellcheck", "-", "-s", "bash", "-e", "SC1090,SC1091"
      )
      expect(violations.count).to eq(0)
    end
  end

  context "with a shellcheck binary installed to a different path" do
    let(:configuration) { { "shellcheck_bin" => "/a/b/c" } }
    let(:shellcheck_no_finding) { [0, nil, nil] }
    let(:shellcheck_finding) { [1, "^-- SC2086 (info): Double quote to prevent globbing and word splitting.", nil] }

    it "flags a command shellcheck would flag" do
      allow(Open3).to receive(:popen3).and_return(shellcheck_finding)

      violations = analyze(<<~YAML)
        on: [push, pull_request, pull_request_target]
        jobs:
          test:
            runs-on: ubuntu-latest
            steps:
            - uses: actions/checkout@v3
            - uses: ruby/setup-ruby@v1
            - run: |
                #!/bin/bash

                x=$(whoami)
                echo Hello, $x
      YAML

      expect(Open3).to have_received(:popen3).with(
        "/a/b/c", "-", "-s", "bash", "-e", "SC1090,SC1091"
      )
      expect(violations.count).to eq(1)
      expect(violations[0].line).to eq(8)
      expect(violations[0].name).to eq("Shellcheck")
    end

    it "exits with an error if shellcheck can't be found" do
      allow(Open3).to receive(:popen3).and_return(shellcheck_finding)
      allow(File).to receive(:exist?).and_return(false)

      expect do
        analyze(<<~YAML)
          on: [push, pull_request, pull_request_target]
          jobs:
            test:
              runs-on: ubuntu-latest
              steps:
              - uses: actions/checkout@v3
              - uses: ruby/setup-ruby@v1
              - run: |
                  #!/bin/bash

                  x=$(whoami)
                  echo Hello, $x
        YAML
      end.to raise_error(SystemExit) { |error|
        expect(error.status).to eq(1)
      }.and output(%r{Couldn't find shellcheck binary \(/a/b/c\)}).to_stderr

      expect(Open3).not_to have_received(:popen3)
    end

    it "doesn't flag a command shellcheck would not flag" do
      allow(Open3).to receive(:popen3).and_return(shellcheck_no_finding)

      violations = analyze(<<~YAML)
        on: [push, pull_request, pull_request_target]
        jobs:
          test:
            runs-on: ubuntu-latest
            steps:
            - uses: actions/checkout@v3
            - uses: ruby/setup-ruby@v1
            - run: |
                #!/bin/bash

                x=$(whoami)
                echo "Hello, $x"
      YAML

      expect(Open3).to have_received(:popen3).with(
        "/a/b/c", "-", "-s", "bash", "-e", "SC1090,SC1091"
      )
      expect(violations.count).to eq(0)
    end
  end
end
