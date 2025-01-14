{ buildPythonApplication, fetchPypi, poetry-core, click, rmscene }:
buildPythonApplication rec {
  pname = "rmc";
  version = "0.2.1";
  pyproject = true;

  propagatedBuildInputs = [
    click
    rmscene
  ];

  nativeBuildInputs = [
    poetry-core
  ];

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-NPA0Bq5Ysmt+nGbtAOsqE2h2jcKqqV6spRjY+TncYVw=";
  };
}
