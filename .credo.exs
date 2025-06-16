# This file contains the configuration for Credo.
%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "test/"],
        excluded: [~r"/_build/", ~r"/deps/", ~r"/node_modules/"]
      },
      strict: false,
      color: true,
      checks: [
        # Skip ModuleDoc and Spec checks initially
        {Credo.Check.Readability.ModuleDoc, false},
        {Credo.Check.Readability.Specs, false}
      ]
    }
  ]
}
