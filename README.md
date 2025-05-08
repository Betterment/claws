# Claws

Claws is a static analysis tool to help you write safer Github Workflows. Inspired by [rubocop](https://github.com/rubocop/rubocop) and its [def_node_matcher](https://docs.rubocop.org/rubocop-ast/node_pattern.html), Claws' rules are simple Ruby classes that contain expressions describing undesirable behaviors. These expressions (written in the [equation expression language](https://github.com/ancat/equation#language-features)) are evaluated at each "depth" of a Github Workflow: Workflow, Job, Step. Any part of a Workflow that causes an expression to return true is surfaced to the user as a violation. 

Rules were designed to be straightforward to write. You do not need to write any application logic -- all you need is a single Equation expression to get started. These do not have to be static expressions either. As you write your expressions, you may find yourself wanting to yield some amount of configurability to the user of your rules. Claws, however, allows you to use variables in your expressions that are populated at runtime by whatever values the user provides.

This is in contrast to common static analysis tools that achieve this by requiring custom application logic to different configuration values as edgecases. For Claws, this means instead of having to write Ruby code that handles parsing configuration options and branching based on those values, you can represent these as options from within your expression.

While it's important to be able to easily write a Rule, it's just as important (if not more!) to write good tests for them. Like with Rubocop, Claws comes with a couple RSpec helpers that makes it easy to write test cases. Test cases are simply example Workflows that exercise a Rule's expressions, ensuring that a modification to a Rule can't accidentally affect its ability to detect known bad content.

## Getting Started

Claws is written in Ruby and distributed as a Ruby Gem, so you can install it using `gem`. Just point it at the [example configuration](example-config.yml) file and you should be good to go.

For one off scans, you can just follow these commands:
```
# Install claws
$ gem install claws-scan

# Optionally, specify a version
$ gem install claws-scan -v 0.7.5

# Scan a Github Action file
analyze -c example_config.yml -t .github/workflows/ci.yml
```

If you'd like to integrate this into your workflow like we have, this should be enough to get you started.

```yaml
name: Workflow Static Analyzer

on:
  pull_request:
    branches:
      - main

jobs:
  build:
    name: Analyze Github Workflows
    runs-on: ubuntu-latest
    steps:
      - name: Set Up Ruby
        uses: ruby/setup-ruby@d8d83c3960843afb664e821fed6be52f37da5267 # v1.231.0
        with:
          ruby-version: '3.0'
      # Grab your configuration file however makes sense for you
      # We keep ours in a separate Github repo.
      - name: Set Up Claws Config
        run: |
          echo ... > /tmp/claws-config.yml
      # Optional, useful if you want Claws to run shellcheck for you
      - name: Set Up Shellcheck
        run: |
          sudo apt-get update
          sudo apt-get install -y shellcheck
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Set Up Claws
        run: |
          gem install claws-scan -v 0.7.5
      - name: Analyze Workflows
        run: |
          #!/bin/bash

          # Collect all files in the .github/workflows directory
          workflow_files=$(find .github/workflows -type f)

          # Exit early if there are no workflow files
          if [[ -z "$workflow_files" ]]; then
            echo "No workflow files found in .github/workflows"
            exit 0
          fi

          flags=()

          # Iterate over each workflow file
          while IFS= read -r file; do
            echo "Processing $file"
            flags+=("-t" "$file")
          done <<< "$workflow_files"

          # Run the analyze command with all gathered flags
          analyze -f github -c /tmp/claws-config.yml "${flags[@]}"
```

## Built In Rules

These are all the rules that come out of the box with Claws. They can all be found in [the rules subdirectory](https://github.com/Betterment/claws/tree/main/lib/claws/rule), and some of them have configuration options.

### AutomaticMerge

This rule flags a Github Action that looks like it might attempt to automatically merge a pull request, regardless of the criteria to do so. It makes no attempt at understanding the criteria, but instead it flags to a reviewer that this is happening and the logic behind it should be scrutinized.

It attempts to detect automatic merges using two heuristics:
* any invocation of the [gh cli](https://cli.github.com/manual/gh_pr) that looks like a command that'll merge the PR
* any use of a known Github Action that automatically merges.

#### Configuration Options

| Option       | Default Value          | Description                                                   |
|-------------|------------------------|---------------------------------------------------------------|
| `pr_events` | ["push", "pull_request_target", "pull_request", "pull_request_comment", "pull_request_review","pull_request_review_comment", "workflow_dispatch", "workflow_call"] | A list of github events to consider an action capable of automatically merging a pull request |
| automerge_actions | ["reitermarkus/automerge", "pascalgn/automerge-action"] | Common Github Actions used to automatically merge a pull request |

### BulkPermissions

This rule flags a Github Action that requests `write-all` or `read-all` permissions anywhere.

Github Actions should list each individual permission it needs to run properly, instead of requesting everything all at once. This helps mitigate the damage that a Github Action that either has a malicious dependency or otherwise has been compromised can do.

The following workflow for example, requests write permissions for everything:

```yaml
name: Deploy

on:
  push:
    branches:
    - main

permissions: write-all

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: action/checkout@v3
      - name: push
                run: rake release
```

But because we know specifically what this workflow needs to run, we can be more explicit about the permissions it requests.

```yaml
name: Deploy

on:
  push:
    branches:
    - main

permissions:
  packages: write

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: action/checkout@v3
      - name: push
                run: rake release
```

### CommandInjection

This rule looks for Github Actions that run shell commands that are vulnerable to command injection. Specifically, it looks for shell commands that use Github's parameterization feature to embed user input (e.g. `${{ github.event.inputs.name }}`) While the command injection vulnerability may not look obvious, even with quotes around the variable, these variables are expanded before the shell command is executed, so the only way to safely embed these variables in your command is to pass them in as environment variables.

For example, take the following job:

```yaml
jobs:
  greet:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v1
      - name: Greet
        run: ./scripts/greet.sh "${{ github.event.inputs.name }}"
```

A user could trigger this workflow and pass in a name as input with `$(echo hacked)`, causing the final command to look like this:

```
./scripts/greet.sh "$(echo hacked)"
```

which naturally, will execute the user's code in your workflow. This would give an attacker the ability to execute arbitrary code in the context of your workflow, so if it has access to credentials or sensitive files, they would be able to access those too. To address this vulnerablity, we would pass this input in as an environment variable:

```yaml
jobs:
  greet:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v1
      - name: Greet
        env:
          NAME: ${{ github.events.inputs.name }}
        run: ./scripts/greet.sh "$NAME"
```

For more information, check [Github's official blog post on these bugs](https://github.blog/security/supply-chain-security/four-tips-to-keep-your-github-actions-workflows-secure/#understanding-command-injection-vulnerabilities-in-github-actions-workflows).

### EmptyName

This rule flags Github Actions that have empty names. Not specifying a name makes it harder to distinguish workflows, especially in repositories with many of them.

### InheritedSecrets

This rule flags Github Actions that allow reusable workflows to inherit secrets from the calling workflow. This means any secrets pulled in by a workflow will be accessible to the reusable workflow, even if it doesn't need them to function. This can be problematic for bigger workflows that do many things and pull in many secrets, especially when new secrets are added that will quietly be passed to the reusable workflow.

The workflow should be called with just the secrets it needs to run.

For example, this workflow uses a reusable workflow with `secrets` set to `inherit`. From simply reading the code, it's not clear what secrets it needs to run; you would need to read the workflow's source code to determine that for yourself, and there's still no guarantee that won't change:

```yaml
jobs:
  call-workflow-passing-data:
    uses: octo-org/example-repo/.github/workflows/reusable-workflow.yml@main
    secrets: inherit
```

Instead, we can pass in a specific secret:

```yaml
jobs:
  call-workflow-passing-data:
    uses: octo-org/example-repo/.github/workflows/reusable-workflow.yml@main
    secrets:
      access-token: ${{ secrets.PERSONAL_ACCESS_TOKEN }}
```

Being explicit about secrets keeps us safe and makes our code reviewers' lives easier.

For more information, check out [Github's official documentation on passing in secrets](https://docs.github.com/en/actions/sharing-automations/reusing-workflows#passing-inputs-and-secrets-to-a-reusable-workflow).

### NoContainers

This rule flags any actions that use non-standard container images. Because using a container image can obscure the purpose of a step, some organizations may want to limit their use.

As an alternative, you can either
* Ignore this finding for a one off scenario.
* Opt out of using a container altogether.
* Configure the rule to allow only specific container images.

By default, the container image allowlist is empty. You could for example, add `ubuntu-latest` to that list if this is an image you're comfortable with developers using in their workflows.

#### Configuration Options

| Option       | Default Value          | Description                                                   |
|-------------|------------------------|---------------------------------------------------------------|
| `approved_images` | []               | An array of approved container images |

### RiskyTriggers

This rule flags actions that have triggers that may have unintended side effects. By default, this rule looks for two triggers:

* `pull_request_target`: This trigger allows an action to run by default in the context of a user's supplied branch. This can lead to unintended consequences where code is executed from the branch, giving an attacker code execution in the context of any of your secrets or other sensitive data. Check out [Github's blog post on this topic](https://securitylab.github.com/resources/github-actions-preventing-pwn-requests/) for more information.
* `workflow_dispatch`: This trigger executes a workflow outside of the typical pull request flow. Anyone with push permissions for the repository can trigger this workflow which sometimes is desirable, but sometimes can be a surprise, especially for larger Github organizations. You may want someone to be able to write to a repository, but not execute code with any associated secrets.

To review changes to Github Actions that use `pull_request_target` or `workflow_dispatch`, asking the following questions should help:
* Does this workflow fetch code from a user supplied branch and execute any of it? Keep in mind that code execution can happen indirectly e.g. an `npm install` command may execute code from the user's branch, even if the step in your Github Action doesn't take user input directly.
* In the event we do need to execute user supplied code (e.g. tests), are we passing any credentials to it? If we are, what are the capabilities of these credentials? Can we use these credentials in a separate job to isolate them from user code?

In some cases, a workflow can be rewritten to not need either of these permissions. In other cases, this is impossible. This rule exists to flag to the code reviewer that this is a risk that needs to be weighed.

If one of these triggers is one you've already accounted for in your threat model, you can remove it from the `risky_triggers`, or you could add new ones altogether.

#### Configuration Options

| Option       | Default Value          | Description                                                   |
|-------------|------------------------|---------------------------------------------------------------|
| `risky_triggers` | ["pull_request_target", "workflow_dispatch"]               | An array of triggers you consider risky. |

### Shellcheck

This rule runs [Shellcheck](https://github.com/koalaman/shellcheck) on shell commands. Effectively, this rule forks off to `shellcheck` and any non-zero complaints it has are considered findings.

Shellcheck is a great tool for dealing with bugs or otherwise unintended effects in shell commands, some of which can result in vulnerabilities. As with running `shellcheck` individually, you can ignore specific findings in shell commands embedded inside workflows.

#### Configuration Options

| Option       | Default Value          | Description                                                   |
|-------------|------------------------|---------------------------------------------------------------|
| `shellcheck_bin` | "/opt/homebrew/bin/shellcheck" | A string that contains the path to the shellcheck binary on your system. |


### SpecialPermissions

This rule flags workflows that request write access to specific unusual permissions. While this rule cannot flag how these permissions are exercised, it serves as a warning to code reviewers that if these permissions are requested, the way they are used should be scrutinized. A reviewer may find that a permission is left over from testing and no longer needed, or that a specific permission was never needed.

### UnapprovedRunners

This rule flags workflows that use runners that they might not need or should not use. This can come in handy when an organization has available self hosted or otherwise expensive runners but wants to be particular about when they're used.

Like with some other rules, this rule doesn't inspect the way a runner is used. Instead, it is meant to signal to code reviewers that the author may be doing something they shouldn't be. These findings can be resolved in a couple ways:
* Add a one off exception for this workflow.
* Use a different runner.
* Add the runner to the `allowed_runners` configuration.

See [Github's documentation for `runs-on`](https://docs.github.com/en/actions/writing-workflows/workflow-syntax-for-github-actions#jobsjob_idruns-on) for more information.

#### Configuration Options

| Option       | Default Value          | Description                                                   |
|-------------|------------------------|---------------------------------------------------------------|
| `allowed_runners` | ["ubuntu-latest"] | An array containing the types of runners a workflow is allowed to use. |

### UnpinnedActions

This rule flags any use of reusable actions that do not pin to a specific commit hash. This is intended to catch potential supply chain issues where a workflow references a third party workflow that may later be modified to introduce a vulnerability or otherwise malicious code. By pinning to a specific commit hash, you can mitigate these risks by ensuring that the code your workflow depends on doesn't change without you knowing.

For example:

```yaml
name: CI

on: push

jobs:
  checkout:
    runs-on: ubuntu
    steps:
      - uses: coolworkflows/very_safe_checkout
```

This workflow uses the third party `coolworkflows/very_safe_checkout` workflow. Because a commit hash isn't specified, we end up pulling in the latest version of this workflow every time our workflow runs. This means we are at risk of pulling untested code which at worst can introduce a vulnerability or malicious code, and at best introduce backwards incompatible code that breaks our workflow.

This workflow should be rewritten to reference a specific commit hash, ensuring that the code we tested with is the code we will always use:

```yaml
name: CI

on: push

jobs:
  checkout:
    runs-on: ubuntu
    steps:
      - uses: coolworkflows/very_safe_checkout@436766774e42e826479ba5868232e5a9c8986887
```

Now every time we run our workflow, we pull in the same version of `very_safe_checkout` every single time, making it difficult for unchecked code to make its way into our workflows.

Because it may be tedious to use specific commit hashes, you can allowlist specific organizations whose actions you consider to be trusted (e.g. the official `actions` organization, or your own organization).

Check out [Github's official documentation on the different techniques for pinning](https://docs.github.com/en/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions#using-third-party-actions) to better understand the risks they come with.

#### Configuration Options

| Option       | Default Value          | Description                                                   |
|-------------|------------------------|---------------------------------------------------------------|
| `trusted_authors` | [] | An array of github organizations that contain workflows that you trust. |

### UnsafeCheckout

This rule flags workflows that may check out user supplied code in an unsafe way. Workflows that do this are at high risk of introducing arbitrary code execution vulnerabilities where user supplied code is executed in a trusted environment with secrets and other sensitive data. It does this by looking at any uses of the `actions/checkout` action with user supplied input.

Like with many other rules, this rule cannot check for you that this is done being safely. Instead, it serves as a flag for code reviewers to double check that the logic used to fetch user supplied code and the way that code is used is safe. For example, running a linter on user supplied code may be safe, but executing a script in a branch given to us by the user is not.

For example, take this workflow that checks out code supplied by the user:

```yaml
on: [pull_request_target]

jobs:
  build:
    name: Build
    runs-on: ubuntu-latest
    steps:
    # check out the attacker controlled branch with their code
    - uses: actions/checkout@v2
      with:
        ref: ${{ github.event.pull_request.head.sha }}

    # set up the environment and run specs
    # because Rakefile comes from the attacker's branch
    # we end up executing their code, even though they don't
    # control the command here
    - run: |
        rake setup
        rake spec
```

This workflow runs unit tests in a user supplied branch. Unit tests are just arbitrary code, so a user could create a unit test that for example dumps all the secrets in environment variables for them to look at. In this case, the workflow may need to be rewritten so that tests only run after being merged (i.e. approved by a code reviewer and confirmed to not have any malicious code) or the strategy may need to be scrapped altogether.

This rule only looks for user supplied branches being checked out for `pull_request_target` and `workflow_dispatch` triggers. Depending on your threat model, you may need to configure `risky_events` appropriately, for example if you trust your Github organization settings enough to be comfortable with all uses of `workflow_dispatch`.

#### Configuration Options

| Option       | Default Value          | Description                                                   |
|-------------|------------------------|---------------------------------------------------------------|
| `risky_events` | ["pull_request_target", "workflow_dispatch"]               | An array of Github events you consider risky. |

## Walkthrough

Let's start with a minimal configuration file that enables some basic Rules.

```yaml
Enabled:
  AutomaticMerge:
  UnsafeCheckout:
  UnpinnedAction:
```

and here's the Workflow file we'll be testing:

```yaml
on: push
name: Pretend to Build
jobs:
  DoNothing:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout
```

Now let's run Claws on this file:

```
$ bundle exec bin/analyze -c config.yml -t corpus/unpinned.yml

Violation: UnpinnedAction on corpus/unpinned.yml:8
All reusable actions must be pinned to a specific version.
    steps:
      - name: Checkout
>>>         uses: actions/checkout
```

It's identified this reusable action as problematic because it's not pinned to a specific version. You can read [Github's own docs](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions#using-third-party-actions) on the topic, but in short, an unpinned version means the contents of the Action can change without your Workflow's contents changing, running the risk of executing new and undesired code.

Now we have several options for remediation here.

* **We could ignore this finding (please don't)**

We can do this by adding a comment to this Workflow to let Claws know we want to continue being a bad person. There are some scenarios where this is totally fine, e.g. an overzealous expression, or some other compensating control that Claws has no insight into (e.g. your Github org doesn't allow externally sourced Actions)

```yaml
on: push
name: Pretend to Build
jobs:
  DoNothing:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        # ignore: UnpinnedAction
        uses: actions/checkout
```

This not only tells Claws to avoid surfacing this finding, but it also signals to other developers that this is bad behavior but was explicitly allowed. Some `git blame` spelunking may help them understand the context better.

* **We could tell the Rule that `actions` is a trusted developer.**

Because `actions` is Github's official account for their reusable actions, we could simply tell the Rule to avoid flagging this. We can update our config from earlier to look a little something like this:

```yaml
Enabled:
  AutomaticMerge:
  UnsafeCheckout:
  UnpinnedAction:
    trusted_authors: ["actions"]
```

Now not only have we remediated this specific finding, but any other Workflows that use an action from Github's official account without pinning it will not be treated as a violation.

Note, configuration options like `trusted_authors` are specific to the individual Rules. Each Rule defines what values it can pull from your configuration file. We'll cover this in technical depth below.

* **And of course, we could just do the right thing and pin the version.**

At the time of writing, the latest version of the `action/checkout` action is 3.5.3, with a corresponding commit hash of `c85c95e3d7251135ab7dc9ce3241c5835cc595a9`. A full length commit hash is the only way to get an immutable reference to code at a specific point in time, so we can just add that to our Workflow and be done with it:

```yaml
on: push
name: Pretend to Build
jobs:
  DoNothing:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@c85c95e3d7251135ab7dc9ce3241c5835cc595a9
```

With that being said, it's up to you to decide how to remediate violations. Claws makes it easy to do that on your own terms.

## Anatomy of A Rule

Here's the source to the `UnpinnedAction` Rule from above.

```ruby
class UnpinnedAction < Rule
  description "All reusable actions must be pinned to a specific version."

  on_step %(
    $action != null &&
    (
      $action.version == null ||
      contains(["main", "master"], $action.version)
    ) &&
    !contains($data.trusted_authors, $action.author)
  ), highlight: "uses"

  def data
    {
      "trusted_authors": configuration.fetch("trusted_authors", [])
    }
  end
end
```

The `on_step` indicates the depth at which this expression will be evaluated. Here, this means for every "step" in a Workflow, this expression will be evaluated. A Rule can have any number of `on_workflow`, `on_job`, and `on_step` expressions. This can come in handy if your expression is getting a bit unwieldy. It might make more sense to break it up into multiple expressions.

To give users some "breathing room", this Rule has a `trusted_authors` configuration option which is exposed to the expression as a variable via `$data.trusted_authors`. By default, its value is an empty array, meaning users who don't need this feature don't need to use it. This is part of what makes Claws' Rules so powerful: expressions are easy to read and fully configurable if you want them to be. 

## Debug Mode

Here's a little walkthrough on how to use it. Let's start by setting one of the expressions in `AutomaticMerge` to debug: true.

```diff
diff --git a/lib/rules/automatic_merge.rb b/lib/rules/automatic_merge.rb
index 076e995..e16da33 100644
--- a/lib/rules/automatic_merge.rb
+++ b/lib/rules/automatic_merge.rb
@@ -11,11 +11,11 @@ class AutomaticMerge < Rule

   on_step %(
     contains_any($workflow.on, $data.pr_events) && (
       $action.name in $data.automerge_actions
     )
-  ), highlight: "uses"
+  ), highlight: "uses", debug: true

   def data
     {
       "automerge_actions":
         configuration.fetch("automerge_actions", default_automerge_actions),
```

Now any invocation of this rule will automatically drop you into a REPL. This is most useful when combined with a specific test case. For example, this rule has five test cases:

```
$ bundle exec rspec spec/rules/automatic_merge_spec.rb

AutomaticMerge
  with default configuration
    flags a step that uses an automerge action
    flags a step that uses the CLI to merge a PR
    doesn't flag a step for using an unrelated action
    doesn't flag a step for doing something unrelated with the CLI
  with a custom configuration
    flags a step that uses an automerge action

Finished in 0.007 seconds (files took 0.21 seconds to load)
5 examples, 0 failures
```

We don't want to be dropped into a REPL for all five cases. In a real world scenario, you'd probably pick a test case that's failing and you're not sure why. In my scenario, all the tests are passing, so let's just do the first one.

```
$ bundle exec rspec spec/rules/automatic_merge_spec.rb:7
Run options: include {:locations=>{"./spec/rules/automatic_merge_spec.rb"=>[7]}}

AutomaticMerge
  with default configuration
!!! CLAWS DEBUG !!!
<Expression '
    contains_any($workflow.on, $data.pr_events) && (
      $action.name in $data.automerge_actions
    )
  '> returned true
Tips:
* values available in @debug_values
* eval a test expression: e 'expression'
* ^D to exit

From: /Users/omar/src/claws/lib/application.rb:194 Application#enter_debug:

    184: def enter_debug(result:, expression:, values:)
    185:   @debug_values = values
    186:
    187:   require 'pry'
    188:   puts "!!! CLAWS DEBUG !!!".red
    189:   puts "#{expression} returned #{result}".red
    190:   puts "Tips:"
    191:   puts "* values available in @debug_values".green
    192:   puts "* eval a test expression: e 'expression'".green
    193:   puts "* ^D to exit".green
 => 194:   binding.pry
    195: end

[1] pry(#<Application>)>
```

This is a regular `binding.pry` REPL, but instead of having to navigate project internals, you can look at the immediately local environment (printed in the tips!). If we're not sure why this test is failing, let's see if the rule is parsed correctly by checking what it thinks the action's name is, and what it's being checked against:

```
[1] pry(#<Application>)> e '$action.name'
"pascalgn/automerge-action"
=> nil
[2] pry(#<Application>)> e '$data.automerge_actions'
["reitermarkus/automerge", "pascalgn/automerge-action"]
=> nil
```

Ok, we can see that it's properly parsed the action name is correctly checking against this list. Because we're evaluating arbitrary expressions, we can evaluate entire subsets of our rule to validate that they work, piece by piece:

```
[4] pry(#<Application>)> e '$action.name in $data.automerge_actions'
true
=> nil
```
We can also get a full snapshot of the local environment as the rule executed, in case there's any clues there:

```
[5] pry(#<Application>)> @debug_values
=> {:data=>
  {:automerge_actions=>["reitermarkus/automerge", "pascalgn/automerge-action"],
   :pr_events=>
    ["push",
     "pull_request_target",
     "pull_request",
     "pull_request_comment",
     "pull_request_review",
     "pull_request_review_comment",
     "workflow_dispatch",
     "workflow_call"]},
 :workflow=>
  {"name"=>"Automerge via Github Action",
   "on"=>"pull_request",
   "jobs"=>{"deploy"=>{"steps"=>[{"id"=>"merge this pull request", "name"=>"automerge", "uses"=>"pascalgn/automerge-action@v0.15.5"}], "runs_on"=>nil}}},
 :job=>{"steps"=>[{"id"=>"merge this pull request", "name"=>"automerge", "uses"=>"pascalgn/automerge-action@v0.15.5"}], "runs_on"=>nil},
 :step=>{"id"=>"merge this pull request", "name"=>"automerge", "uses"=>"pascalgn/automerge-action@v0.15.5"},
 :action=>{"name"=>"pascalgn/automerge-action", "version"=>"v0.15.5", "author"=>"pascalgn"},
 :secrets=>[]}
```

Since this rule is functioning as desired, we don't need to dig any further. But hopefully this should make rule development a lot easier.

## Writing Tests

Rules should have corresponding specs that contain sample Workflows that exercise all the different ways to trigger their expressions. See [specs](./specs/rules/) for more info.

## Contributing

Check [CONTRIBUTING.md](CONTRIBUTING.md)
