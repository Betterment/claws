module Claws
  module Rule
    class ImplicitPersistCredentials < BaseRule
      description <<~DESC
        By default, actions/checkout will store generated credentials to disk so that
        subsequent git operations will not require reauthentication. These credentials
        will be available to subsequent steps and jobs. This may be undesirable and
        potentially unsafe in scenarios where these credentials may be accessible to
        untrusted code. In these cases, if these credentials are stolen they can be used
        externally by an attacker to clone repositories that would otherwise have been
        inaccessible.

        If you know you will not need to access this repository for the rest of your
        workflow, consider setting `persist-credentials` to false. Conversely,
        explicitly set it to true if you know you will need these credentials.

        For more information:
        https://github.com/betterment/claws/blob/main/README.md#implicitpersistcredentials
      DESC

      on_step %(
        $step.meta.action.name == "actions/checkout" &&
        !contains([true, false], dig($step, "with.persist-credentials"))
      ), highlight: "uses"
    end
  end
end
